#!/bin/bash

# Function to check if a command exists
command_exists() {
  command -v "$1" &> /dev/null
}

# Exit on error
set -e

# Update package lists
echo "Updating package lists..."
sudo apt-get update

# Install Python 3.11 if not installed
if ! command_exists python3.11; then
  echo "Installing Python 3.11..."
  sudo apt-get install -y software-properties-common
  sudo add-apt-repository -y ppa:deadsnakes/ppa
  sudo apt-get update
  sudo apt-get install -y python3.11 python3.11-venv python3.11-dev
fi

# Install pip if not installed
if ! command_exists pip3; then
  echo "Installing pip..."
  sudo apt-get install -y python3-pip
fi

# Install Docker if not installed
if ! command_exists docker; then
  echo "Installing Docker..."
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt-get update
  sudo apt-get install -y docker-ce
fi

# Install Docker Compose if not installed
if ! command_exists docker-compose; then
  echo "Installing Docker Compose..."
  sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
fi

# Install Loki Docker plugin if not installed
if ! docker plugin ls | grep -q loki; then
  echo "Installing Loki Docker plugin..."
  docker plugin install grafana/loki-docker-driver:latest --alias loki --grant-all-permissions
fi

# Wait for Loki to be ready
echo "Waiting for Loki to be ready..."
sleep 10

# Check if Loki is accessible
max_retries=20
retry_count=0
while [ $retry_count -lt $max_retries ]; do
  if curl -s http://localhost:3100/ready > /dev/null 2>&1; then
    echo "Loki is ready!"
    break
  fi
  echo "Waiting for Loki... ($retry_count/$max_retries)"
  sleep 10
  retry_count=$((retry_count + 1))
done

if [ $retry_count -eq $max_retries ]; then
  echo "Warning: Loki may not be ready, but continuing..."
fi

# Configure Docker daemon to use default logging (not Loki globally)
echo "Configuring Docker logging driver..."
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "10"
  }
}
EOF
sudo systemctl restart docker

# Start Docker service if not running
if ! sudo systemctl is-active --quiet docker; then
  echo "Starting Docker service..."
  sudo systemctl start docker
  sudo systemctl enable docker
fi

# Add current user to docker group if not already added
if ! groups $USER | grep -q docker; then
  echo "Adding user to docker group..."
  sudo usermod -aG docker $USER
  newgrp docker
fi

# Install required Python packages
echo "Installing required Python packages..."
pip3 install --upgrade pip
pip3 install docker-compose

# Verify installations
echo "Verifying installations..."
python3.11 --version
pip3 --version
docker --version
docker-compose --version

# Stop and remove existing containers
echo "Stopping and removing existing containers..."
# Stop all running containers
docker rm -f $(docker ps -a -q) || true

# Ensure app-network exists
echo "Ensuring networks exist..."
if ! docker network inspect app-network >/dev/null 2>&1; then
  echo "Creating app-network..."
  docker network create app-network
fi

# Start monitoring stack
echo "Starting monitoring stack..."
docker-compose -f docker-compose.monitoring.yml up -d --build

# Check if monitoring containers are running
if ! docker-compose -f docker-compose.monitoring.yml ps | grep -q "Up"; then
  echo "Failed to start monitoring containers"
  docker-compose -f docker-compose.monitoring.yml logs
  exit 1
fi

# Build and start new containers
echo "Building and starting containers..."
docker-compose up -d --build

# Check if containers are running
if ! docker-compose ps | grep -q "Up"; then
  echo "Failed to start containers"
  docker-compose logs
  exit 1
fi

echo "Deployment completed successfully"
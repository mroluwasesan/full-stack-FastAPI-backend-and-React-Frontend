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

# Create and set up deployment directory
echo "Setting up deployment directory..."
DEPLOY_DIR="/home/$USER/dojo-task"
mkdir -p $DEPLOY_DIR
cd $DEPLOY_DIR

# Clone or update repository
if [ ! -d ".git" ]; then
  echo "Cloning repository..."
  git clone https://github.com/$GITHUB_REPOSITORY.git .
  # Fetch all branches
  git fetch --all
else
  echo "Updating repository..."
  # Reset any local changes that might prevent pull
  git reset --hard
  # Clean any untracked files
  git clean -fd
  # Fetch all changes from remote
  git fetch --all
  # Get the default branch name dynamically
  DEFAULT_BRANCH=$(git remote show origin | grep 'HEAD branch' | awk '{print $3}')
  # Checkout and pull the default branch
  git checkout $DEFAULT_BRANCH
  git pull origin $DEFAULT_BRANCH
fi

# Verify the repository state
echo "Repository status:"
git status
echo "Latest commit:"
git log -1

# Stop and remove existing containers
echo "Stopping and removing existing containers..."
docker rm -f $(docker ps -a -q) || true

# Ensure app-network exists
echo "Ensuring networks exist..."
if ! docker network inspect app-network >/dev/null 2>&1; then
  echo "Creating app-network..."
  docker network create app-network
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

# Start monitoring stack
echo "Starting monitoring stack..."
docker-compose -f docker-compose.monitoring.yml up -d --build

# Check if monitoring containers are running
if ! docker-compose -f docker-compose.monitoring.yml ps | grep -q "Up"; then
  echo "Failed to start monitoring containers"
  docker-compose -f docker-compose.monitoring.yml logs
  exit 1
fi

# Verify Traefik is routing correctly
echo "Checking Traefik configuration..."
docker exec dojo-task-traefik-1 traefik config dump

# Verify services are registered with Traefik
echo "Checking Traefik service status..."
curl -k https://localhost/api/http/services | jq .

echo "Deployment completed successfully"
#!/bin/bash

set -e  # Exit on any error

# Function to install Python 3.11
install_python() {
    if ! command_exists python3.11; then
        echo "Installing Python 3.11..."
        sudo apt-get install -y software-properties-common
        sudo add-apt-repository -y ppa:deadsnakes/ppa
        sudo apt-get update
        sudo apt-get install -y python3.11 python3.11-venv python3.11-dev
    else
        echo "Python 3.11 is already installed"
    fi
}

# Function to install pip
install_pip() {
    if ! command_exists pip3; then
        echo "Installing pip..."
        sudo apt-get install -y python3-pip
    else
        echo "pip is already installed"
    fi
}

# Function to install Docker
install_docker() {
    if ! command_exists docker; then
        echo "Installing Docker..."
        sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt-get update
        sudo apt-get install -y docker-ce
    else
        echo "Docker is already installed"
    fi
}

# Function to install Docker Compose
install_docker_compose() {
    if ! command_exists docker-compose; then
        echo "Installing Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        echo "Docker Compose is already installed"
    fi
}

# Function to start Docker service
start_docker_service() {
    if ! sudo systemctl is-active --quiet docker; then
        echo "Starting Docker service..."
        sudo systemctl start docker
        sudo systemctl enable docker
    else
        echo "Docker service is already running"
    fi
}

# Function to add user to docker group
setup_docker_user() {
    if ! groups $USER | grep -q docker; then
        echo "Adding user to docker group..."
        sudo usermod -aG docker $USER
        newgrp docker
    else
        echo "User is already in docker group"
    fi
}

# Function to install Python packages
install_python_packages() {
    echo "Installing required Python packages..."
    pip3 install --upgrade pip
    pip3 install docker-compose
}

# Function to verify installations
verify_installations() {
    echo "Verifying installations..."
    python3.11 --version
    pip3 --version
    docker --version
    docker-compose --version
}

# Function to setup deployment directory
setup_deployment_directory() {
    echo "Setting up deployment directory..."
    DEPLOY_DIR="/home/$USER/dojo-task"
    mkdir -p $DEPLOY_DIR
    cd $DEPLOY_DIR

    # Store the deploy directory for later use
    export DEPLOY_DIR
}

# Function to clone or update repository
update_repository() {
    echo "Updating repository..."
    if [ ! -d ".git" ]; then
        echo "Cloning repository..."
        # Note: GITHUB_REPOSITORY should be passed as environment variable
        git clone https://github.com/${GITHUB_REPOSITORY}.git .
    else
        echo "Updating existing repository..."
        git pull origin main
    fi
}

# Function to stop existing containers
stop_existing_containers() {
    echo "Stopping existing containers..."
    # Stop and remove existing containers
    docker rm -f $(docker ps -a -aq) 2>/dev/null || true
}

# Function to setup Docker networks
setup_docker_networks() {
    echo "Ensuring networks exist..."
    if ! docker network inspect app-network >/dev/null 2>&1; then
        echo "Creating app-network..."
        docker network create app-network
    else
        echo "app-network already exists"
    fi
}

# Function to build and start main containers
start_main_containers() {
    echo "Building and starting main containers..."
    docker-compose up -d --build

    # Check if containers are running
    if ! docker-compose ps | grep -q "Up"; then
        echo "Failed to start containers"
        docker-compose logs
        exit 1
    fi
    echo "Main containers started successfully"
}

# Function to start monitoring stack
start_monitoring_stack() {
    echo "Starting monitoring stack..."
    docker-compose -f docker-compose.monitoring.yml up -d --build

    # Check if monitoring containers are running
    if ! docker-compose -f docker-compose.monitoring.yml ps | grep -q "Up"; then
        echo "Failed to start monitoring containers"
        docker-compose -f docker-compose.monitoring.yml logs
        exit 1
    fi
    echo "Monitoring stack started successfully"
}

# Main deployment function
main() {
    echo "Starting deployment process..."

    # Update package lists
    echo "Updating package lists..."
    sudo apt-get update

    # Install all required components
    install_python
    install_pip
    install_docker
    install_docker_compose
    start_docker_service
    setup_docker_user
    install_python_packages
    verify_installations

    # Setup deployment
    setup_deployment_directory
    update_repository
    stop_existing_containers
    setup_docker_networks

    # Start services
    start_main_containers
    start_monitoring_stack

    echo "Deployment completed successfully!"
}

# Run main function
main "$@"
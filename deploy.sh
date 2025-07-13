##!/bin/bash
#
#set -e  # Exit on any error
#
## Function to install Python 3.11
#install_python() {
#    if ! command_exists python3.11; then
#        echo "Installing Python 3.11..."
#        sudo apt-get install -y software-properties-common
#        sudo add-apt-repository -y ppa:deadsnakes/ppa
#        sudo apt-get update
#        sudo apt-get install -y python3.11 python3.11-venv python3.11-dev
#        sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
#    else
#        echo "Python 3.11 is already installed"
#    fi
#}
#
## Function to install pip
#install_pip() {
#    if ! command_exists pip3; then
#        echo "Installing pip..."
#        sudo apt-get install -y python3-pip
#        python3.11 -m ensurepip --upgrade
#    else
#        echo "pip is already installed"
#    fi
#    # Add pip to PATH if needed
#        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
#            echo "Adding ~/.local/bin to PATH"
#            echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
#            source ~/.bashrc
#        fi
#}
#
#
## Function to install Docker
#install_docker() {
#    if ! command_exists docker; then
#        echo "Installing Docker..."
#        sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
#        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
#        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
#        sudo apt-get update
#        sudo apt-get install -y docker-ce
#    else
#        echo "Docker is already installed"
#    fi
#}
#
## Function to install Docker Compose
#install_docker_compose() {
#    if ! command_exists docker-compose; then
#        echo "Installing Docker Compose..."
#        sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
#        sudo chmod +x /usr/local/bin/docker-compose
#    else
#        echo "Docker Compose is already installed"
#    fi
#}
#
## Function to start Docker service
#start_docker_service() {
#    if ! sudo systemctl is-active --quiet docker; then
#        echo "Starting Docker service..."
#        sudo systemctl start docker
#        sudo systemctl enable docker
#    else
#        echo "Docker service is already running"
#    fi
#}
#
## Function to add user to docker group
#setup_docker_user() {
#    if ! groups $USER | grep -q docker; then
#        echo "Adding user to docker group..."
#        sudo usermod -aG docker $USER
#        newgrp docker
#    else
#        echo "User is already in docker group"
#    fi
#}
#\
#
## Function to install Python packages
#install_python_packages() {
#    echo "Installing required Python packages..."
#    pip3 install --upgrade pip
#    pip3 install docker-compose
#}
#
## Function to verify installations
#verify_installations() {
#    echo "Verifying installations..."
#    python3.11 --version
#    pip3 --version
#    docker --version
#    docker-compose --version
#}
#
## Function to setup deployment directory
#setup_deployment_directory() {
#    echo "Setting up deployment directory..."
#    DEPLOY_DIR="/home/$USER/dojo-task"
#    mkdir -p $DEPLOY_DIR
#    cd $DEPLOY_DIR
#    export DEPLOY_DIR
#}
#
## Function to clone or update repository
#update_repository() {
#    echo "Updating repository..."
#    if [ ! -d ".git" ]; then
#        echo "Cloning repository..."
#        # Note: GITHUB_REPOSITORY should be passed as environment variable
#        git clone https://github.com/${GITHUB_REPOSITORY}.git .
#    else
#        echo "Resetting any local changes..."
#        git reset --hard HEAD
#        echo "Updating existing repository..."
#        git pull origin main
#    fi
#}
#
## Function to stop existing containers
#stop_existing_containers() {
#    echo "Stopping existing containers..."
#    # Stop and remove existing containers
#    docker rm -f $(docker ps -a -aq) 2>/dev/null || true
#}
#
## Function to setup Docker networks
#setup_docker_networks() {
#    echo "Ensuring networks exist..."
#    if ! docker network inspect app-network >/dev/null 2>&1; then
#        echo "Creating app-network..."
#        docker network create app-network
#    else
#        echo "app-network already exists"
#    fi
#}
#
## Function to build and start main containers
#start_main_containers() {
#    echo "Building and starting main containers..."
#    docker-compose up -d --build
#
#    # Check if containers are running
#    if ! docker-compose ps | grep -q "Up"; then
#        echo "Failed to start containers"
#        docker-compose logs
#        exit 1
#    fi
#    echo "Main containers started successfully"
#}
#
## Function to start monitoring stack
#start_monitoring_stack() {
#    echo "Starting monitoring stack..."
#    docker-compose -f docker-compose.monitoring.yml up -d --build
#
#    # Check if monitoring containers are running
#    if ! docker-compose -f docker-compose.monitoring.yml ps | grep -q "Up"; then
#        echo "Failed to start monitoring containers"
#        docker-compose -f docker-compose.monitoring.yml logs
#        exit 1
#    fi
#    echo "Monitoring stack started successfully"
#}
#
## Main deployment function
#main() {
#    echo "Starting deployment process..."
#
#    # Update package lists
#    echo "Updating package lists..."
#    sudo apt-get update
#
#    # Install all required components
#    install_python
#    install_pip
#    install_docker
#    install_docker_compose
#    start_docker_service
#    setup_docker_user
#    install_python_packages
#    verify_installations
#
#    # Setup deployment
#    setup_deployment_directory
#    update_repository
#    stop_existing_containers
#    setup_docker_networks
#
#    # Start services
#    start_main_containers
#    start_monitoring_stack
#
#    echo "Deployment completed successfully!"
#}
#
## Run main function
#main "$@"


#!/bin/bash

# Deploy script for dojo-task application
# This script handles the complete deployment process including:
# - Installing required dependencies
# - Setting up Docker and Docker Compose
# - Cloning/updating the repository
# - Building and starting containers

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to fix apt-pkg issues
fix_apt_pkg() {
    print_status "Fixing apt-pkg issues..."
    sudo apt-get install -y python3-apt --fix-missing || true
    sudo apt-get install -y python3-distutils || true
}

# Function to install Python 3.11
install_python() {
    if ! command_exists python3.11; then
        print_status "Installing Python 3.11..."
        sudo apt-get install -y software-properties-common

        # Fix potential apt-pkg issues before adding repository
        fix_apt_pkg

        sudo add-apt-repository -y ppa:deadsnakes/ppa
        sudo apt-get update
        sudo apt-get install -y python3.11 python3.11-venv python3.11-dev

        # Set python3.11 as default python3
        sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
    else
        print_status "Python 3.11 is already installed"
    fi
}

# Function to install pip
install_pip() {
    if ! command_exists pip3; then
        print_status "Installing pip..."
        sudo apt-get install -y python3-pip
        python3.11 -m ensurepip --upgrade
    else
        print_status "pip is already installed"
    fi

    # Add pip to PATH if needed
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        print_status "Adding ~/.local/bin to PATH"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        export PATH="$HOME/.local/bin:$PATH"
    fi
}

# Function to install Docker
install_docker() {
    if ! command_exists docker; then
        print_status "Installing Docker..."
        sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

        # Use a more reliable method to add Docker GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt-get update
        sudo apt-get install -y docker-ce
    else
        print_status "Docker is already installed"
    fi
}

# Function to install Docker Compose
install_docker_compose() {
    if ! command_exists docker-compose; then
        print_status "Installing Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        print_status "Docker Compose is already installed"
    fi
}

# Function to start Docker service
start_docker_service() {
    if ! sudo systemctl is-active --quiet docker; then
        print_status "Starting Docker service..."
        sudo systemctl start docker
        sudo systemctl enable docker
    else
        print_status "Docker service is already running"
    fi
}

# Function to add user to docker group
setup_docker_user() {
    if ! groups $USER | grep -q docker; then
        print_status "Adding user to docker group..."
        sudo usermod -aG docker $USER
        # Use sg instead of newgrp for better compatibility
        sg docker -c "echo 'User added to docker group successfully'"
    else
        print_status "User is already in docker group"
    fi
}

# Function to install Python packages
install_python_packages() {
    print_status "Installing required Python packages..."

    # Use python3.11 specifically and install to user directory
    python3.11 -m pip install --user --upgrade pip
    python3.11 -m pip install --user docker-compose

    # Also install system-wide if needed
    sudo python3.11 -m pip install --upgrade pip docker-compose || true
}

# Function to verify installations
verify_installations() {
    print_status "Verifying installations..."
    python3.11 --version
    pip3 --version
    docker --version
    docker-compose --version
}

# Function to setup deployment directory
setup_deployment_directory() {
    print_status "Setting up deployment directory..."
    DEPLOY_DIR="/home/$USER/dojo-task"
    mkdir -p $DEPLOY_DIR
    cd $DEPLOY_DIR

    # Store the deploy directory for later use
    export DEPLOY_DIR
}

# Function to clone or update repository
update_repository() {
    print_status "Updating repository..."
    if [ ! -d ".git" ]; then
        print_status "Cloning repository..."
        # Note: GITHUB_REPOSITORY should be passed as environment variable
        git clone https://github.com/${GITHUB_REPOSITORY}.git .
    else
        print_status "Resetting any local changes..."
        git reset --hard HEAD
        print_status "Updating existing repository..."
        git pull origin main
    fi
}

# Function to stop existing containers
stop_existing_containers() {
    print_status "Stopping existing containers..."
    # Stop and remove existing containers
    docker rm -f $(docker ps -a -aq) 2>/dev/null || true
}

# Function to setup Docker networks
setup_docker_networks() {
    print_status "Ensuring networks exist..."
    if ! docker network inspect app-network >/dev/null 2>&1; then
        print_status "Creating app-network..."
        docker network create app-network
    else
        print_status "app-network already exists"
    fi
}

# Function to build and start main containers
start_main_containers() {
    print_status "Building and starting main containers..."
    docker-compose up -d --build

    # Check if containers are running
    if ! docker-compose ps | grep -q "Up"; then
        print_error "Failed to start containers"
        docker-compose logs
        exit 1
    fi
    print_status "Main containers started successfully"
}

# Function to start monitoring stack
start_monitoring_stack() {
    print_status "Starting monitoring stack..."
    docker-compose -f docker-compose.monitoring.yml up -d --build

    # Check if monitoring containers are running
    if ! docker-compose -f docker-compose.monitoring.yml ps | grep -q "Up"; then
        print_error "Failed to start monitoring containers"
        docker-compose -f docker-compose.monitoring.yml logs
        exit 1
    fi
    print_status "Monitoring stack started successfully"
}

# Function to verify Traefik configuration
verify_traefik() {
    print_status "Checking Traefik configuration..."

    # Wait a bit for containers to be fully ready
    sleep 10

    # Check if Traefik container exists and is running
    if docker ps | grep -q "traefik"; then
        docker exec $(docker ps | grep traefik | awk '{print $1}') traefik config dump || print_warning "Could not dump Traefik config"

        print_status "Checking Traefik service status..."
        curl -k https://localhost/api/http/services | jq . || print_warning "Could not check Traefik services"
    else
        print_warning "Traefik container not found or not running"
    fi
}

# Main deployment function
main() {
    print_status "Starting deployment process..."

    # Update package lists
    print_status "Updating package lists..."
    sudo apt-get update

    # Fix common issues first
    fix_apt_pkg

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

    # Verify deployment
    verify_traefik

    print_status "Deployment completed successfully!"
}

# Run main function
main "$@"
#!/bin/bash

log_step "Checking and installing prerequisites..."

#install curl
if ! command -v curl &>/dev/null; then
    sudo apt install -y curl &>/dev/null
    log_info "curl installed successfully."
fi

if ! command -v tar &>/dev/null; then
    sudo apt install -y tar &>/dev/null
    log_info "tar installed successfully."
fi

if ! command -v jq &>/dev/null; then
    sudo apt install -y jq &>/dev/null
    log_info "jq installed successfully."
fi



if [ -x "$(command -v docker)" ]; then
    log_info "Docker is already installed."
    #check docker compose version
    # if docker-compose version 2>/dev/null; then
    #     if command -v docker-compose &> /dev/null; then
    #     V1_VERSION=$(docker-compose --version)
    #     echo "WARNING: Legacy 'docker-compose' found: $V1_VERSION"
    #     read -p "Do you want to remove the legacy 'docker-compose' to avoid conflicts? (y/n) " answer
    #     if [[ "$answer" =~ ^[Yy]$ ]]; then
      
else    
    
    log_info "Docker is not installed. Proceeding with installation..." #!!!!use logger function
    # Add Docker's official GPG key:
    sudo apt update
    sudo apt install ca-certificates curl
    sudo install -m 0755  -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc 
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
    Types: deb
    URIs: https://download.docker.com/linux/ubuntu
    Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
    Components: stable
    Architectures: $(dpkg --print-architecture)
    Signed-By: /etc/apt/keyrings/docker.asc
EOF

    sudo apt update


    #install docker engine
    sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

    # Add current user to docker group
    sudo usermod -aG docker $USER   
    newgrp docker # Apply the new group membership without logging out and back in
fi


# Verify Docker installation
if docker --version 2>/dev/null; then
    log_info "Docker installed successfully."
    if docker run hello-world &>/dev/null; then  # returns an exit code of zero 
        log_info "Docker is working correctly."
    else
        log_error "Docker installation seems to have issues. Please check the Docker service."
        exit 1
    fi
else
    log_error "Docker installation failed."
    exit 1
fi  

# Install Node.js and npm
# curl -fsSL https://deb.nodesource.com/setup_18.x | sudo bash -
# sudo apt install -y nodejs 

# Verify Node.js and npm installation
# if node -v 2>/dev/null && npm -v 2>/dev/null; then
#     echo "Node.js and npm installed successfully: Node.js version: $(node -v), npm version: $(npm -v)"
# else
#     echo "Node.js and npm installation failed."
#     exit 1
# fi 




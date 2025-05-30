#!/bin/bash

# Uninstall old versions
sudo apt-get remove -y docker docker-engine docker.io containerd runc

# Update package index
sudo apt-get update

# Install required packages
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker’s official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  focal stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index again
sudo apt-get update

# Install Docker Engine, CLI, containerd, and plugins
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group (optional)
# vagrant is the user created by Vagrant
sudo usermod -aG docker vagrant

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

echo "Docker installation complete. You may need to log out and log back in for group changes to take effect."

# sudo apt install -y sshpass
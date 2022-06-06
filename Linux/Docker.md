 # Docker Engine Install Guide
 
 ### Set up the repository
 ```bash
sudo apt-get update -y
 
sudo apt-get install \
   ca-certificates \
   curl \
   gnupg \
   lsb-release
```

### Add Docker’s official GPG key:
```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

### Use the following command to set up the repository:
```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### Install Docker Engine
```bash
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

### Verify that Docker Engine is installed correctly by running the hello-world image.
```bash
sudo docker run hello-world
```

# Docker Compose Install Guide

### Download the latest Docker-Compose version
```bash
sudo curl -L https://github.com/docker/compose/releases/download/v2.0.1/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
```

### Make the binary file executable.
```bash
chmod +x docker-compose-linux-x86_64
```

### Move the file to your PATH
```bash
sudo mv docker-compose-linux-x86_64 /usr/local/bin/docker-compose
```

### Confirm that docker-compose has been installed
```bash
docker-compose version
```

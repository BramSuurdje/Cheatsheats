# Install Portainer with Docker on Linux

## Deployment

First, create the volume that Portainer Server will use to store its database:
```bash
docker volume create portainer_data
```
Then, download and install the Portainer Server container:
```bash
docker run -d -p 8000:8000 -p 9443:9443 --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
```

### Now that the installation is complete, you can log into your Portainer Server instance by opening a web browser and going to:
```bash
https://localhost:9443
```
Replace localhost with the relevant IP address or FQDN if needed, and adjust the port if you changed it earlier.
You will be presented with the initial setup page for Portainer Server.

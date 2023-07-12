#!/bin/bash
# Made by Bram Suurd 
# This script will automatically install and configure the following services. 
# Nextcloud
# Wordpress
# Webmin

# This script is made for the following distributions
# Ubuntu
# Debian
# CentOS
# Fedora
# Arch Linux

# set some colors
CNT="[\e[1;36mNOTE\e[0m]"
COK="[\e[1;32mOK\e[0m]"
CER="[\e[1;31mERROR\e[0m]"
CAT="[\e[1;37mATTENTION\e[0m]"
CWR="[\e[1;35mWARNING\e[0m]"
CAC="[\e[1;33mACTION\e[0m]"
INSTLOG="install.log"

sleep 2

echo -e "$CNT - You are about to run a script that will install and configure the following services:
- Nextcloud
- Wordpress
- Backups
- Monitoring using Webmin"

sleep 3

read -n1 -rep $'[\e[1;33mACTION\e[0m] - Would you like to continue with the install (y,n) ' INST
if [[ $INST == "Y" || $INST == "y" ]]; then
    clear
    echo -e "$COK - Starting install script.."
else
    echo -e "$CNT - This script would now exit, no changes were made to your system."
    exit
fi

sleep 3

echo -e "\n
$CNT - This script will run some commands that require sudo. You will be prompted to enter your password.
If you are worried about entering your password then you may want to review the content of the script."

sleep 3

# check what package manager is being used
echo -e "$CNT - Checking what package manager is being used.."
sleep 1
if [ -x "$(command -v apt-get)" ]; then
    echo -e "$CNT - Using apt-get package manager"
    PKGMGR="apt-get"
elif [ -x "$(command -v yum)" ]; then
    echo -e "$CNT - Using yum package manager"
    PKGMGR="yum"
elif [ -x "$(command -v pacman)" ]; then
    echo -e "$CNT - Using pacman package manager"
    PKGMGR="pacman"
else
    echo -e "$CER - No package manager found, exiting.."
    exit
fi

docker-install () {
    sleep 1
    # install docker and docker-compose
        echo -e "$COK - Installing docker.."
        # update the system based on the package manager
        if [[ $PKGMGR == "apt-get" ]]; then
            sudo apt-get update -y
            sudo apt-get upgrade -y
            sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
            if [[ $(lsb_release -is) == "Ubuntu" ]]; then
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            elif [[ $(lsb_release -is) == "Debian" ]]; then
                curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
                sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
            else
                echo -e "$CER - Unsupported distribution: $(lsb_release -is), exiting.."
                exit
            fi
            sudo apt-get update -y
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose
            sudo usermod -aG docker $USER
            # check if docker was installed successfully
            if [[ $(docker --version) == *"Docker"* ]]; then
                echo -e "$COK - Docker installed successfully"
            else
                echo -e "$CER - Docker failed to install, exiting.."
                exit
            fi
        elif [[ $PKGMGR == "yum" ]]; then
            sudo yum update -y
            sudo yum install -y yum-utils device-mapper-persistent-data lvm2
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose
            sudo systemctl start docker
            sudo systemctl enable docker
            sudo usermod -aG docker $USER
            # check if docker was installed successfully
            if [[ $(docker --version) == *"Docker"* ]]; then
                echo -e "$COK - Docker installed successfully"
            else
                echo -e "$CER - Docker failed to install, exiting.."
                exit
            fi
        elif [[ $PKGMGR == "pacman" ]]; then
            sudo pacman -Syu --noconfirm
            sudo pacman -S --noconfirm docker docker-compose
            sudo systemctl start docker
            sudo systemctl enable docker
            sudo usermod -aG docker $USER
            # check if docker was installed successfully
            if [[ $(docker --version) == *"Docker"* ]]; then
                echo -e "$COK - Docker installed successfully"
            else
                echo -e "$CER - Docker failed to install, exiting.."
                exit
            fi
        else
            echo -e "$CER - No package manager found, exiting.."
            exit
        fi
}

nextcloud-install () {
    sleep 1
    sudo docker-compose -p nextcloud -f dc-nextcloud.yml up -d
    #check if nextcloud is running
    if [[ $(sudo docker ps -a) == *"nextcloud"* ]]; then
        NEXTCLOUDIP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
        NEXTCLOUDURL="http://$NEXTCLOUDIP:81"
        echo -e "$COK - Nextcloud installed successfully"
        echo ""
        sleep 2
        echo -e "$CNT - Nextcloud URL details:"
        echo -e "$CNT - Nextcloud URL is: $NEXTCLOUDURL"

    else
        echo -e "$CER - Nextcloud failed to install, trying to start the container again.."
        # try to start nextcloud again
        sudo docker-compose -p nextcloud -f dc-nextcloud.yml up -d
        #check if nextcloud is running
        if [[ $(sudo docker ps -a) == *"nextcloud"* ]]; then
            NEXTCLOUDIP=$(hostname -I | awk '{print $1}')
            NEXTCLOUDURL="http://$NEXTCLOUDIP:81"
            echo -e "$COK - Nextcloud installed successfully"
            echo ""
            sleep 2
            echo -e "$CNT - Nextcloud URL details:"
            echo -e "$CNT - Nextcloud URL is: $NEXTCLOUDURL"
        else
            echo -e "$CER - Nextcloud failed to install or start, exiting.."
            exit
        fi
    fi
}


wordpress-install () {
    sleep 1
    sudo docker-compose -p wordpress -f dc-wordpress.yml up -d
    #check if wordpress is running
    if [[ $(sudo docker ps -a) == *"wordpress"* ]]; then
        WORDPRESSIP=$(hostname -I | awk '{print $1}')
        WORDPRESSURL="http://$WORDPRESSIP:80"
        echo -e "$COK - Wordpress installed successfully"
        sleep 2
        echo ""
        echo -e "$CNT - Wordpress URL details:"
        echo -e "$CNT - Wordpress URL is: $WORDPRESSURL"

    else
        echo -e "$CER - Wordpress failed to install, trying to start the container again.."
        # try to start wordpress again
        sudo docker-compose -p wordpress -f dc-wordpress.yml up -d
        #check if wordpress is running
        if [[ $(sudo docker ps -a) == *"wordpress"* ]]; then
            echo -e "$COK - Wordpress installed successfully"
            WORDPRESSIP=$(hostname -I | awk '{print $1}')
            WORDPRESSURL="http://$WORDPRESSIP:80"
            sleep 2
            echo ""
            echo -e "$CNT - Wordpress URL details:"
            echo -e "$CNT - Wordpress URL is: $WORDPRESSURL"
        else
            echo -e "$CER - Wordpress failed to install or start, exiting.."
            exit
        fi
    fi
}


portainer-install () {
    sleep 1
    sudo docker volume create portainer_data
    sudo docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest
    #check if portainer is running
    if [[ $(sudo docker ps -a) == *"portainer"* ]]; then
        PORTAINERIP=$(hostname -I | awk '{print $1}')
        PORTAINERURL="https://$PORTAINERIP:9443"
        echo -e "$COK - Portainer installed successfully"
        sleep 2
        echo ""
        echo -e "$CNT - Portainer URL is: $PORTAINERURL"

    else
        echo -e "$CER - Portainer failed to install, trying to start the container again.."
        # try to start portainer again
        sudo docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest
        #check if portainer is running
        if [[ $(sudo docker ps -a) == *"portainer"* ]]; then
            echo -e "$COK - Portainer installed successfully"
            PORTAINERIP=$(hostname -I | awk '{print $1}')
            PORTAINERURL="https://$PORTAINERIP:9443"
            echo ""
            echo -e "$CNT - Portainer URL is: $PORTAINERURL"
        else
            echo -e "$CER - Portainer failed to install or start, exiting.."
            exit
        fi
    fi
}


webmin-install () {
    sleep 1
    curl -o setup-repos.sh https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh
    sh setup-repos.sh
}

sleep 1
# Nextcloud install
clear
echo -e "$CNT - Nextcloud is a platform to create your own cloud storage"
sleep 2
read -n1 -rep $'[\e[1;33mACTION\e[0m] - Would you like to install nextcloud (y,n) ' INSTNC
if [[ $INSTNC == "Y" || $INSTNC == "y" ]]; then
    echo -e "$CNT - Installing nextcloud using docker"
    # check if docker is installed
    if [[ $(docker --version) == *"Docker"* ]]; then
        echo -e "$CNT - Docker is installed... Continuing"
        nextcloud-install
    else
        echo -e "$CER - Docker is not installed"
        sleep 1
        echo -e "$CNT - Installing docker and continuing"
        docker-install
        nextcloud-install
    fi
else
    echo -e "$CNT - Skipping nextcloud install"
fi


# Wordpress install
clear
echo -e "$CNT - Wordpress is a platform to create websites and blogs"
sleep 2
read -n1 -rep $'[\e[1;33mACTION\e[0m] - Would you like to install wordpress (y,n) ' INSTWP
if [[ $INSTWP == "Y" || $INSTWP == "y" ]]; then
    echo -e "$CNT - Installing wordpress using docker"
    # check if docker is installed
    if [[ $(docker --version) == *"Docker"* ]]; then
        echo -e "$CNT - Docker is installed... Continuing"
        wordpress-install
    else
        echo -e "$CER - Docker is not installed"
        sleep 1
        echo -e "$CNT - Installing docker and continuing"
        docker-install
        wordpress-install
    fi
else
    echo -e "$CNT - Skipping wordpress install"
fi

# Portainer install
clear
echo -e "$CNT - Portainer is a docker management tool to manage your docker containers"
sleep 2
read -n1 -rep $'[\e[1;33mACTION\e[0m] - Would you like to install portainer (y,n) ' INSTPORT
if [[ $INSTPORT == "Y" || $INSTPORT == "y" ]]; then
    echo -e "$CNT - Installing portainer using docker"
    # check if docker is installed
    if [[ $(docker --version) == *"Docker"* ]]; then
        echo -e "$CNT - Docker is installed... Continuing"
        portainer-install
    else
        echo -e "$CER - Docker is not installed"
        sleep 1
        echo -e "$CNT - Installing docker and continuing"
        docker-install
        portainer-install
    fi
else
    echo -e "$CNT - Skipping portainer install"
fi

# Webmin install
clear
echo -e "$CNT - Webmin is a web-based interface for system administration for Unix"
echo -e "$CNT - Webmin is only available for RHEL and Debian based systems"
sleep 2
read -n1 -rep $'[\e[1;33mACTION\e[0m] - Would you like to install webmin (y,n) ' INSTWEBMIN
if [[ $INSTWEBMIN == "Y" || $INSTWEBMIN == "y" ]]; then
    webmin-install
else
    echo -e "$CNT - Skipping webmin install"
fi

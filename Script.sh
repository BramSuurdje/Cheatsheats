#!/bin/bash
echo "Script Gemaakt door Bram Suurd"
echo "134587@student.drenthecollege.nl"

MariaDB_Installeren() {
    echo Voeg ondrej/php PPA toe en werk package lists bij
    sudo add-apt-repository -y ppa:ondrej/php
    sudo apt update

    echo Installeer Apache, MariaDB, PHP 8.1 en vereiste modules
    sudo apt install -y apache2 mariadb-server php8.1 libapache2-mod-php8.1 php8.1-gd php8.1-json php8.1-mysql php8.1-curl php8.1-mbstring php8.1-intl php8.1-imagick php8.1-xml php8.1-zip
}
MariaDB_Installeren > /dev/null
echo "MariaDB is geinstalleerd"


MariaDB_Configuren() {
    echo "Enter current password for root (enter for none): <vul hier je root-wachtwoord in>"
    echo "Change the root password? [Y/n] n"
    echo "Remove anonymous users? [Y/n] Y"
    echo "Disallow root login remotly? [Y/n] Y"
    echo "Remove test database and access to it? [Y/n] Y"
    echo "Reload privilege tables now? [Y/n] Y"

    echo Configureer de MYSQL installatie
    sudo mysql_secure_installation
}
MariaDB_Installeren
echo "MariaDB is geconfigureerd"


Databases_Aanmaken() {
    echo Een nieuwe database en gebruiker maken voor Nextcloud
    sudo mysql
    CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY 'Password123';
    CREATE DATABASE nextcloud;
    GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';
    FLUSH PRIVILEGES;
    EOF

    echo Een nieuwe database en gebruiker maken voor WordPress
    sudo mysql
    CREATE USER 'wordpress'@'localhost' IDENTIFIED BY 'Password123';
    CREATE DATABASE wordpress;
    GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost';
    FLUSH PRIVILEGES;
    EOF

}
MariaDB_Installeren > /dev/null
echo "MariaDB is geconfigureerd"


Nextcloud_Installeren() {
    echo Nextcloud Downloaden
    cd /tmp || exit
    wget https://download.nextcloud.com/server/releases/latest.tar.bz2
    tar -xvjf latest.tar.bz2
    sudo mv nextcloud /var/www/

    echo regels instellen voor de Nextcloud-directory
    sudo chown -R www-data:www-data /var/www/nextcloud/
    sudo chmod -R 755 /var/www/nextcloud/

    echo Apache virtuele host configureren voor Nextcloud
    sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/nextcloud.conf
    sudo sed -i 's/DocumentRoot \/var\/www\/html/DocumentRoot \/var\/www\/nextcloud/g' /etc/apache2/sites-available/nextcloud.conf
    sudo sed -i 's/<Directory \/var\/www\/html>/<Directory \/var\/www\/nextcloud>/g' /etc/apache2/sites-available/nextcloud.conf
    sudo a2ensite nextcloud.conf
    sudo a2enmod rewrite

    echo Nextcloud configureren om de gegevensmap op de andere schijf te gebruiken
    sudo -u www-data php /var/www/nextcloud/occ config:system:set datadirectory --value="/data"
}
Nextcloud_Installeren > /dev/null
echo "Nextcloud is geinstalleerd"

Wordpress_Installeren() {
    echo Wordpress downloaden
    cd /tmp || exit
    wget https://wordpress.org/latest.tar.gz
    tar -xzvf latest.tar.gz
    sudo mv wordpress /var/www/html/

    echo regels instellen voor de WordPress-directory
    sudo chown -R www-data:www-data /var/www/html/wordpress
    sudo chmod -R 755 /var/www/html/wordpress

    echo Apache virtuele host configureren voor WordPress
    sudo cp /etc/apache2/sites-available/nextcloud.conf /etc/apache2/sites-available/wordpress.conf
    sudo sed -i 's/ServerName/ServerAlias/g' /etc/apache2/sites-available/wordpress.conf
    sudo sed -i 's/nextcloud/wordpress/g' /etc/apache2/sites-available/wordpress.conf
    sudo sed -i 's//var/www/nextcloud//var/www/html/wordpress/g' /etc/apache2/sites-available/wordpress.conf
    sudo sed -i 's/www-data/wordpress/g' /etc/apache2/sites-available/wordpress.conf
    sudo a2ensite wordpress.conf

    echo Apache restarten
    sudo systemctl restart apache2
}
Wordpress_Installeren > /dev/null
echo "Wordpress is geinstalleerd"

Webmin_Installeren() {
    echo Webmin Installeren
    sudo echo "deb https://download.webmin.com/download/repository sarge contrib" | sudo tee -a /etc/apt/sources.list
    sudo wget -q https://www.webmin.com/jcameron-key.asc -O- | sudo apt-key add -
    sudo apt update
    sudo apt install -y webmin
}
Webmin_Installeren > /dev/null
echo "Webmin is geinstalleerd"

echo "Installatie Voltooit!"
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "NEXTCLOUD_URL="http://${SERVER_IP}/nextcloud/""
echo "WEBMIN_URL="https://${SERVER_IP}:10000/""
echo "WORDPRESS_URL="http://${SERVER_IP}/wordpress/""


#!/bin/bash
echo "Script Gemaakt door Bram Suurd"
echo "134587@student.drenthecollege.nl"

if [ "$USER" != "root" ]
then
    echo "Voer dit uit als root of met sudo"
    exit 2
fi

MariaDB_Installeren_Configureren() {
    echo "Voeg ondrej/php PPA toe en werk package lists bij"
    sudo apt-get update
    sudo apt-get install -y gnupg2 ca-certificates curl 
    sudo wget https://packages.sury.org/php/apt.gpg -O /etc/apt/trusted.gpg.d/php.gpg
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php.list
    sudo apt-get update

    echo "Installeer Apache, MariaDB, PHP 8.1 en vereiste modules"
    sudo apt-get install -y apache2 mariadb-server php8.1 libapache2-mod-php8.1 php8.1-gd php8.1-mysql php8.1-curl php8.1-mbstring php8.1-intl php8.1-imagick php8.1-xml php8.1-zip
    sudo systemctl restart apache2

    systemctl start apache2.service
    systemctl enable apache2.service
    echo "Configureer de MYSQL installatie"
    sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '123';"
    sudo mysql -e "DELETE FROM mysql.user WHERE User='';"
    sudo mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    sudo mysql -e "DROP DATABASE IF EXISTS test;"
    sudo mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    sudo mysql -e "FLUSH PRIVILEGES;"
    echo "MariaDB is geconfigureerd"

    echo "Een nieuwe database en gebruiker maken voor Nextcloud"
    sudo mysql -u root -p -e "CREATE DATABASE nextcloud;"
    sudo mysql -u root -p -e "CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY '123';"
    sudo mysql -u root -p -e "GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';"
    sudo mysql -u root -p -e "FLUSH PRIVILEGES;"

    echo "Een nieuwe database en gebruiker maken voor WordPress"
    sudo mysql -u root -p -e "CREATE DATABASE wordpress;"
    sudo mysql -u root -p -e "CREATE USER 'wordpress'@'localhost' IDENTIFIED BY '123';"
    sudo mysql -u root -p -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost';"
    sudo mysql -u root -p -e "FLUSH PRIVILEGES;"

    echo "Databases zijn aangemaakt"
}
MariaDB_Installeren_Configureren
echo "MariaDB is geinstalleerd en geconfigureerd"



Nextcloud_Installeren() {
    echo "Nextcloud downloaden..."
    #sudo curl -O https://download.nextcloud.com/server/releases/latest.tar.bz2
    sudo tar -xvjf latest.tar.bz2 || { echo "Uitpakken mislukt"; exit 1; }
    sudo mv nextcloud /var/www/html/ || { echo "Verplaatsen mislukt"; exit 1; }

    echo "Regels instellen voor de Nextcloud-directory..."
    sudo chown -R www-data:www-data /var/www/html/nextcloud/ || { echo "Chown mislukt"; exit 1; }
    sudo chmod -R 755 /var/www/html/nextcloud/ || { echo "Chmod mislukt"; exit 1; }

    echo "Apache virtuele host configureren voor Nextcloud..."
    sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/nextcloud.conf || { echo "Kopiëren mislukt"; exit 1; }
    sudo sed -i 's/DocumentRoot \/var\/www\/html/DocumentRoot \/var\/www\/html\/nextcloud/g' /etc/apache2/sites-available/nextcloud.conf || { echo "Aanpassen mislukt"; exit 1; }
    sudo sed -i 's/<Directory \/var\/www\/html>/<Directory \/var\/www\/html\/nextcloud>/g' /etc/apache2/sites-available/nextcloud.conf || { echo "Aanpassen mislukt"; exit 1; }
    sudo a2ensite nextcloud.conf || { echo "Virtuele host activeren mislukt"; exit 1; }
    sudo a2enmod rewrite || { echo "Module activeren mislukt"; exit 1; }

    echo "Nextcloud configureren om de gegevensmap op de andere schijf te gebruiken..." || { echo "Configuratie mislukt"; exit 1; }
}

Nextcloud_Installeren

echo "Nextcloud is geïnstalleerd."

Wordpress_Installeren() {
    echo Wordpress downloaden
    cd /tmp || exit
    wget https://wordpress.org/latest.tar.gz
    tar -xzvf latest.tar.gz
    mv wordpress /var/www/html/

    echo regels instellen voor de WordPress-directory
    chown -R www-data:www-data /var/www/html/wordpress
    chmod -R 755 /var/www/html/wordpress

    echo Apache virtuele host configureren voor WordPress
    cp /etc/apache2/sites-available/nextcloud.conf /etc/apache2/sites-available/wordpress.conf
    sed -i 's/ServerName/ServerAlias/g' /etc/apache2/sites-available/wordpress.conf
    sed -i 's/nextcloud/wordpress/g' /etc/apache2/sites-available/wordpress.conf
    sed -i 's//var/www/nextcloud//var/www/html/wordpress/g' /etc/apache2/sites-available/wordpress.conf
    sed -i 's/www-data/wordpress/g' /etc/apache2/sites-available/wordpress.conf
    a2ensite wordpress.conf
    sudo chown www-data:www-data /data -R

    echo Apache restarten
    systemctl restart apache2
}
Wordpress_Installeren
echo "Wordpress is geinstalleerd"

Webmin_Installeren() {
    echo Webmin Installeren
    echo "deb https://download.webmin.com/download/repository sarge contrib" | tee -a /etc/apt/sources.list
    wget -q https://www.webmin.com/jcameron-key.asc -O- | apt-key add -
    apt update
    apt install -y webmin
}
Webmin_Installeren
echo "Webmin is geinstalleerd"

Backups_instellen() {
apt-get update
apt-get install -y rsync cron
mkdir -p /back/backups
rsync -avr /data /back/backups
(crontab -l ; echo "0 0 * * * rsync -avr /data /back/backups") | crontab -

}
Backups_instellen
echo "Backups zijn nu ingesteld"

echo "Installatie Voltooid!"
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "NEXTCLOUD_URL="http://${SERVER_IP}/nextcloud/""
echo "WEBMIN_URL="https://${SERVER_IP}:10000/""
echo "WORDPRESS_URL="http://${SERVER_IP}/wordpress/""

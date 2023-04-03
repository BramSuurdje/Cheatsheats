#!/bin/bash
# Gemaakt door Bram Suurd
# 134587@student.drenthecollege.nl

if [ "$USER" != "root" ]
then
    echo "Voer dit uit als root of met sudo"
    exit 2
fi

DIALOG_INSTALLED=$(dpkg-query -W --showformat='${Status}\n' dialog|grep "install ok installed")

if [ "$DIALOG_INSTALLED" == "" ]; then
  echo "Dialog is niet geïnstalleerd, nu installeren ..."
  apt-get update > /dev/null 2>&1
  apt-get install -y dialog > /dev/null 2>&1
fi

MariaDB_Installeren_Configureren() {
    echo "Voeg ondrej/php PPA toe en werk de package lists bij"
    apt-get install -y gnupg2 gnupg ca-certificates curl 
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list >/dev/null
    apt update -y
    required_packages=("apache2" "mariadb-server" "curl" "php8.1" "libapache2-mod-php8.1" "php8.1-gd" "php8.1-mysql" "php8.1-curl" "php8.1-mbstring" "php8.1-intl" "php8.1-imagick" "php8.1-xml" "php8.1-zip")
    for package in "${required_packages[@]}"; do
        if ! dpkg -s "$package" >/dev/null 2>&1; then
            apt-get install -y "$package"
        fi
    done

    systemctl restart apache2
    systemctl enable apache2.service

    mysql -u root -p123 << EOF
        ALTER USER 'root'@'localhost' IDENTIFIED BY '123';
        DELETE FROM mysql.user WHERE User='';
        DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
        DROP DATABASE IF EXISTS test;
        DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
        FLUSH PRIVILEGES;
EOF

    mysql -u root -p123 << EOF
        CREATE DATABASE IF NOT EXISTS nextcloud;
        CREATE USER IF NOT EXISTS 'nextcloud'@'localhost' IDENTIFIED BY '123';
        GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';
        CREATE DATABASE IF NOT EXISTS wordpress;
        CREATE USER IF NOT EXISTS 'wordpress'@'localhost' IDENTIFIED BY '123';
        GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost';
        FLUSH PRIVILEGES;
EOF
} 

Nextcloud_Installeren() {
    echo "Nextcloud downloaden..."
    if [ -e latest.tar.bz2 ]; then
        echo "Nextcloud is al gedownload, downloaden wordt overgeslagen"
    else
        curl -o latest.tar.bz2 https://download.nextcloud.com/server/releases/latest.tar.bz2

    fi

    tar -xvjf latest.tar.bz2 -C /var/www/html/

    echo "Regels instellen voor de Nextcloud-directory..."
    chown -R www-data:www-data /var/www/html/nextcloud/
    chmod -R u+rwX,g+rX,o+rX /var/www/html/nextcloud/
    chown www-data:www-data /var/www/html/nextcloud
    chown -R www-data:www-data /data


    echo "Apache virtuele host configureren voor Nextcloud..."
    cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/nextcloud.conf
    sed -i 's/DocumentRoot \/var\/www\/html/DocumentRoot \/var\/www\/html\/nextcloud/g' /etc/apache2/sites-available/nextcloud.conf
    sed -i 's/<Directory \/var\/www\/html>/<Directory \/var\/www\/html\/nextcloud>/g' /etc/apache2/sites-available/nextcloud.conf
    a2ensite nextcloud.conf
    a2enmod rewrite

    if [ $? -eq 0 ]; then
        echo "Nextcloud is geïnstalleerd."
    else
        echo "Er is iets fout gegaan bij het configureren van Apache voor Nextcloud."
    fi
}

Wordpress_Installeren() {
    echo "Wordpress downloaden..."
    if [ -e /tmp/latest.tar.gz ]; then
        echo "Wordpress is al gedownload, downloaden wordt overgeslagen"
    else
        curl -o /tmp/latest.tar.gz https://wordpress.org/latest.tar.gz
    fi

    tar -xzf /tmp/latest.tar.gz -C /var/www/html/
    chown -R www-data:www-data /var/www/html/wordpress
    chmod -R 755 /var/www/html/wordpress

    echo "Apache virtuele host configureren voor Wordpress..."
    cp /etc/apache2/sites-available/nextcloud.conf /etc/apache2/sites-available/wordpress.conf
    sed -i 's/ServerName/ServerAlias/g; s/nextcloud/wordpress/g; s#/var/www/nextcloud#/var/www/html/wordpress#g; s/www-data/wordpress/g' /etc/apache2/sites-available/wordpress.conf
    a2ensite wordpress.conf

    echo "Apache herstarten..."
    systemctl restart apache2
}

Backups_instellen() {
    apt update && apt install -y rsync cron
    mkdir -p /back/backups
    rsync -avr --delete /data /back/backups
    (crontab -l ; echo "0 0 * * * /usr/bin/rsync -avr --delete /data /back/backups") | crontab -
}

Webmin_Installeren() {
    echo Webmin Installeren
    echo "deb https://download.webmin.com/download/repository sarge contrib" | tee -a /etc/apt/sources.list
    wget -q https://www.webmin.com/jcameron-key.asc -O- | apt-key add -
    apt update
    apt install -y webmin
}

Post_Install() {
  echo "Hierbij alle web-interfaces"
  SERVER_IP=$(hostname -I | awk '{print $1}')
  echo "Nextcloud URL: http://${SERVER_IP}/nextcloud/"
  echo "Webmin URL: https://${SERVER_IP}:10000/"
  echo "WordPress URL: http://${SERVER_IP}/wordpress/"
}

Gebruikers_Toevoegen() {

    echo "voer de naam van de nieuwe gebruiker in"
    read naam
    echo "Voer het personeelsnummer in:"
    read personeelsnummer
    echo "Voer de juiste Afdeling in:"
    echo "De afdelingen zijn"
    echo "Administratie"
    echo "Directie"
    echo "Verkoop"
    echo "-------------------"
    read personeelsafdeling

groups=("Administratie" "Directie" "Verkoop") 

occ="/var/www/html/nextcloud/occ"

for group in "${groups[@]}"
do
    if grep -q "^$group:" /etc/group; then
        echo "Group $group already exists"
    else
        echo "Group $group does not exist, creating it..."
        groupadd "$group"
        sudo -u www-data php "$occ" group:create "$group"
        echo "Group $group created"
    fi
done


    wachtwoord=$(echo "($personeelsnummer*3)+5" | bc)$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 3 | head -n 1)'!'$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 2 | head -n 1)'#'

    useradd -m -d /home/$personeelsnummer -s /bin/bash -p $(echo $wachtwoord | openssl passwd -1 -stdin) $personeelsnummer

    usermod -aG $personeelsafdeling $personeelsnummer

    export OC_PASS="$wachtwoord"
    sudo -u www-data php $occ user:add --display-name $naam --password "$wachtwoord" "$personeelsnummer"

    echo "Gebruiker $naam is aangemaakt met de inlognaam $personeelsnummer, met wachtwoord $wachtwoord en toegevoegd aan de groep $personeelsafdeling"
}

HEIGHT=15
WIDTH=60
CHOICE_HEIGHT=6
BACKTITLE="Bram Suurd 134587"
TITLE="Linux Drenthecollege"
MENU="Kies een van de volgende opties:"

OPTIONS=(1 "Alle Scripts Uitvoeren"
         2 "Specifieke Scripts Uitvoeren"
         3 "Alle web links laten zien"
         4 "Gebruikers Toevoegen"
         5 "Exit")

while true; do
    CHOICE=$(dialog --clear \
                    --backtitle "$BACKTITLE" \
                    --title "$TITLE" \
                    --menu "$MENU" \
                    $HEIGHT $WIDTH $CHOICE_HEIGHT \
                    "${OPTIONS[@]}" \
                    2>&1 >/dev/tty)

    if [[ $CHOICE =~ ^[1-5]$ ]]; then
        clear
        break
    else
        echo "Ongeldige invoer. Voer een getal in tussen 1 en 5."
    fi

done

case $CHOICE in
    1)
        echo "MariaDB instellen en configureren..."
        MariaDB_Installeren_Configureren || echo "Fout bij het installeren van MariaDB"
        echo "Nextcloud aan het installeren..."
        Nextcloud_Installeren || echo "Fout bij het installeren van Nextcloud"
        echo "Wordpress aan het installeren..."
        Wordpress_Installeren || echo "Fout bij het installeren van Wordpress"
        echo "Webmin aan het installeren..."
        Webmin_Installeren || echo "Fout bij het installeren van Webmin"
        echo "Back-ups instellen..."
        Backups_instellen || echo "Fout bij het instellen van back-ups"
        Post_Install
        ;;
    2)
        # sub-menu loop
        while true; do
            SUBMENU="Kies een van de volgende opties:"
            SUBOPTIONS=(1 "MariaDB Installeren en instellen"
                        2 "Nextcloud Installeren"
                        3 "Wordpress Installeren"
                        4 "Webmin Installeren"
                        5 "Back-ups Instellen"
                        6 "Terug naar menu")
            SUBCHOICE=$(dialog --clear \
                               --backtitle "$BACKTITLE" \
                               --title "Specifieke Scripts Uitvoeren" \
                               --menu "$SUBMENU" \
                               $HEIGHT $WIDTH $CHOICE_HEIGHT \
                               "${SUBOPTIONS[@]}" \
                               2>&1 >/dev/tty)

            if [[ $SUBCHOICE =~ ^[1-6]$ ]]; then
                clear
                break
            else
                echo "Ongeldige invoer. Voer een getal in tussen 1 en 6."
            fi
        done

        case $SUBCHOICE in
            1)
                echo "MariaDB instellen en configureren..."
                MariaDB_Installeren_Configureren || echo "Fout bij het installeren van MariaDB"
                ;;
            2)
                echo "Nextcloud aan het installeren..."
                Nextcloud_Installeren || echo "Fout bij het installeren van Nextcloud"
                ;;
            3)
                echo "Wordpress aan het installeren..."
                Wordpress_Installeren || echo "Fout bij het installeren van Wordpress"
                ;;
            4)
                echo "Webmin Installeren"
                Webmin_Installeren || echo "Fout bij het installeren van Webmin"
                ;;
            5)
                echo "Back-ups instellen..."
                Backups_instellen || echo "Fout bij het instellen van back-ups"
                ;;
            6)
                exit 0
                ;;
            *)
                echo "Invalid option selected. Please try again."
                ;;
        esac
        ;;
    3)
        Post_Install
        ;;
    4)
        Gebruikers_Toevoegen
        ;;
    5)
        exit
        ;;
    *)
        echo "Ongeldige optie geselecteerd. Probeer het opnieuw."
        ;;
esac

echo "Druk op Enter om door te gaan..."
read
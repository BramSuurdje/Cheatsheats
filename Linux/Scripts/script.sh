#!/bin/bash
# Gemaakt door Bram Suurd
# 134587@student.drenthecollege.nl

    if [ "$USER" != "root" ]
    then
        echo "Voer dit uit als root"
        exit 2
    fi

    if ! command -v dialog &> /dev/null
    then
        echo "dialog is niet geïnstalleerd, nu installeren..."
        apt install -y dialog > /dev/null
    fi

function Schijven_Mounten() {
    if ! command -v parted &> /dev/null
    then
        echo "Parted is niet geïnstalleerd, nu installeren..."
        apt install -y parted > /dev/null
    fi

    clear

    # List all disks and their sizes
    disks=$(lsblk -o NAME,SIZE -d -p -n)

    # Extract the last letter of the disk names
    letter1=$(echo "$disks" | awk '/100G/ { print substr($1, length($1)-2, 1) }')
    letter2=$(echo "$disks" | awk '/50G/ { print substr($1, length($1)-2, 1) }' | head -n 1)
    letter3=$(echo "$disks" | awk '/50G/ { print substr($1, length($1)-2, 1) }' | tail -n 1)

    mount1="/data"
    mount2="/back"
    mount3="/ftp"

    device1="/dev/sd$letter1"
    device2="/dev/sd$letter2"
    device3="/dev/sd$letter3"

    parted -s $device1 mklabel gpt mkpart primary ext4 0% 100%
    parted -s $device2 mklabel gpt mkpart primary ext4 0% 100%
    parted -s $device3 mklabel gpt mkpart primary ext4 0% 100%

    mkdir -p $mount1
    mkdir -p $mount2
    mkdir -p $mount3

    mkfs.ext4 ${device1}1
    mkfs.ext4 ${device2}1
    mkfs.ext4 ${device3}1

    uuid1=$(blkid -o value -s UUID ${device1}1)
    uuid2=$(blkid -o value -s UUID ${device2}1)
    uuid3=$(blkid -o value -s UUID ${device3}1)

    echo "UUID=$uuid1    $mount1    ext4    defaults    0    2" | tee -a /etc/fstab
    echo "UUID=$uuid2    $mount2    ext4    defaults    0    2" | tee -a /etc/fstab
    echo "UUID=$uuid3    $mount3    ext4    defaults    0    2" | tee -a /etc/fstab

    mount -a

    echo "Start uw systeem opnieuw op om alles toe te passen. Wilt u nu opnieuw opstarten? (y/n)"
    read answer

    if [ "$answer" != "${answer#[Yy]}" ]; then
        reboot
    fi
}


function Dependencies_Installeren() {
    if [ -f /tmp/dependencies-installed ]; then
        echo "Dependencies zijn al geinstalleerd. Skipping..."
        return 0
    fi

    echo "Voeg ondrej/php PPA toe en werk de package lists bij..."
    apt-get install -y gnupg2 gnupg ca-certificates curl 
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list >/dev/null
    apt update -y
    required_packages=("apache2" "mariadb-server" "curl" "php" "libapache2-mod-php" "php-gd" "php-mysql" "php-curl" "php-mbstring" "php-intl" "php-imagick" "php-xml" "php-zip" "php-json")
    for package in "${required_packages[@]}"; do
        if ! dpkg -s "$package" >/dev/null 2>&1; then
            apt-get install -y "$package"
        fi
    done

    touch /tmp/dependencies-installed
} 


function MariaDB_Configureren() {
    systemctl restart apache2
    systemctl enable apache2.service

    clear
    echo "Wat moet het wachtwoord worden van de databases?"
    read db_password

    nextcloud_dbuser="nextcloud"
    nextcloud_dbname="nextcloud"
    wordpress_dbuser="wordpress"
    wordpress_dbname="wordpress"


    mysql -u root -p$db_password << EOF
    ALTER USER 'root'@'localhost' IDENTIFIED BY '$db_password';
    DELETE FROM mysql.user WHERE User='';
    DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
    FLUSH PRIVILEGES;
EOF

    mysql -u root -p$db_password << EOF
    CREATE DATABASE IF NOT EXISTS $nextcloud_dbname;
    CREATE USER IF NOT EXISTS '$nextcloud_dbuser'@'localhost' IDENTIFIED BY '$db_password';
    GRANT ALL PRIVILEGES ON $nextcloud_dbname.* TO '$nextcloud_dbname'@'localhost';
    CREATE DATABASE IF NOT EXISTS $wordpress_dbname;
    CREATE USER IF NOT EXISTS '$wordpress_dbuser'@'localhost' IDENTIFIED BY '$db_password';
    GRANT ALL PRIVILEGES ON $wordpress_dbname.* TO '$wordpress_dbuser'@'localhost';
    FLUSH PRIVILEGES;
EOF
}


function Nextcloud_Installeren() {
    NEXTCLOUD_PATH=/var/www/html/nextcloud
    if [ -d "$NEXTCLOUD_PATH" ]; then
        echo "Nextcloud is al geïnstalleerd."
        return 0
    fi

    echo "Nextcloud downloaden..."
    if [ -e latest.tar.bz2 ]; then
        echo "Nextcloud is al gedownload, downloaden wordt overgeslagen."
    else
        curl -o latest.tar.bz2 https://download.nextcloud.com/server/releases/latest.tar.bz2
    fi

    tar -xvjf latest.tar.bz2 -C "/var/www/html"
    rm latest.tar.bz2
    echo "Regels instellen voor de Nextcloud-directory..."
    chown -R www-data:www-data "$NEXTCLOUD_PATH"
    chmod -R u+rwX,g+rX,o+rX "$NEXTCLOUD_PATH"
    chown -R www-data:www-data /data

    echo "Apache virtuele host configureren voor Nextcloud..."
    DEFAULT_CONF=/etc/apache2/sites-available/000-default.conf
    NEXTCLOUD_CONF=/etc/apache2/sites-available/nextcloud.conf
    cp "$DEFAULT_CONF" "$NEXTCLOUD_CONF"
    sed -i 's/DocumentRoot \/var\/www\/html/DocumentRoot \/var\/www\/html\/nextcloud/g' "$NEXTCLOUD_CONF"
    sed -i 's/<Directory \/var\/www\/html>/<Directory \/var\/www\/html\/nextcloud>/g' "$NEXTCLOUD_CONF"
    a2ensite nextcloud.conf
    a2enmod rewrite

    if [ $? -eq 0 ]; then
        echo "Nextcloud is geïnstalleerd."
    else
        echo "Er is iets fout gegaan bij het configureren van Apache voor Nextcloud."
    fi
}


function Wordpress_Installeren() {
    echo "Wordpress downloaden..."
    if [ -e /tmp/latest.tar.gz ]; then
        echo "Wordpress is al gedownload, downloaden wordt overgeslagen"
    else
        if ! curl -o /tmp/latest.tar.gz https://wordpress.org/latest.tar.gz; then
            echo "Fout bij het downloaden van Wordpress"
            exit 1
        fi
    fi
    
    if ! tar -xzf /tmp/latest.tar.gz -C /var/www/html/; then
        echo "Fout bij het uitpakken van Wordpress"
        exit 1
    fi

    chown -R www-data:www-data /var/www/html/wordpress
    chmod -R u=rwX,g=rX,o=rX /var/www/html/wordpress
    find /var/www/html/wordpress -type d -exec chmod g+s {} +

    echo "Apache virtuele host configureren voor Wordpress..."
    cp /etc/apache2/sites-available/nextcloud.conf /etc/apache2/sites-available/wordpress.conf
    sed -i 's/ServerName/ServerAlias/g; s/nextcloud/wordpress/g; s#/var/www/nextcloud#/var/www/html/wordpress#g; s/www-data/wordpress/g' /etc/apache2/sites-available/wordpress.conf
    a2ensite wordpress.conf

    echo "Apache herstarten..."
    if ! systemctl restart apache2; then
        echo "Fout bij het herstarten van Apache"
        exit 1
    fi
} 


function Backups_instellen() {
    set -e

    BACKUP_DIR=/back/backups

    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
    fi

    rsync -avr --delete /data "$BACKUP_DIR"

    if [ "$?" -eq 0 ]; then
        (crontab -l ; echo "0 0 * * * /usr/bin/rsync -avr --delete /data $BACKUP_DIR") | crontab -
    else
        echo "Error: rsync command failed."
    fi
} 


function Webmin_Installeren() {
    set -e

    REPO_URL="deb https://download.webmin.com/download/repository sarge contrib"
    GPG_KEY_URL="https://www.webmin.com/jcameron-key.asc"

    apt-get update
    apt-get install -y wget gnupg
    wget -q "$GPG_KEY_URL" -O- | apt-key add -
    echo "$REPO_URL" | tee -a /etc/apt/sources.list
    apt-get update
    apt-get install -y webmin
} 

function Docker_Installeren() {
    apt-get update -y
    apt-get install ca-certificates curl gnupg -y
    mkdir -m 0755 -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y
    apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
}

function Post_Install() {
    set -e
    mkdir -p /data/gegevens
    clear

    WEBMIN_PORT=10000
    SERVER_IP=$(hostname -I | awk '{print $1}')
    NEXTCLOUD_URL="http://${SERVER_IP}/nextcloud/"
    WEBMIN_URL="https://${SERVER_IP}:${WEBMIN_PORT}/"
    WORDPRESS_URL="http://${SERVER_IP}/wordpress/"

    { 
    echo "Hierbij alle web-interfaces:"
    echo "Nextcloud URL: $NEXTCLOUD_URL"
    echo "Webmin URL: $WEBMIN_URL"
    echo "WordPress URL: $WORDPRESS_URL"
    echo " "
    echo "Nextcloud DataDirectory: /data"
    echo "Nextcloud gebruikersnaam: $nextcloud_dbuser"
    echo "Nextcloud wachtwoord: $db_password"
    echo "Nextcloud database: $nextcloud_dbname"
    echo "Nextcloud DatabaseServer: Localhost"
    echo " "
    echo "Wordpress database: $wordpress_dbname"
    echo "Wordpress gebruikersnaam: $wordpress_dbuser"
    echo "Wordpress wachtwoord: $db_password"
    echo "Wordpress DatabaseServer: Localhost"
    } |& tee -a /data/gegevens/wachtwoorden.txt

}

function Gegevens_Weblinks() {
    Weblinks_Path="/data/gegevens/wachtwoorden.txt"

    if [ -f "$Weblinks_Path" ]; then
    cat "$Weblinks_Path"
    else
        echo ""
    fi
}

function Gegevens_Weblinks() {
    Weblinks_Path="/data/gegevens/wachtwoorden.txt"

    if [ -f "$Weblinks_Path" ]; then
    cat "$Weblinks_Path"
    else
    echo "File $Weblinks_Path does not exist"
    fi
}

function Gebruikers_Toevoegen() {

    su -s /bin/sh www-data -c "php" /var/www/html/nextcloud/occ config:system set default_language --value="nl"

    printf "Voer de naam van de nieuwe gebruiker in: "
    read username

    printf "Voer het personeelsnummer in: "
    read employee_number

    printf "Voer de juiste afdeling in:\n"
    printf "1. Administratie\n"
    printf "2. Directie\n"
    printf "3. Verkoop\n"
    read -p "Afdeling: " department_number

    case $department_number in
        1) department="Administratie" ;;
        2) department="Directie" ;;
        3) department="Verkoop" ;;
        *) echo "Ongeldig afdelingsnummer" && return ;;
    esac

    if id -u "$username" >/dev/null 2>&1; then
        printf "Gebruiker %s bestaat al\n" "$username"
        return
    fi

    if getent group "$department" >/dev/null 2>&1; then
        printf "Groep %s bestaat al\n" "$department"
    else
        printf "Groep aanmaken %s\n" "$department"
        groupadd "$department"
        -u www-data php /var/www/html/nextcloud/occ group:add --quota=5G \"$department\"
    fi
    
    if ! command -v pwgen &> /dev/null
    then
        echo "pwgen is niet geinstalleerd, nu installeren..."
        apt install pwgen -y
    else
        echo ""
    fi

    password=$(pwgen -1cnsy 16)
    hashed_password=$(openssl passwd -1 "$password")

    useradd -m -d "/home/$employee_number" -s /bin/bash -p "$hashed_password" "$employee_number"
    usermod -aG "$department" "$employee_number"
    export OC_PASS=$password
    su -s /bin/sh www-data -c "php /var/www/html/nextcloud/occ user:add --password-from-env --display-name=\"$username\" --group=\"$department\" \"$employee_number\""
    su -s /bin/sh www-data -c "php /var/www/html/nextcloud/occ user:setting \"$employee_number\" files quota 5G"

    mkdir -p /data/user-accounts && printf "Gebruiker %s is aangemaakt met gebruikersnaam %s, wachtwoord %s, en toegevoegd aan de groep %s met een quota van 5GB\n" "$username" "$employee_number" "$password" "$department" | tee -a /data/user-accounts/$employee_number-Wachtwoord.txt

} 

function Menu() {

HEIGHT=15
WIDTH=60
CHOICE_HEIGHT=6
BACKTITLE="Linux Project"
TITLE="Linux Drenthecollege"
MENU="Kies een van de volgende opties:"

OPTIONS=(1 "Gebruikers Toevoegen"
         2 "Schijven Mounten"
         3 "Alle web links laten zien"
         4 "Specifieke Scripts uitvoeren"
         5 "Compleet script runnen"
         6 "Exit")

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
        echo "Ongeldige invoer. Voer een getal in tussen 1 en 6."
    fi

done

case $CHOICE in
    1)
        Gebruikers_Toevoegen
        ;;
    2)
        echo "Beginnen met het mounten van de schijven..."
        Schijven_Mounten || echo "Fout bij het Mounten van de schijven"
        ;;
    3)
        Gegevens_Weblinks
        ;;
    4)
        while true; do
            SUBMENU="Kies een van de volgende opties:"
            SUBOPTIONS=(1 "MariaDB Installeren en instellen"
                        2 "Nextcloud Installeren"
                        3 "Wordpress Installeren"
                        4 "Webmin Installeren"
                        5 "Docker Installeren"
                        6 "Back-ups Instellen"
                        7 "Terug naar menu")
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
                Dependencies_Installeren || echo "Fout bij het installeren van dependencies"
                MariaDB_Installeren_Configureren || echo "Fout bij het installeren van MariaDB"
                ;;
            2)
                echo "Nextcloud aan het installeren..."
                Dependencies_Installeren || echo "Fout bij het installeren van dependencies"
                Nextcloud_Installeren || echo "Fout bij het installeren van Nextcloud"
                ;;
            3)
                echo "Wordpress aan het installeren..."
                Dependencies_Installeren || echo "Fout bij het installeren van dependencies"
                Wordpress_Installeren || echo "Fout bij het installeren van Wordpress"
                ;;
            4)
                echo "Webmin Installeren"
                Dependencies_Installeren || echo "Fout bij het installeren van dependencies"
                Webmin_Installeren || echo "Fout bij het installeren van Webmin"
                ;;
            5)
                echo "Docker Installeren"
                Docker_Installeren || echo "Fout bij het installeren van Docker"
                ;;
            6)
                echo "Back-ups instellen..."
                Dependencies_Installeren || echo "Fout bij het installeren van dependencies"
                Backups_instellen || echo "Fout bij het instellen van back-ups"
                ;;
            7)
                exit 0
                ;;
            *)
                echo "Invalid option selected. Please try again."
                ;;
        esac
        ;;
    5)
        echo "Dependencies aan het installeren..."
        Dependencies_Installeren || echo "Fout bij het installeren van dependencies"
        echo "MariaDB aan het Configureren..."
        MariaDB_Configureren || echo "Fout bij het configureren van Mariadb"
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
    6)
        exit
        ;;
    *)
        echo "Ongeldige invoer. Voer een getal in tussen 1 en 7."
        ;;
esac
}
Menu

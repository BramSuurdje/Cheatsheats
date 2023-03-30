# dit is wat je allemaal vanaf begin moet doen
##### Voeg de 3 extra schrijfen toe aan de VM
##### 1x 50G
##### 1x 50G
##### 1x 100G

login als root en download sudo, en voeg jezelf toe aan de sudo groep.
```bash
su -
apt install sudo
usermod -aG sudo (gebruikersnaam)
```
##### nu gaan we de folders aanmaken
```bash
sudo mkdir /data
sudo mkdir /back
sudo mkdir /ftp
```
##### kijk welke 3 schijfen er nieuw zijn met de command lsblk, deze heten meestal sda, sdb, sdc.
##### nu gaan we de schijfen aanmaken
```bash
sudo cfdisk /dev/sdb 
```
Als labeltype kiezen we gpt.
Maak nu een partition aan
klik op "write" en dan "quit" doe deze stappen opnieuw voor de andere schijf

##### ga nu de schijfen formatteren
```bash
sudo mkfs.ext4 /dev/sdb1
```

##### zoek nu de UUIDs op van de nieuwe schrijfen
```bash
sudo blkid
```
##### nu gaan we met de fstab de schijven aan de mappen mounten 
```bash
sudo nano /etc/fstab
```

##### in deze file zetten we de volgende lines
```bash
# /data
UUID=ea0d7b33-0fe8-47c4-ab4a-2f00733a2dcf /data	ext4	defaults	0	2
# /ftp
UUID=20606b0d-e633-4b23-b713-7d312a6c6517 /ftp 	ext4 defaults 	0 	2
# /back
UUID=20606b0d-e633-4b23-b713-7d312a6c6517 /back ext4 defaults 	0 	2
```
## De UUID hierboven is bedoeld als voorbeeld! Kopieer hier de UUID die je in de vorige stap hebt achterhaald. Tussen de UUID-code en de mount (/data en /back) druk je 1x de <SPATIEBALK> in. Na de mount (/data en /back) moet je de <TAB>-toets gebruiken om de opties gescheiden te houden. Wanneer je de <SPATIEBALK> gebruikt krijg je een error.

##### Controleer met het commando "sudo mount -a" of alles goed is gelukt. Wanneer je geen foutmelding
##### krijgt dan heb je de partities op de juiste manier toegevoegd aan fstab
```bash
sudo mount -a
sudo reboot now
```

##### Check nu of het gelukt is.
```bash
sudo lsblk
```

##### download nu het script om de andere stappen automatisch te laten doen
```bash
wget https://raw.githubusercontent.com/br4mSuurd/Cheatsheats/main/Linux/Scripts/script.sh
chmod +x script.sh
sudo script.sh
```

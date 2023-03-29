# dit is wat je allemaal vanaf begin moet doen
```bash
su -
apt install sudo
usermod -aG sudo (gebruikersnaam)
```
Voeg de 3 extra schrijfen toe aan de VM
1x 50G
1x 50G
1x 100G

kijk welke 3 schijfen er nieuw zijn met de command lsblk, deze heten meestal sda, sdb, sdc.
```bash
sudo cfdisk /dev/sdb 
```
Als labeltype kiezen we gpt.
Maak nu een partition van 
klik op "write" en dan "quit" doe deze stappen opnieuw voor de andere schijf
ga nu de schijfen formatteren
```bash
sudo mkfs.ext4 /dev/sdb1
sudo mkfs.ext4 /dev/sdc1
```

# Alle commands die ik gebruikt heb voor het powershell code project,
# 4/6/2023

#### IP veranderen
```ps1
New-NetIPaddress -InterfaceIndex 12 -IPAddress 192.168.1.5 -PrefixLength 24 -DefaultGateway 192.168.1.1
```
#### DNS Instellingen veranderen
```ps1
Set-DNSClientServerAddress –InterfaceIndex 12 -ServerAddresses 8.8.8.8
```
#### Installeren van ADDS
```ps1
Install-WindowsFeature AD-Domain-Services –IncludeManagementTools -Verbose
```
#### ADDS Configuren
```ps1
Install-ADDSForest -DomainName powershell.dc -ForestMode Default -DomainMode Default -DomainNetbiosName POWERSHELL -InstallDns:$true
```
#### Toevoegen van een ADOG
```ps1
New-ADOrganizationalUnit -Name "Bovenliggende" -Path "DC=powershell,DC=dc"
```
#### Toevoegen van Sub-ADOG's
```ps1
New-ADOrganizationalUnit -Name "Onderliggende1" -Path "OU=Bovenliggende,DC=powershell,DC=dc"
```
dit moet je 4 keer doen, elke keer moet je het nummer veranderen.

#### Toevoegen van een Security Groep
```ps1
New-ADGroup -Name "Onderliggende1Groep" -Path "OU=Onderliggende1,OU=Topliggende,DC=contoso,DC=com" -GroupCategory Security -GroupScope Global
```
dit kun je 4 keer doen, bij elke keer moet je het nummer veranderen van 1/4

#### Toevoegen van een map en daar een netwerk share van maken
```ps1
New-Item -ItemType Directory -Path "C:\HomeFolders"
Import-Module SMBShare
New-SmbShare -Name "$Homefolders" -Path "C:\HomeFolders"
```
#### Het installeren van de DHCP feature
```ps1
Install-WindowsFeature -Name DHCP -IncludeManagementTools
```
#### Het configureren van de DHCP feature
```ps1
Add-DhcpServerV4Scope -Name "Scope1" -StartRange 10.0.0.240 -EndRange 10.0.0.240 -SubnetMask 255.255.255.0
```
#### Het installeren van Routing and remote access
```ps1
Install-WindowsFeature -Name Routing -IncludeManagementTools
```
#### DNS forward lookup zone toevoegen
```ps1
Add-DnsServerResourceRecordA -Name "WSC1" -IPv4Address "10.0.0.15" -ZoneName "powershell.dc"
```
# Import active directory module for running AD cmdlets
```ps1
Import-Module ActiveDirectory
```
#### Hier het gehele script om users toe te voegen aan het Systeem. verander onderandere de Import-Csv dir, de -HomeDirectory locatie varible.
```ps1
# Store the data from NewUsersFinal.csv in the $ADUsers variable
$ADUsers = Import-Csv C:\Users\Administrator\Desktop\Nieuwe-Gebruikers.csv ";"

$password = 'Password123'
$basePath = "\\WSC1\Home-folders"

# Loop through each row containing user details in the CSV file
foreach ($User in $ADUsers) {
    # Read user data from each field in each row and assign the data to a variable as below
    $username = $User.username
    $firstname = $User.voornaam
    $lastname = $User.achternaam
    $SecurityGroup = $User.SecurityGroep
    $OU = $User.ou

    # Check to see if the user already exists in AD
    if (Get-ADUser -F { SamAccountName -eq $username }) {
        
        # If user does exist, give a warning
        Write-Warning "Er bestaat al een gebruiker genaamt: $username"
    }
    else {
        New-ADUser `
            -SamAccountName $username `
            -UserPrincipalName "$username@$UPN" `
            -Name "$firstname $lastname" `
            -GivenName $firstname `
            -Surname $lastname `
            -Enabled $True `
            -DisplayName "$lastname, $firstname" `
            -Path $OU `
            -HomeDirectory \\WSC1\Home-Folders\$Username -homedrive 'H:' `
            -AccountPassword (ConvertTo-secureString $password -AsPlainText -Force) -ChangePasswordAtLogon $True

        Add-ADGroupMember -Identity $SecurityGroup -Members $username

        # Create the home folder for the user
        $homeFolderPath = "$basePath\$username"
        New-Item -ItemType Directory -Path $homeFolderPath

        # Set permissions on the home folder to allow the user full control
        $Acl = Get-Acl $homeFolderPath
        $Ar = New-Object  System.Security.AccessControl.FileSystemAccessRule($username,"FullControl","Allow")
        $Acl.SetAccessRule($Ar)
        Set-Acl $homeFolderPath $Acl

        # als de gebruiker is aangemaakt zeg dit.
        Write-Host "De Gebruiker: $username is aangemaakt." 
    }
}
```

#!/bin/bash

# vraag om input van de gebruiker
read -p "Geef het personeelsnummer van de gebruiker: " username
read -p "Geef de naam van de afdeling (groep) waar de gebruiker aan toegevoegd moet worden: " group_name

# genereer wachtwoord
a=$(( ( RANDOM % 10 ) + 1 ))
b=$(( ( RANDOM % 10 ) + 1 ))
c=$(( ( RANDOM % 10 ) + 1 ))
d=$(( ( RANDOM % 10 ) + 1 ))
e=$(( ( RANDOM % 10 ) + 1 ))
f=$(( ( RANDOM % 10 ) + 1 ))
g=$(( ( RANDOM % 10 ) + 1 ))
h=$(( ( RANDOM % 10 ) + 1 ))
i=$(( ( RANDOM % 10 ) + 1 ))
j=$(( ( RANDOM % 10 ) + 1 ))
k=$(( ( RANDOM % 10 ) + 1 ))
l=$(( ( RANDOM % 10 ) + 1 ))
m=$(( ( RANDOM % 10 ) + 1 ))
n=$(( ( RANDOM % 10 ) + 1 ))
o=$(( ( RANDOM % 10 ) + 1 ))
p=$(( ( RANDOM % 10 ) + 1 ))
q=$(( ( RANDOM % 10 ) + 1 ))
r=$(( ( RANDOM % 10 ) + 1 ))
s=$(( ( RANDOM % 10 ) + 1 ))
t=$(( ( RANDOM % 10 ) + 1 ))
u=$(( ( RANDOM % 10 ) + 1 ))
v=$(( ( RANDOM % 10 ) + 1 ))
w=$(( ( RANDOM % 10 ) + 1 ))
x=$(( ( RANDOM % 10 ) + 1 ))
y=$(( ( RANDOM % 10 ) + 1 ))
z=$(( ( RANDOM % 10 ) + 1 ))
special_char_1=$(printf '\x$(printf %x $(( ( RANDOM % 10 ) + 33 )))')
special_char_2=$(printf '\x$(printf %x $(( ( RANDOM % 10 ) + 33 )))')
password=$(( $a + $b + $c + $d + $e + $f + $g + $h + $i + $j ))"$special_char_1""$special_char_2""$(( $k + $l ))"

# maak gebruiker
echo "Gebruiker aanmaken..."
nextcloud user:add $username --password $password --group $group_name --home /home

# geef melding van wachtwoord
echo "Wachtwoord voor $username is: $password"

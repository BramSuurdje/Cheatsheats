Import-Module -Name Terminal-Icons
$ENV:STARSHIP_CONFIG = "$HOME/.config/starship.toml"
Invoke-Expression (&starship init powershell)

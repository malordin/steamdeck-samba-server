#!/bin/bash


RED="31"
GREEN="32"
BOLDGREEN="\e[1;${GREEN}m"
ITALICRED="\e[3;${RED}m"
ENDCOLOR="\e[0m"



if [ "$1" = "gui" ]; then
  # Script is running with a GUI argument (icon)
  if zenity --question --width=400 --height=100 --text="This script will install Samba server on your system. Did you change the password via passwd?"; then
    # User answered "yes" or "Y" or "y"
    password=$(zenity --password --title="Enter your password")
    echo "$password" | sudo -S echo "Continuing with Samba server installation..."
  else
    # User answered "no" or "N" or "n"
    zenity --error --width=400 --height=100 --text="This script requires your password to work correctly. Please change your password via passwd and try again."
    exit 1
  fi
else
  # Script is running without a GUI argument (console)
  echo "WARNING: This script will install Samba server on your system."
  read -p "Did you change the password via passwd? [Y/N] " password_choice

  case "$password_choice" in
    y|Y ) # User answered "yes" or "Y" or "y"
          read -s -p "Please enter your password: " password
          echo "$password" | sudo -S echo "Continuing with Samba server installation..." ;;
    n|N ) # User answered "no" or "N" or "n"
          echo "This script requires your password to work correctly. Please change your password via passwd and try again."
          exit 1 ;;
    * )   # User provided an invalid choice
          echo "Invalid choice, aborting script." && exit 1 ;;
  esac
fi



# Check if "deck" user's password has been changed
if [ "$(sudo grep '^deck:' /etc/shadow | cut -d':' -f2)" = "*" ] || [ "$(sudo grep '^deck:' /etc/shadow | cut -d':' -f2)" = "!" ]; then
    # Prompt user to change "deck" user's password
    echo "It looks like you haven't changed the password for the 'deck' user yet."
    read -p "Would you like to change it now? (y/n) " choice
    if [ "$choice" = "y" ]; then
        sudo passwd deck
    fi
fi

# Disable steamos-readonly
echo "Disabling steamos-readonly..."
sudo steamos-readonly disable

# Edit pacman.conf file
echo "Editing pacman.conf file..."
sudo sed -i '/^SigLevel[[:space:]]*=[[:space:]]*Required DatabaseOptional/s/^/#/' /etc/pacman.conf
sudo sed -i '/^#SigLevel[[:space:]]*=[[:space:]]*Required DatabaseOptional/a\
SigLevel = TrustAll\
' /etc/pacman.conf

# Initialize pacman keys
echo "Initializing pacman keys..."
sudo pacman-key --init

# Populate pacman keys
echo "Populating pacman keys..."
sudo pacman-key --populate archlinux



# Install samba
echo "Installing samba..."
sudo pacman -Sy --noconfirm samba

# Write new smb.conf file
echo "Writing new smb.conf file..."
sudo tee /etc/samba/smb.conf > /dev/null <<EOF
[global]
netbios name = steamdeck

[steamapps]
comment = Steam apps directory
path = /home/deck/.local/share/Steam/steamapps/
browseable = yes
read only = no
create mask = 0777
directory mask = 0777
force user = deck
force group = deck

[home]
comment = Home folder
path = /home/
browseable = yes
read only = no
create mask = 0777
directory mask = 0777
force user = deck
force group = deck

[downloads]
comment = Downloads directory
path = /home/deck/Downloads/
browseable = yes
read only = no
create mask = 0777
directory mask = 0777
force user = deck
force group = deck

[mmcblk0p1]
comment = Steam apps directory on SD card
path = /run/media/mmcblk0p1/
browseable = yes
read only = no
create mask = 0777
directory mask = 0777
force user = deck
force group = deck
EOF


echo "Adding 'deck' user to samba user database..."
if [ "$1" = "gui" ]; then
    password=$(zenity --password --title "Set Samba Password" --width=400)
    (echo "$password"; echo "$password") | sudo smbpasswd -s -a deck
else
    sudo smbpasswd -a deck
fi

# Enable and start smb service
echo "Enabling and starting smb service..."
sudo systemctl enable smb.service
sudo systemctl start smb.service

firewall-cmd --permanent --zone=public --add-service=samba
firewall-cmd --reload


# Restart smb service
echo "Restarting smb service..."
sudo systemctl restart smb.service

# re-enable the readonly filesystem
sudo steamos-readonly enable
echo "Filesystem now read-only"


if [ "$1" = "gui" ]; then
  zenity --info --width=400 --height=100 --text="Samba server set up successfully! You can access the 'steamapps', 'downloads' and 'mmcblk0p1' folders on your Steam Deck from any device on your local network."
  else 
    echo -e "${BOLDGREEN}Samba server set up successfully!${ENDCOLOR} You can access the 'steamapps', 'downloads' and 'mmcblk0p1' folders on your Steam Deck from any device on your local network."
    read -p "Press Enter to continue..." 
fi

      

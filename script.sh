#!/bin/bash

if [ -z "$DESKTOP_SESSION" ]; then
    # Script is being run from the console
    echo "WARNING: This script will install Samba server on your system."
    read -p "Are you sure you want to continue? [Y/N] " choice

    case "$choice" in
      y|Y ) echo "Continuing with Samba server installation..." ;;
      n|N ) echo "Aborting script." && exit 1 ;;
      * ) echo "Invalid choice, aborting script." && exit 1 ;;
    esac
else
    # Script is being run from an icon
    if zenity --question --text="This script will install Samba server on your system. Are you sure you want to continue?"; then
        echo "Continuing with Samba server installation..."
    else
        echo "Aborting script." && exit 1
    fi
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

# Populate pacman keys
echo "Populating pacman keys..."
sudo pacman-key --populate archlinux

# Initialize pacman keys
echo "Initializing pacman keys..."
sudo pacman-key --init

# Install samba
echo "Installing samba..."
sudo pacman -Sy --noconfirm samba

# Add "deck" user to samba user database
echo "Adding 'deck' user to samba user database..."
echo "Please enter the same password as on Steam Deck:"
sudo smbpasswd -a deck

# Enable and start smb service
echo "Enabling and starting smb service..."
sudo systemctl enable smb.service
sudo systemctl start smb.service



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

# Restart smb service
echo "Restarting smb service..."
sudo systemctl restart smb.service

# Print log
echo "Samba server set up successfully! You can access the 'steamapps' and 'downloads' folders on your Steam Deck from any device on your local network."


# re-enable the readonly filesystem
sudo steamos-readonly enable
echo "Filesystem now read-only"

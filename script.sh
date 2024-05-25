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
sudo sed -i '/^#SigLevel[[:space:]]*=[[:space:]]*Required DatabaseOptional/a\SigLevel = TrustAll' /etc/pacman.conf

# Initialize pacman keys
echo "Initializing pacman keys..."
sudo pacman-key --init

# Populate pacman keys
echo "Populating pacman keys..."
sudo pacman-key --populate archlinux

# Install Samba
echo "Installing samba..."
sudo pacman -Sy --noconfirm samba

# Initialize Samba configuration after installed
echo "Initializing new smb.conf file..."
sudo tee /etc/samba/smb.conf > /dev/null <<EOF
[global]
netbios name = steamdeck
EOF

# Function to add a new share to smb.conf
add_smb_share() {
    echo "Adding share for $1..."
    sudo tee -a /etc/samba/smb.conf > /dev/null <<EOF
[$2]
comment = $2 directory
path = $1
browseable = yes
read only = no
create mask = 0777
directory mask = 0777
force user = deck
force group = deck
EOF
}

# Handle multiple directory inputs
while true; do
    echo "Enter the path of the directory you want to share, or press ENTER to share the entire /home directory:"
    read -p "Path: " custom_path
    # default to /home/
    if [[ -z "$custom_path" ]]; then
        custom_path="/home/"
        share_name="home"
        add_smb_share "$custom_path" "$share_name"
        echo "No path entered. Defaulting to share the entire /home directory."
    elif [[ -d "$custom_path" ]]; then
        share_name=$(basename "$custom_path")
        # create new share
        add_smb_share "$custom_path" "$share_name"
        echo "Directory added: $custom_path"
    else
        echo "The path '$custom_path' does not exist or is not a directory. Please check the path and try again."
    fi

    read -p "Would you like to add another directory? (Y/n): " add_more
    if [[ $add_more =~ ^[Nn] ]]; then
        break
    fi
done

# Confirm sharing setup
while true; do
    read -p "Are you sure you want to proceed with sharing directories? (y/n): " confirmation
    case "$confirmation" in
        [Yy] ) 
            echo "Proceeding with sharing setup..."
            break ;;
        [Nn] ) 
            echo "Setup aborted by user."
            exit 1 ;;
        * ) 
            echo "Invalid input. Please enter 'Y' for Yes or 'N' for No." ;;
    esac
done



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

# Final confirmation
if [ "$1" = "gui" ]; then
    zenity --info --width=400 --height=100 --text="Samba server set up successfully! You can now access the shared directories on your Steam Deck from any device on your local network."
else
    echo -e "${BOLDGREEN}Samba server set up successfully!${ENDCOLOR} You can now access the shared directories on your Steam Deck from any device on your local network."
    read -p "Press Enter to continue..."
fi

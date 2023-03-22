
# SteamDeck Samba Server

This is a simple script that sets up a Samba server on your SteamDeck, allowing you to easily transfer files to and from your device.

## Installation

To run the script, simply insert the following command in your SteamDeck terminal:

`sh -c "$(curl -fsSL https://raw.githubusercontent.com/malordin/steamdeck-samba-server/main/script.sh)"` 

This will download and run the `script.sh` file from the GitHub repository, which will automatically install and configure the Samba server on your SteamDeck.

## Usage

Once the Samba server is installed, you can connect to it from any device on the same network. Simply open a file explorer window on your computer, and type the following in the address bar:

`\\steamdeck` 

You should then be prompted to enter your SteamDeck username and password. Once you do so, you'll be able to access the files on your SteamDeck just like any other shared folder.

## License

This script is licensed under the [MIT License](https://github.com/malordin/steamdeck-samba-server/blob/main/LICENSE). Feel free to use, modify, and distribute it as you see fit.

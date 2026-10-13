#!/bin/bash

LOGGED_USER=stat -f%Su /dev/console

#sudo su $LOGGED_USER -c ‘defaults delete com.apple.dock persistent-apps’

dock_item() {

printf ‘<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>%s</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>’, “$1”

}

# Declare all apps here

notes=$(dock_item /System/Applications/Notes.app)

chrome=$(dock_item /Applications/Google\ Chrome.app)

mail=$(dock_item /Applications/Mail.app)

#sudo su $LOGGED_USER -c “defaults write com.apple.dock persistent-apps -array ‘$notes’ ‘$chrome’ ‘$mail'”

#killall Dock



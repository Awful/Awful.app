#!/bin/bash

cd "$( dirname "${BASH_SOURCE[0]}" )"/..
[ -e app-group ] && APP_GROUP=`cat app-group | tr -d '[[:space:]]'`

cp Xcode/AppGroup.entitlements App/Awful.entitlements

if [ "$APP_GROUP" ]; then
    function buddy() {
        /usr/libexec/PlistBuddy -x -c "$1" App/Awful.entitlements
    }
    buddy "Add :com.apple.security.application-groups array"
    buddy "Add :com.apple.security.application-groups:0 string $APP_GROUP"
fi

cp App/Awful.entitlements Smilies/Keyboard/Keyboard.entitlements

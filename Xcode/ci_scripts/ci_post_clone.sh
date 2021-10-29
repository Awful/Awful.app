#!/bin/sh
set -e

# If an app group is specified via custom environment variable, set up the entitlements.
[ -n "$AWFUL_APP_GROUP_IDENTIFIER" ] &&
perl -pe "s/PASTE YOUR APP GROUP IDENTIFIER HERE/$AWFUL_APP_GROUP_IDENTIFIER/g" ../../Local.sample.entitlements > ../../Local.entitlements &&
echo "CODE_SIGN_ENTITLEMENTS = ../Local.entitlements" > ../../Local.xcconfig

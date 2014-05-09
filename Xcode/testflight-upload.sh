#!/usr/bin/env bash

PATH="$PATH":/usr/local/bin

if [ -z "$SRCROOT" ] || [ -z "$ARCHIVE_PRODUCTS_PATH" ]; then
  echo "Please run from an Xcode archive post-action."; exit 1
fi

function error {
  echo "error: $1"
  osascript -e "tell application \"Xcode\"" \
    -e "display dialog \"$1\" buttons {\"OK\"} with icon stop with title \"TestFlight Upload\"" \
    -e "end tell" > /dev/null 2>&1
}

# Grab API keys we'll need later.
API_KEYS="$SRCROOT/../api_keys"
while IFS=" " read name key; do
  declare $name="$key"
done < "$API_KEYS"
if [ -z "$TESTFLIGHT_API_TOKEN" ]; then
  error "Missing TestFlight API token."; exit 1
fi
if [ -z "$TESTFLIGHT_TEAM_TOKEN" ]; then
  error "Missing TestFlight team token."; exit 1
fi

# Find somewhere to stash release notes, .ipa archive, and a log.
WORKING_DIR=$(mktemp -t TestFlight-Upload -d)
LOG="$WORKING_DIR/testflight-upload.log"
function log {
  echo "$1" >> "$LOG"
}
function open_log {
  open -a Console "$LOG"
}

set >> "$LOG"

log "Asking for release notes"
NEAREST_TAG=$(cd "$SRCROOT" ; git describe --abbrev=0)
NOTES_FILE="$WORKING_DIR/notes.txt"
cat <<END > "$NOTES_FILE"


# Please provide some information about this release.
# Lines starting with # (like this one) are not included.
# Here are the relevant git commits sorted by author:
#
END
(cd "$SRCROOT" ; git shortlog $NEAREST_TAG.. | sed 's/^/# /' >> "$NOTES_FILE")
mate -w --name "$SCHEME_NAME Release Notes" "$NOTES_FILE" >> "$LOG" 2>&1
if [ $? -ne 0 ]; then
  error "Missing release notes. Upload cancelled. Please see log for details."
  open_log
  exit 1
fi
# Not sure how to combine these two sed passes.
sed -i '' /^#/d "$NOTES_FILE"
sed -i '' -e :a -e '/^\n*$/{$d;N;};/\n$/ba' "$NOTES_FILE"
log "Release notes saved to $NOTES_FILE"

log "Packaging app into an .ipa"
APP="$ARCHIVE_PRODUCTS_PATH/$INSTALL_PATH/$WRAPPER_NAME"
IPA="$WORKING_DIR/$SCHEME_NAME.ipa"
xcrun -sdk iphoneos PackageApplication "$APP" -o "$IPA" >> "$LOG" 2>&1
if [ $? -ne 0 ]; then
  error "App packaging failed. Please see log for details."
  open_log
  exit 1
fi
log "App packaged as $IPA"

osascript -e "tell application \"Xcode\"" \
  -e "display dialog \"Upload is about to begin. Once it's done, you'll be asked to tag the release.\" with icon 1 with title \"TestFlight Upload\"" \
  -e "end tell" > /dev/null 2>&1
if [ $? -ne 0 ]; then
  log "User cancelled"
  exit 1
fi

log "Uploading to TestFlight"
RESPONSE_FILE="$WORKING_DIR/response.txt"
log "Writing response to $RESPONSE_FILE"
# By default, nobody has permission to install the build and nobody gets notified. The otherwise pointless distribution_lists=Everyone gives the "Everyone" list access and notifies them. Be sure to add testers to the "Everyone" list or they won't get any builds uploaded by this script.
STATUS_CODE=$(curl "http://testflightapp.com/api/builds.json" \
  -o "$RESPONSE_FILE" \
  -s \
  --write-out "%{http_code}" \
  -F "file=@$IPA" \
  -F api_token="$TESTFLIGHT_API_TOKEN" \
  -F team_token="$TESTFLIGHT_TEAM_TOKEN" \
  -F distribution_lists=Everyone \
  -F notify=True \
  -F "notes=@$NOTES_FILE" \
  2>> "$LOG" )
if [ $? -ne 0 ] || [ "$STATUS_CODE" -ge 300 ]; then
  error "Upload failed. Please see log for details."
  open_log
  exit 1
fi
log "Upload complete"

log "Tagging release"
VERSION=$( osascript -e "tell application \"Xcode\"" \
  -e "set version_dialog to display dialog \"Upload complete!\n\nWhat version is this release? Last version was $NEAREST_TAG\" default answer \"\" buttons {\"Tag\"} default button \"Tag\" with icon 1 with title \"TestFlight Upload\"" \
  -e "set chosen_version to text returned of version_dialog" \
  -e "end tell" \
  -e "return chosen_version" \
  2>> "$LOG"
)
if [ -z "$VERSION" ]; then
  error "This release is not tagged. Consider tagging it manually."
  open_log
  exit 1
fi
( cd "$SRCROOT"; git tag -a -f -m <("$NOTES_FILE") "$VERSION" >> "$LOG" 2>&1 )
if [ $? -ne 0 ]; then
  error "Failed to tag release. Please see log for details."
  open_log
  exit 1
fi
log "Release tagged as $VERSION"

# Clean up.
rm -rf "$WORKING_DIR"

#!/usr/bin/env bash
set -e
SCRIPTDIR=$(dirname "${0}")

BUILD_SETTINGS="TEST_AFTER_BUILD=YES"
XCODEFLAGS="-configuration Release -sdk iphonesimulator ${BUILD_SETTINGS}"

xcodebuild -alltargets clean $XCODEFLAGS
xcodebuild -target ParsingTests $XCODEFLAGS 2>&1 | awk -f "${SCRIPTDIR}/xcodebuild.awk"

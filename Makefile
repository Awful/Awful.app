.PHONY: archive beta copyright test
SHELL=/bin/bash

archive:
	xcodebuild -scheme Awful archive

beta:
	Xcode/version-bump.rb beta

copyright:
	Xcode/fix-copyright.rb

minor:
	Xcode/version-bump.rb minor

stickerscale:
	Xcode/scale-stickers

test:
	set -o pipefail && xcodebuild -scheme Awful -configuration Release -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone SE,OS=10.0' test | xcpretty -c

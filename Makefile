.PHONY: archive beta copyright

archive:
	xcodebuild -scheme Awful archive

beta:
	Xcode/version-bump.rb beta

copyright:
	Xcode/fix-copyright.rb

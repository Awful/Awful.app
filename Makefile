.PHONY: beta copyright

beta:
	Xcode/version-bump.rb beta

copyright:
	Xcode/fix-copyright.rb

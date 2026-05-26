#!/bin/sh
# Trust SPM macro and plugin fingerprints so Xcode Cloud can build without
# the manual "Trust & Enable" prompt that interactive Xcode shows.
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES

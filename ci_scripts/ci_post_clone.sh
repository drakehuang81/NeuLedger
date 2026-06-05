#!/bin/sh
# Trust SPM macro and plugin fingerprints so Xcode Cloud can build without
# the manual "Trust & Enable" prompt that interactive Xcode shows.
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES

# Materialize the Firebase config: the plist is git-ignored (public repo)
# and injected via the GOOGLE_SERVICE_INFO_PLIST_B64 secret environment
# variable configured on each Xcode Cloud workflow. Workflows without the
# variable build fine — CrashReportingBootstrap skips configure() when the
# plist is absent from the bundle.
if [ -n "$GOOGLE_SERVICE_INFO_PLIST_B64" ]; then
  echo "$GOOGLE_SERVICE_INFO_PLIST_B64" | base64 -d \
    > "$CI_PRIMARY_REPOSITORY_PATH/NeuLedger/Resources/GoogleService-Info.plist"
fi

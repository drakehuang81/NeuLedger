#!/bin/sh
# Upload dSYMs to Firebase Crashlytics after archive builds.
#
# Runs in every Xcode Cloud workflow, but only does work when an archive
# exists: PR (Build + Test) workflows have no CI_ARCHIVE_PATH and skip
# silently; TestFlight / Release workflows upload the archive's dSYMs.
set -e

if [ -n "$CI_ARCHIVE_PATH" ]; then
  UPLOAD_SYMBOLS="$CI_DERIVED_DATA_PATH/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols"
  "$UPLOAD_SYMBOLS" \
    -gsp "$CI_PRIMARY_REPOSITORY_PATH/NeuLedger/Resources/GoogleService-Info.plist" \
    -p ios \
    "$CI_ARCHIVE_PATH/dSYMs"
fi

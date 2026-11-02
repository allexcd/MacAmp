#!/bin/zsh
set -eu
cd "${0:A:h}/.."
xcodebuild -project MacAmp.xcodeproj -scheme MacAmp -configuration Release -derivedDataPath DerivedData -clonedSourcePackagesDirPath .build build
python3 scripts/collect-licenses.py
python3 scripts/package-app.py

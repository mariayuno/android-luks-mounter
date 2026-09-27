#!/bin/bash
# 🛠️ Android LUKS Mounter - Module Builder
# 👤 Author: Rex Ackermann

# --- Configuration ---
VERSION=$(grep "^version=" module.prop | cut -d= -f2)
OUTPUT_ZIP="android-luks-mounter-${VERSION}.zip"

# --- 🚀 Build Process ---
echo "[*] Starting build for Android LUKS Mounter ${VERSION}..."

# 1. Cleanup
rm -f android-luks-mounter-*.zip mounter-module.zip

# 2. Packaging
echo "[+] Creating flashable ZIP: $OUTPUT_ZIP"
# We exclude the build script itself and repo metadata/tracking files from the ZIP.
zip -r9 "$OUTPUT_ZIP" module.prop customize.sh post-fs-data.sh service.sh action.sh system/ LICENSE README.md -x ".*"

# 3. Success
if [ -f "$OUTPUT_ZIP" ]; then
    # Also write a stable-named copy so /releases/latest/download/android-luks-mounter.zip
    # always resolves without knowing the version in advance.
    cp "$OUTPUT_ZIP" android-luks-mounter.zip
    echo " "
    echo "################################################"
    echo "#                                              #"
    echo "#   ✅ BUILD SUCCESSFUL!                       #"
    echo "#   📁 Output: $OUTPUT_ZIP                #"
    echo "#   📁 Stable: android-luks-mounter.zip    #"
    echo "#                                              #"
    echo "################################################"
else
    echo "❌ Build failed!"
    exit 1
fi

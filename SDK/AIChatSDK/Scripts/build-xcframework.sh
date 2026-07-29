#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
repository_root=${script_directory:h:h:h}
default_output_directory="${repository_root}/SDK/AIChatSDK/Artifacts"
output_directory=${1:-$default_output_directory}

temporary_root=$(mktemp -d "${TMPDIR:-/private/tmp}/AIChatSDK.XXXXXX")
archive_path="${temporary_root}/AIChatSDK.xcarchive"
derived_data_path="${temporary_root}/DerivedData"
temporary_xcframework="${temporary_root}/AIChatSDK.xcframework"
temporary_zip="${temporary_root}/AIChatSDK.xcframework.zip"

archive_products="${archive_path}/Products/Library/Frameworks"
framework_path="${archive_products}/AIChatSDK.framework"
framework_version_path="${framework_path}/Versions/A"
build_products="${derived_data_path}/Build/Intermediates.noindex/ArchiveIntermediates/AIChatSDK/BuildProductsPath/Release"
module_source="${build_products}/AIChatSDK.swiftmodule"
module_destination="${framework_version_path}/Modules/AIChatSDK.swiftmodule"
resource_bundle_source="${build_products}/AIChatSDK_AIChatSDK.bundle"
resource_bundle_destination="${framework_version_path}/Resources/AIChatSDK_AIChatSDK.bundle"
dsym_path="${archive_path}/dSYMs/AIChatSDK.framework.dSYM"

cleanup() {
    /bin/rm -rf "$temporary_root"
}
trap cleanup EXIT

xcodebuild archive \
    -workspace "${repository_root}/AIChat.xcworkspace" \
    -scheme AIChatSDK \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$archive_path" \
    -derivedDataPath "$derived_data_path" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    CODE_SIGNING_ALLOWED=NO

test -d "$framework_path"
test -d "$module_source"
test -d "$resource_bundle_source"
test -d "$dsym_path"

mkdir -p "$module_destination"
cp -R "${module_source}/." "${module_destination}/"
mkdir -p "${framework_version_path}/Resources"
cp -RL "$resource_bundle_source" "$resource_bundle_destination"

xcodebuild -create-xcframework \
    -framework "$framework_path" \
    -debug-symbols "$dsym_path" \
    -output "$temporary_xcframework"

test -f "${temporary_xcframework}/Info.plist"
arm64_interface=$(find "$temporary_xcframework" \
    -path "*AIChatSDK.swiftmodule/arm64-apple-macos.swiftinterface" \
    -print -quit)
x86_64_interface=$(find "$temporary_xcframework" \
    -path "*AIChatSDK.swiftmodule/x86_64-apple-macos.swiftinterface" \
    -print -quit)
resource_bundle=$(find "$temporary_xcframework" \
    -name "AIChatSDK_AIChatSDK.bundle" \
    -type d -print -quit)
test -n "$arm64_interface"
test -n "$x86_64_interface"
test -n "$resource_bundle"

ditto -c -k --sequesterRsrc --keepParent \
    "$temporary_xcframework" \
    "$temporary_zip"

checksum=$(swift package compute-checksum "$temporary_zip")
mkdir -p "$output_directory"

timestamp=$(date "+%Y%m%d-%H%M%S")
for existing_name in AIChatSDK.xcframework AIChatSDK.xcframework.zip; do
    existing_path="${output_directory}/${existing_name}"
    if [[ -e "$existing_path" ]]; then
        mv "$existing_path" "${existing_path}.backup-${timestamp}"
    fi
done

mv "$temporary_xcframework" "${output_directory}/AIChatSDK.xcframework"
mv "$temporary_zip" "${output_directory}/AIChatSDK.xcframework.zip"

print "XCFramework: ${output_directory}/AIChatSDK.xcframework"
print "Archive:     ${output_directory}/AIChatSDK.xcframework.zip"
print "Checksum:    ${checksum}"

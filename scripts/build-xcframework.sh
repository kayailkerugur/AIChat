#!/bin/zsh
set -euo pipefail

project_path="AIChat.xcodeproj"
scheme_name="AIChatSDK"
configuration_name="Release"
output_root="${1:-Build/Distribution}"
archive_path="$output_root/AIChatSDK-macOS.xcarchive"
xcframework_path="$output_root/AIChatSDK.xcframework"
zip_path="$output_root/AIChatSDK.xcframework.zip"

mkdir -p "$output_root"

backup_suffix="$(date +%Y%m%d-%H%M%S)"
if [[ -d "$archive_path" ]]; then
  mv "$archive_path" "$archive_path.$backup_suffix"
fi

xcodebuild archive \
  -project "$project_path" \
  -scheme "$scheme_name" \
  -configuration "$configuration_name" \
  -destination "generic/platform=macOS" \
  -archivePath "$archive_path" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  CODE_SIGNING_ALLOWED=NO

if [[ -d "$xcframework_path" ]]; then
  mv "$xcframework_path" "$xcframework_path.$backup_suffix"
fi

if [[ -f "$zip_path" ]]; then
  mv "$zip_path" "$zip_path.$backup_suffix"
fi

xcodebuild -create-xcframework \
  -framework "$archive_path/Products/Library/Frameworks/AIChatSDK.framework" \
  -output "$xcframework_path"

ditto -c -k --sequesterRsrc --keepParent \
  "$xcframework_path" "$zip_path"

swift package compute-checksum "$zip_path"

#!/bin/zsh
set -euo pipefail

xcframework_root="${1:-Build/Distribution/AIChatSDK.xcframework}"
framework_parent="$xcframework_root/macos-arm64_x86_64"
framework_binary="$framework_parent/AIChatSDK.framework/Versions/A/AIChatSDK"

install_names="$(otool -D "$framework_binary")"
if [[ "$install_names" != *"@rpath/AIChatSDK.framework/Versions/A/AIChatSDK"* ]]; then
  print -u2 "AIChatSDK has an invalid dynamic-library install name."
  exit 1
fi

xcrun swiftc \
  -typecheck \
  -target arm64-apple-macos15.0 \
  -F "$framework_parent" \
  IntegrationSmoke/EmptyHost.swift

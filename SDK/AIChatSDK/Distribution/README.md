# AIChatSDK binary distribution

The local Swift Package remains the development source of truth. Its library
product is dynamic so Xcode can archive it as `AIChatSDK.framework`.

## Build

From the repository root:

```sh
SDK/AIChatSDK/Scripts/build-xcframework.sh
```

The command creates these ignored artifacts:

- `SDK/AIChatSDK/Artifacts/AIChatSDK.xcframework`
- `SDK/AIChatSDK/Artifacts/AIChatSDK.xcframework.zip`

It archives with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`, includes both macOS
architectures (`arm64` and `x86_64`), copies the Swift module interfaces,
embeds `AIChatSDK_AIChatSDK.bundle`, includes the dSYM and prints the Swift
Package checksum.

Existing artifacts are moved to timestamped backups instead of being deleted.
Pass a directory as the first argument to use a different output location.

## Publish

1. Sign the framework with the distribution identity used by the publisher.
2. Upload `AIChatSDK.xcframework.zip` to an immutable HTTPS release URL.
3. Copy `Package.binary.template.swift` into the binary distribution
   repository as `Package.swift`.
4. Replace the example URL and checksum with the values for that release.
5. Tag the package using semantic versioning.

The generated binary is currently macOS-only and retains the app target's
minimum deployment version. Local development should continue to depend on
the source package in `SDK/AIChatSDK`.

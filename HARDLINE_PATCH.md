# Hardline carrier-metadata patch

This fork exists to keep Meta App Events attribution enabled in Hardline without
allowing metadata generation to construct `CTTelephonyNetworkInfo`.

## Revision and behavior

- Upstream source: `facebook/facebook-ios-sdk` tag `v18.1.1`
- Upstream commit: `80d0ee82f6370d1bace1431a80cb80575f98ee90`
- Patch owner: Hardline mobile engineering
- Patched components: `FBSDKAppEventsDeviceInfo._getCarrier` and its now-unused
  CoreTelephony dynamic-loader accessor

Upstream uses `NoCarrier` for Simulator metadata and whenever CoreTelephony does
not return a carrier name. This patch always uses that supported unavailable
value and removes the CoreTelephony imports and dynamic class lookup. The
`extinfo` array shape, install and activation events, ATE publication, campaign
attribution, SDK initialization, and all non-carrier metadata remain unchanged.

Tests cover the initial `encodedDeviceInfo` collection and a forced expired
group-1 refresh. Both must replace carrier data with `NoCarrier`. The release
artifact must also pass the binary reference check documented below.

## Reproducible release

Requirements:

- Xcode 26.6 (build 17F113)
- XcodeGen 2.29.0
- macOS with iOS 12+ device and Simulator SDKs

From a clean checkout of the release commit:

```sh
./scripts/build_hardline_corekit_xcframework.sh /absolute/path/to/xcodegen
swift package compute-checksum build/hardline/FBSDKCoreKit-Dynamic_XCFramework.zip
```

The script regenerates the upstream Xcode projects, runs the focused CoreKit
tests, archives device and Simulator slices with distribution interfaces, makes
the XCFramework, verifies that its binaries contain no
`CTTelephonyNetworkInfo` reference, normalizes archive timestamps, and writes a
deterministic zip.

Create a GitHub release named `v18.1.1-hardline.1`, attach the zip, and update
the `FBSDKCoreKit` binary target URL and checksum in `Package.swift` before
tagging the exact release commit. Hardline pins that tag and resolved revision.

## Upstream and removal plan

Track removal in Hardline issue HAR-956. Report the blocking carrier lookup to
Meta upstream with the physical-device Sentry stack and this minimal patch.
For each Meta SDK update, compare `FBSDKAppEventsDeviceInfo` and its tests.
Remove the fork only after an upstream release no longer constructs
`CTTelephonyNetworkInfo` from initial or refreshed App Events/ATE metadata and
Hardline has repeated the package, device, event-receipt, and attribution checks.

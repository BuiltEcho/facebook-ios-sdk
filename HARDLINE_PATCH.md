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
HARDLINE_SDK_SIGNING_IDENTITY="<Apple signing identity>" \
  ./scripts/build_hardline_corekit_xcframework.sh /absolute/path/to/xcodegen
swift package compute-checksum build/hardline/FBSDKCoreKit-Dynamic_XCFramework.zip
```

The script regenerates the upstream Xcode projects, runs the focused CoreKit
tests, archives device and Simulator slices with distribution interfaces, makes
the XCFramework, verifies that its binaries contain no
`CTTelephonyNetworkInfo` reference, normalizes archive timestamps, and writes a
zip. Signing includes a secure timestamp, so signed archive checksums change on
each signing operation. Record and pin the checksum of the published artifact.

Create a GitHub release named `v18.1.1-hardline.2`, attach the zip, and update
the `FBSDKCoreKit` binary target URL and checksum in `Package.swift` before
tagging the exact release commit. Hardline pins that tag and resolved revision.

## Upstream and removal plan

Track removal in Hardline issue HAR-956. Report the blocking carrier lookup to
Meta upstream with the physical-device Sentry stack and this minimal patch.
For each Meta SDK update, compare `FBSDKAppEventsDeviceInfo` and its tests.
Remove the fork only after an upstream release no longer constructs
`CTTelephonyNetworkInfo` from initial or refreshed App Events/ATE metadata and
Hardline has repeated the package, device, event-receipt, and attribution checks.

## Signature repair: v18.1.1-hardline.2

Apple rejected Hardline 4.2.6 (1) with ITMS-91065 because the prior
XCFramework had no SDK signature. An app's embedded framework signature does
not replace the SDK author's XCFramework signature.

This release adds only a timestamped Apple Development signature from Hardline
team `7U6FP8M3C7` to the original v18.1.1-hardline.1 XCFramework. All 465
original payload files were compared byte for byte and remain identical; no
SDK source or executable was rebuilt. The root `_CodeSignature` is new.
The existing missing localization bundle remains unchanged.

- Original zip SHA-256: `f0d0a443f956d2ddc1a518163be7a14809996662de5721df5eaf5d796f5d66ae`
- Signed zip SHA-256: `14c0b396ae8f415fb3a2184a7ffc2200a44ea4c0f264cae08b13811cfd32662b`
- Signer: Apple Development: Jacob Pettingill (JKN526BS6B)
- Signing certificate SHA-1: `B688EEEDA2828754ACC5A0F91121EBB312572148`
- Verification: `codesign --verify --strict` with an Apple anchor and the
  Hardline team requirement. Apple documents both Apple Development and Apple
  Distribution identities as valid SDK signing identities.

Future artifact builds require `HARDLINE_SDK_SIGNING_IDENTITY` and fail if
signing or team verification fails. Preserve each published release asset;
never replace a zip behind an existing package checksum.

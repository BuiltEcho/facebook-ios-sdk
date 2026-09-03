/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

@testable import FBSDKCoreKit

import TestTools
import XCTest

final class AppEventsDeviceInfoTests: XCTestCase {

  // swiftlint:disable implicitly_unwrapped_optional
  var deviceInfo: _AppEventsDeviceInfo!
  var settings: TestSettings!
  // swiftlint:enable implicitly_unwrapped_optional

  override func setUp() {
    super.setUp()

    settings = TestSettings()
    deviceInfo = _AppEventsDeviceInfo()
    deviceInfo.configure(settings: settings)
  }

  override func tearDown() {
    settings = nil
    deviceInfo = nil

    super.tearDown()
  }

  func testDefaultDependencies() {
    deviceInfo = _AppEventsDeviceInfo()
    XCTAssertNil(
      deviceInfo.settings,
      "Should not have settings by default"
    )
  }

  func testConfiguringWithDependencies() {
    XCTAssertTrue(
      deviceInfo.settings === settings,
      "Should use the provided settings"
    )
  }

  func testCarrierMetadataAlwaysUsesSupportedUnavailablePlaceholder() {
    XCTAssertEqual(_AppEventsDeviceInfo.carrier(), "NoCarrier")
  }

  func testInitialAndExpiredMetadataCollectionNeverRestoresCarrierData() throws {
    settings.shouldUseCachedValuesForExpensiveMetadata = false

    let initialMetadata = try decodedMetadata(from: deviceInfo)
    XCTAssertEqual(initialMetadata[8] as? String, "NoCarrier")

    deviceInfo.carrierName = "Carrier that must not survive a refresh"
    deviceInfo.lastGroup1CheckTime = 0

    let refreshedMetadata = try decodedMetadata(from: deviceInfo)
    XCTAssertEqual(refreshedMetadata[8] as? String, "NoCarrier")
  }

  private func decodedMetadata(from deviceInfo: _AppEventsDeviceInfo) throws -> [Any] {
    let encoded = try XCTUnwrap(deviceInfo.encodedDeviceInfo)
    let data = try XCTUnwrap(encoded.data(using: .utf8))
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [Any])
  }
}

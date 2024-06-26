//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import AWSCognitoAuthPlugin

class ASFDeviceInfoTests: XCTestCase {

    func testdeviceInfo() async {
        let asf = await ASFDeviceInfo(id: "mockID")
        let deviceFingerPrint = await asf.deviceInfo()
        XCTAssertNotNil(deviceFingerPrint)
    }
}

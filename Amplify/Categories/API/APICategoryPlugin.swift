//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

/// API Category Plugin
public protocol APICategoryPlugin: Plugin, APICategoryBehavior { }

/// API Category Plugin
public extension APICategoryPlugin {

    /// The category type for API
    var categoryType: CategoryType {
        return .api
    }
}

import AWSAPIPlugin


public extension AWSAPIPlugin {
    public func printPluginConfig() {
        print(pluginConfig)
    }
    
    public func printPluginConfigEndpoints() {
        print(pluginConfig.endpoints)
    }
}

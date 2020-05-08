//
// Copyright 2018-2020 Amazon.com,
// Inc. or its affiliates. All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify

public protocol AuthCognitoIdentityProvider {
    func getIdentityId() -> Result<String, AmplifyAuthError>

    func getUserSub() -> Result<String, AmplifyAuthError>
}

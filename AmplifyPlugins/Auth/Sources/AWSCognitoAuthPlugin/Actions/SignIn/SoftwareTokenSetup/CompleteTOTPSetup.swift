//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify
import AWSCognitoIdentityProvider

struct CompleteTOTPSetup: Action {

    var identifier: String = "CompleteTOTPSetup"
    let userSession: String
    let signInEventData: SignInEventData

    func execute(withDispatcher dispatcher: EventDispatcher, environment: Environment) async {
        logVerbose("\(#fileID) Starting execution", environment: environment)

        do {
            var deviceMetadata = DeviceMetadata.noData
            guard let username = signInEventData.username else {
                throw SignInError.unknown(message: "Unable to unwrap username during TOTP verification")
            }
            let authEnv = try environment.authEnvironment()
            let userpoolEnv = try environment.userPoolEnvironment()
            let challengeType: CognitoIdentityProviderClientTypes.ChallengeNameType = .mfaSetup

            deviceMetadata = await DeviceMetadataHelper.getDeviceMetadata(
                for: username,
                with: environment)

            var challengeResponses = [
                "USERNAME": username
            ]
            let userPoolClientId = userpoolEnv.userPoolConfiguration.clientId

            if let clientSecret = userpoolEnv.userPoolConfiguration.clientSecret {
                let clientSecretHash = ClientSecretHelper.clientSecretHash(
                    username: username,
                    userPoolClientId: userPoolClientId,
                    clientSecret: clientSecret
                )
                challengeResponses["SECRET_HASH"] = clientSecretHash
            }

            if case .metadata(let data) = deviceMetadata {
                challengeResponses["DEVICE_KEY"] = data.deviceKey
            }

            let asfDeviceId = try await CognitoUserPoolASF.asfDeviceID(
                for: username,
                credentialStoreClient: authEnv.credentialsClient)

            var userContextData: CognitoIdentityProviderClientTypes.UserContextDataType?
            if let encodedData = await CognitoUserPoolASF.encodedContext(
                username: username,
                asfDeviceId: asfDeviceId,
                asfClient: userpoolEnv.cognitoUserPoolASFFactory(),
                userPoolConfiguration: userpoolEnv.userPoolConfiguration) {
                userContextData = .init(encodedData: encodedData)
            }

            let analyticsMetadata = userpoolEnv
                .cognitoUserPoolAnalyticsHandlerFactory()
                .analyticsMetadata()

            let input = RespondToAuthChallengeInput(
                analyticsMetadata: analyticsMetadata,
                challengeName: challengeType,
                challengeResponses: challengeResponses,
                clientId: userPoolClientId,
                session: userSession,
                userContextData: userContextData)

            let responseEvent = try await UserPoolSignInHelper.sendRespondToAuth(
                request: input,
                for: username,
                signInMethod: signInEventData.signInMethod,
                environment: userpoolEnv)
            logVerbose("\(#fileID) Sending event \(responseEvent)",
                       environment: environment)
            await dispatcher.send(responseEvent)

        } catch let error as SignInError {
            logError(error.authError.errorDescription, environment: environment)
            let errorEvent = SignInEvent(eventType: .throwAuthError(error))
            logVerbose("\(#fileID) Sending event \(errorEvent)",
                       environment: environment)
            await dispatcher.send(errorEvent)
        } catch {
            let error = SignInError.service(error: error)
            logError(error.authError.errorDescription, environment: environment)
            let errorEvent = SignInEvent(eventType: .throwAuthError(error))
            logVerbose("\(#fileID) Sending event \(errorEvent)",
                       environment: environment)
            await dispatcher.send(errorEvent)
        }
    }

}

extension CompleteTOTPSetup: CustomDebugDictionaryConvertible {
    var debugDictionary: [String: Any] {
        [
            "identifier": identifier,
            "session": userSession.masked(),
            "signInEventData": signInEventData.debugDictionary
        ]
    }
}

extension CompleteTOTPSetup: CustomDebugStringConvertible {
    var debugDescription: String {
        debugDictionary.debugDescription
    }
}

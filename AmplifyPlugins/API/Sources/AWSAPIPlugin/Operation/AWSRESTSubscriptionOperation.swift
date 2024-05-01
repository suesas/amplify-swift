//
//  AWSRESTSubscriptionOperation.swift
//  
//
//  Created by eIBarto on 01.05.24.
//

import Foundation
import Amplify

public class RESTSubscriptionOperation: AmplifyInProcessReportingOperation<
    RESTOperationRequest,
    Data,
    Data,
    APIError
> { }

class AWSRESTSubscriptionOperation: RESTSubscriptionOperation {
    
    var data = Data()

    let session: URLSessionBehavior
    var mapper: OperationTaskMapper
    let pluginConfig: AWSAPICategoryPluginConfiguration

    init(request: RESTOperationRequest,
         session: URLSessionBehavior,
         mapper: OperationTaskMapper,
         pluginConfig: AWSAPICategoryPluginConfiguration,
         inProcessListener: AWSRESTSubscriptionOperation.InProcessListener?,
         resultListener: AWSRESTSubscriptionOperation.ResultListener?) {

        self.session = session
        self.mapper = mapper
        self.pluginConfig = pluginConfig

        super.init(categoryType: .api, eventName: HubPayload.EventName.API.subscribe, request: request, inProcessListener: inProcessListener, resultListener: resultListener)
    }

    override public func cancel() {
        super.cancel()
        // displatch disconnected?
        /*Task {
            guard let appSyncRealTimeClient = self.appSyncRealTimeClient else {
                return
            }

            do {
                try await appSyncRealTimeClient.unsubscribe(id: subscriptionId)
                finish()
            } catch {
                print("[AWSGraphQLSubscriptionOperation] Failed to unsubscribe \(subscriptionId), error: \(error)")
            }

            await appSyncRealTimeClient.disconnectWhenIdel()
        }*/
        
        /*
         dispatch(result: .failure(APIError.unknown("", "", error)))
         finish()
         */
    }

    override public func main() {
        Task { await mainAsync() }
        
        /*if isCancelled {
            finish()
            return
        }

        // Validate the request
        do {
            try request.validate()
        } catch let error as APIError {
            dispatch(result: .failure(error))
            finish()
            return
        } catch {
            dispatch(result: .failure(APIError.unknown("Could not validate request", "", nil)))
            finish()
            return
        }

        // Retrieve endpoint configuration
        let endpointConfig: AWSAPICategoryPluginConfiguration.EndpointConfig
        do {
            endpointConfig = try pluginConfig.endpoints.getConfig(for: request.apiName, endpointType: .graphQL)
        } catch let error as APIError {
            dispatch(result: .failure(error))
            finish()
            return
        } catch {
            dispatch(result: .failure(APIError.unknown("Could not get endpoint configuration", "", nil)))
            finish()
            return
        }

        let authType: AWSAuthorizationType?
        if let pluginOptions = request.options.pluginOptions as? AWSAPIPluginDataStoreOptions {
            authType = pluginOptions.authType
        } else if let authorizationMode = request.authMode as? AWSAuthorizationType {
            authType = authorizationMode
        } else {
            authType = nil
        }
        Task {
            do {
                appSyncRealTimeClient = try await appSyncRealTimeClientFactory.getAppSyncRealTimeClient(
                    for: endpointConfig,
                    endpoint: endpointConfig.baseURL,
                    authService: authService,
                    authType: authType,
                    apiAuthProviderFactory: apiAuthProviderFactory
                )

                // Create subscription
                self.subscription = try await appSyncRealTimeClient?.subscribe(
                    id: subscriptionId,
                    query: encodeRequest(query: request.document, variables: request.variables)
                ).sink(receiveValue: { [weak self] event in
                    self?.onAsyncSubscriptionEvent(event: event)
                })
            } catch {
                let error = APIError.operationError("Unable to get connection for api \(endpointConfig.name)", "", error)
                dispatch(result: .failure(error))
                finish()
                return
            }

        }*/
    }
    
    private func mainAsync() async {
        if isCancelled {
            finish()
            return
        }

        let urlRequest = validateRequest(request).flatMap(buildURLRequest(from:))
        let finalRequest = await getEndpointConfig(from: request).flatMapAsync { endpointConfig in
            let interceptorConfig = pluginConfig.interceptorsForEndpoint(withConfig: endpointConfig)
            let preludeInterceptors = interceptorConfig?.preludeInterceptors ?? []
            let customerInterceptors = interceptorConfig?.interceptors ?? []
            let postludeInterceptors = interceptorConfig?.postludeInterceptors ?? []

            var finalResult = urlRequest
            // apply prelude interceptors
            for interceptor in preludeInterceptors {
                finalResult = await finalResult.flatMapAsync { request in
                    await applyInterceptor(interceptor, request: request)
                }
            }

            // apply customize headers
            finalResult = finalResult.map { urlRequest in
                var mutableRequest = urlRequest
                for (key, value) in request.headers ?? [:] {
                    mutableRequest.setValue(value, forHTTPHeaderField: key)
                }
                return mutableRequest
            }

            // apply customer interceptors
            for interceptor in customerInterceptors {
                finalResult = await finalResult.flatMapAsync { request in
                    await applyInterceptor(interceptor, request: request)
                }
            }

            // apply postlude interceptor
            for interceptor in postludeInterceptors {
                finalResult = await finalResult.flatMapAsync { request in
                    await applyInterceptor(interceptor, request: request)
                }
            }
            return finalResult
        }

        switch finalRequest {
        case .success(let finalRequest):
            if isCancelled {
                finish()
                return
            }

            // Begin network task
            Amplify.API.log.debug("Starting network task for \(request.operationType) \(id)")
            let task = session.dataTaskBehavior(with: finalRequest)
            mapper.addPair(operation: self, task: task)
            task.resume()
        case .failure(let error):
            Amplify.API.log.debug("Dispatching error \(error)")
            dispatch(result: .failure(error))
            finish()
        }
    }
    
    private func validateRequest(_ request: RESTOperationRequest) -> Result<RESTOperationRequest, APIError> {
        do {
            try request.validate()
            return .success(request)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(APIError.unknown("Could not validate request", "", nil))
        }
    }

    private func getEndpointConfig(
        from request: RESTOperationRequest
    ) -> Result<AWSAPICategoryPluginConfiguration.EndpointConfig, APIError> {
        do {
            return .success(try pluginConfig.endpoints.getConfig(for: request.apiName, endpointType: .rest))
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(APIError.unknown("Could not get endpoint configuration", "", nil))
        }
    }

    private func buildURLRequest(from request: RESTOperationRequest) -> Result<URLRequest, APIError> {
        getEndpointConfig(from: request).flatMap { endpointConfig in
            do {
                let url = try RESTOperationRequestUtils.constructURL(
                    for: endpointConfig.baseURL,
                    withPath: request.path,
                    withParams: request.queryParameters
                )
                return .success(RESTOperationRequestUtils.constructURLRequest(
                    with: url,
                    operationType: request.operationType,
                    requestPayload: request.body
                ))
            } catch let error as APIError {
                return .failure(error)
            } catch {
                return .failure(APIError.operationError("Failed to construct URL", "", error))
            }
        }
    }

    private func applyInterceptor(_ interceptor: URLRequestInterceptor, request: URLRequest) async -> Result<URLRequest, APIError> {
        do {
            return .success(try await interceptor.intercept(request))
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(
                APIError.operationError(
                    "Failed to intercept request with \(type(of: interceptor)). Error message: \(error.localizedDescription).",
                    "See underlying error for more details",
                    error
                )
            )
        }
    }
    /*
    // MARK: - Subscription callbacks

    private func onSubscriptionConnectionState(_ subscriptionConnectionState: SubscriptionConnectionState) { Todo hand network events if needed
        let subscriptionEvent = RESTSubscriptionEvent.connection(subscriptionConnectionState)
        dispatchInProcess(data: subscriptionEvent)

        if case .disconnected = subscriptionConnectionState {
            dispatch(result: .success(data))
            finish()
        }
    }
 */
}

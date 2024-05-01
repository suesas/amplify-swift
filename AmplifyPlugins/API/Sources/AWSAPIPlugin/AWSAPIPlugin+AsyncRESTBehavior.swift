//
//  AWSAPIPlugin+AsyncRESTBehavior.swift
//  
//
//  Created by eIBarto on 01.05.24.
//

import Foundation
import Amplify

public extension AWSAPIPlugin {
    func subscribe(
        request: RESTRequest,
        operationType: RESTOperationType,
        valueListener: RESTSubscriptionOperation.InProcessListener?,
        completionListener: RESTSubscriptionOperation.ResultListener?
    ) -> RESTSubscriptionOperation {
        
        let operationRequest = RESTOperationRequest(request: request, operationType: operationType)
        let operation = AWSRESTSubscriptionOperation(request: operationRequest, session: session, mapper: mapper, pluginConfig: pluginConfig, inProcessListener: valueListener, resultListener: completionListener)
        
        queue.addOperation(operation)
        return operation
    }
}

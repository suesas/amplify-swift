//
//  AWSRESTSubscriptionOperation+APIOperation.swift
//  
//
//  Created by eIBarto on 01.05.24.
//

import Foundation
import Amplify

extension AWSRESTSubscriptionOperation: APIOperation {
    func getOperationId() -> UUID {
        return id
    }

    func cancelOperation() {
        cancel()
    }

    func updateProgress(_ data: Data, response: URLResponse?) {
        if isCancelled || isFinished {
            finish()
            return
        }

        let apiOperationResponse = APIOperationResponse(error: nil, response: response, data: data)
        do {
            try apiOperationResponse.validate()
        } catch let error as APIError {
            dispatch(result: .failure(error))
            finish()
            return
        } catch {
            dispatch(result: .failure(APIError.unknown("", "", error)))
            finish()
            return
        }

        dispatchInProcess(data: data)
        self.data.append(data)
    }

    func complete(with error: Error?, response: URLResponse?) {
        if isCancelled || isFinished {
            finish()
            return
        }

        mapper.removePair(for: self)

        let apiOperationResponse = APIOperationResponse(error: error, response: response)
        do {
            try apiOperationResponse.validate()
        } catch let error as APIError {
            dispatch(result: .failure(error))
            finish()
            return
        } catch {
            dispatch(result: .failure(APIError.unknown("", "", error)))
            finish()
            return
        }

        dispatch(result: .success(data))
        finish()
    }
}

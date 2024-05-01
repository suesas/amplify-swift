@ -0,0 +1,18 @@
//
//  RESTSubscriptionEvent.swift
//  
//
//  Created by eIBarto on 01.05.24.
//

import Foundation

public enum RESTSubscriptionEvent {
    /// The subscription's connection state has changed.
    case connection(SubscriptionConnectionState)

    /// The subscription received data.
    case data(Data)
}

extension RESTSubscriptionEvent: Sendable { }

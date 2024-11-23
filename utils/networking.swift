//
//  networking.swift
//  DailyPic
//
//  Created by Paul Zenker on 23.11.24.
//

import Foundation
import Network

func checkNetworkConnection(completion: @escaping (Bool) -> Void) {
    let monitor = NWPathMonitor()
    let queue = DispatchQueue.global(qos: .background)
    
    monitor.pathUpdateHandler = { path in
        if path.status == .satisfied {
            // Network is available
            if path.isConstrained {
                // Low Data Mode is enabled
                completion(false)
            } else {
                // Network is available and Low Data Mode is not enabled
                completion(true)
            }
        } else {
            // Network is not available
            completion(false)
        }
        monitor.cancel() // Stop monitoring after getting the status
    }
    
    monitor.start(queue: queue)
}

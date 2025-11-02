//
//  AsyncSemaphore.swift
//  Weather Station App
//
//  Created by Assistant on 12/19/24.
//

import Foundation

/// Thread-safe async semaphore for controlling concurrent access
actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(value: Int) {
        self.value = value
    }
    
    func wait() async {
        value -= 1
        if value >= 0 {
            return
        }
        
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    func signal() {
        value += 1
        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.resume()
        }
    }
}
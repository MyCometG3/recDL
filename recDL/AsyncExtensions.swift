//
//  AsyncExtensions.swift
//  recDL
//
//  Created by AI Assistant on 2025/01/09.
//  Copyright © 2025 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Foundation

/// Generic async wrappers for completion-handler based APIs
extension NSObject {
    /// Helper for creating async wrappers around completion handlers
    func withCheckedContinuation<T>(_ operation: @escaping (@escaping (T) -> Void) -> Void) async -> T {
        return await withCheckedContinuation { continuation in
            operation { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Helper for creating throwing async wrappers around completion handlers  
    func withCheckedThrowingContinuation<T>(_ operation: @escaping (@escaping (Result<T, Error>) -> Void) -> Void) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            operation { result in
                continuation.resume(with: result)
            }
        }
    }
}

/// AsyncStream helpers for high-frequency callback bridging
actor StreamBridge<Element> {
    private var continuation: AsyncStream<Element>.Continuation?
    private let bufferPolicy: AsyncStream<Element>.Continuation.BufferPolicy
    
    init(bufferPolicy: AsyncStream<Element>.Continuation.BufferPolicy = .bufferingNewest(100)) {
        self.bufferPolicy = bufferPolicy
    }
    
    func createStream() -> AsyncStream<Element> {
        return AsyncStream(bufferingPolicy: bufferPolicy) { continuation in
            self.continuation = continuation
        }
    }
    
    func yield(_ element: Element) {
        continuation?.yield(element)
    }
    
    func finish() {
        continuation?.finish()
        continuation = nil
    }
}
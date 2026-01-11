//
//  race.swift
//  Daily Pic
//
//  Created by Paul Zenker on 11.01.26.
//

enum TimeoutError: Error {
  case timeout
}

/**
 Takes 2 closures and returns after one is completed
 */
func race<T>(
  _ lhs: sending @escaping () async throws -> T,
  _ rhs: sending @escaping () async throws -> T
) async throws -> T {
  return try await withThrowingTaskGroup(of: T.self) { group in
    group.addTask { try await lhs() }
    group.addTask { try await rhs() }

    defer { group.cancelAll() }

    return try await group.next()!
  }
}

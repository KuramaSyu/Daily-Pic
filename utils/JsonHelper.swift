//
//  JsonHelper.swift
//  Daily Pic
//
//  Created by Paul Zenker on 29.08.25.
//
import Foundation
import CryptoKit

/// Calculates the Hash as Hex String of a given struct
public func sha256Hex<T: Codable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(value)
    let digest = SHA256.hash(data: data)
    return digest.map{ String(format: "%02x", $0)}.joined()
}



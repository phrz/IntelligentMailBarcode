//
//  Extensions.swift
//  IntelligentMailBarcode
//
//  Created by Paul Herz on 7/29/24.
//

import Foundation

internal extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
    
    func asPrettyHex() -> String {
        return self.hexEncodedString().uppercased().chunked(by: 2).joined(separator: " ")
    }
}

internal extension String {
    func chunked(by length: Int) -> [String] {
        var startIndex = self.startIndex
        var results = [Substring]()

        while startIndex < self.endIndex {
            let endIndex = self.index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            results.append(self[startIndex..<endIndex])
            startIndex = endIndex
        }

        return results.map { String($0) }
    }
}

//
//  MACAddressValidator.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import Foundation

class MACAddressValidator {
    static func isValid(_ macAddress: String) -> Bool {
        // MAC address should be in format XX:XX:XX:XX:XX:XX
        let pattern = "^[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: macAddress.count)
        return regex?.firstMatch(in: macAddress, options: [], range: range) != nil
    }
    
    static func format(_ macAddress: String) -> String {
        // Remove common separators and spaces
        let cleaned = macAddress.replacingOccurrences(of: "-", with: ":")
                                .replacingOccurrences(of: " ", with: "")
                                .uppercased()
        
        // If it's just 12 hex chars, add colons
        if cleaned.count == 12 && cleaned.allSatisfy({ $0.isHexDigit }) {
            let formatted = cleaned.enumerated().compactMap { index, char in
                index > 0 && index % 2 == 0 ? ":\(char)" : "\(char)"
            }.joined()
            return formatted
        }
        
        return cleaned
    }
}

extension Character {
    var isHexDigit: Bool {
        return self.isNumber || ("A"..."F").contains(self) || ("a"..."f").contains(self)
    }
}
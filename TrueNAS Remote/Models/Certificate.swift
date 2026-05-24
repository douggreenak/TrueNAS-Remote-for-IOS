import Foundation
import SwiftUI

struct Certificate: Identifiable {
    let id: Int
    let name: String
    let commonName: String
    let issuer: String
    let san: [String]        // Subject Alternative Names
    let from: Date
    let until: Date
    let keyType: String      // RSA, EC
    let keyLength: Int

    var daysUntilExpiry: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: until).day ?? 0
    }

    var expiryColor: Color {
        switch daysUntilExpiry {
        case ..<0:   return .red
        case ..<30:  return .red
        case ..<90:  return .orange
        default:     return .green
        }
    }

    var expiryLabel: String {
        let d = daysUntilExpiry
        if d < 0  { return "Expired" }
        if d < 1  { return "Expires today" }
        if d < 30 { return "Expires in \(d)d" }
        return "Valid"
    }
}

struct CertificateAuthority: Identifiable {
    let id: Int
    let name: String
    let commonName: String
    let from: Date
    let until: Date
    var isInternal: Bool

    var daysUntilExpiry: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: until).day ?? 0
    }
}

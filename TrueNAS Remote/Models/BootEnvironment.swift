import Foundation
import SwiftUI

struct BootEnvironment: Identifiable {
    let id: String           // name
    let name: String
    let created: Date
    let size: Int64          // bytes
    var active: Bool         // currently booted
    var keepForever: Bool

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .binary)
    }

    var formattedDate: String {
        created.formatted(date: .abbreviated, time: .omitted)
    }
}

import Foundation

struct TrueNASUser: Identifiable {
    let id: Int              // UID
    let username: String
    let fullName: String
    let email: String
    let shell: String
    let homeDir: String
    var locked: Bool
    var sudoEnabled: Bool
    var groups: [Int]        // GIDs
    var builtIn: Bool        // system user
}

struct TrueNASGroup: Identifiable {
    let id: Int              // GID
    let name: String
    var users: [String]      // usernames
    var builtIn: Bool
    var sudoEnabled: Bool
}

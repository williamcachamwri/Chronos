import Foundation

/// Represents a single file-system event tracked by Chronos.
/// Events are immutable facts — they describe what happened at a specific moment.
enum EventType: String, Codable, Sendable {
    case created
    case modified
    case renamed
    case removed
}

struct FileEvent: Identifiable, Sendable {
    let id: Int64
    let path: String
    let name: String
    let parentPath: String
    let eventType: EventType
    let timestamp: Date
    let size: Int64
    let isDirectory: Bool
    let inode: UInt64
}

extension EventType {
    /// Returns the human-readable description of this event type.
    var description: String {
        switch self {
        case .created:   return "Created"
        case .modified:  return "Modified"
        case .renamed:   return "Renamed"
        case .removed:   return "Removed"
        }
    }

    /// Returns a color associated with the event type for UI display.
    var typeColor: (r: Double, g: Double, b: Double) {
        switch self {
        case .created:   return (0.20, 0.78, 0.35)   // green
        case .modified:  return (0.25, 0.48, 0.90)   // blue
        case .renamed:   return (0.95, 0.60, 0.10)   // amber
        case .removed:   return (0.95, 0.25, 0.25)   // red
        }
    }
}

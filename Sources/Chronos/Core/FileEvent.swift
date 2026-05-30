import Foundation

enum EventType: String, Codable, Sendable {
    case created, modified, renamed, removed
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

struct FileSnapshot: Sendable {
    let path: String
    let name: String
    let parentPath: String
    let lastEventType: EventType
    let lastEventTime: Date
    let size: Int64
    let isDirectory: Bool
    let inode: UInt64
}

enum DiffStatus: String, Sendable {
    case added, removed, modified, unchanged
}

struct FileDiff: Sendable {
    let path: String
    let name: String
    let status: DiffStatus
    let oldSize: Int64
    let newSize: Int64
    let isDirectory: Bool
}

extension EventType {
    var description: String {
        switch self {
        case .created:  return "Created"
        case .modified: return "Modified"
        case .renamed:  return "Renamed"
        case .removed:  return "Removed"
        }
    }

    var hexColor: String {
        switch self {
        case .created:  return "#34d399"  // green
        case .modified: return "#60a5fa"  // blue
        case .renamed:  return "#f59e0b"  // amber
        case .removed:  return "#f87171"  // red
        }
    }
}

extension DiffStatus {
    var description: String {
        switch self {
        case .added:     return "Added"
        case .removed:   return "Removed"
        case .modified:  return "Modified"
        case .unchanged: return "Unchanged"
        }
    }

    var hexColor: String {
        switch self {
        case .added:     return "#34d399"
        case .removed:   return "#f87171"
        case .modified:  return "#f59e0b"
        case .unchanged: return "#9ca3af"
        }
    }
}

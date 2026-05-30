import Testing
@testable import Chronos

struct ChronosTests {
    @Test func testEventTypeRawValue() async throws {
        let types: [EventType] = [.created, .modified, .renamed, .removed]
        for type in types {
            let decoded = EventType(rawValue: type.rawValue)
            #expect(decoded == type)
        }
    }
}

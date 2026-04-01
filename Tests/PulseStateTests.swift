import XCTest
@testable import PulseCore

final class PulseStateTests: XCTestCase {
    func testDecodeGreenState() throws {
        let json = """
        {"state":"green","label":"Running"}
        """.data(using: .utf8)!
        let msg = try JSONDecoder().decode(PulseMessage.self, from: json)
        XCTAssertEqual(msg.state, .green)
        XCTAssertEqual(msg.label, "Running")
        XCTAssertNil(msg.ttl)
    }

    func testDecodeWithTTL() throws {
        let json = """
        {"state":"yellow","label":"Response ready","ttl":5}
        """.data(using: .utf8)!
        let msg = try JSONDecoder().decode(PulseMessage.self, from: json)
        XCTAssertEqual(msg.state, .yellow)
        XCTAssertEqual(msg.ttl, 5)
    }

    func testDecodeAllStates() throws {
        for name in ["green", "yellow", "orange", "red", "gray"] {
            let json = """
            {"state":"\(name)","label":"test"}
            """.data(using: .utf8)!
            let msg = try JSONDecoder().decode(PulseMessage.self, from: json)
            XCTAssertEqual(msg.state.rawValue, name)
        }
    }

    func testDecodeInvalidState() {
        let json = """
        {"state":"purple","label":"test"}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(PulseMessage.self, from: json))
    }

    func testStateDisplayNames() {
        XCTAssertEqual(PulseState.green.displayName, "Running")
        XCTAssertEqual(PulseState.red.displayName, "Error")
        XCTAssertEqual(PulseState.orange.displayName, "Caution")
        XCTAssertEqual(PulseState.yellow.displayName, "Waiting")
        XCTAssertEqual(PulseState.gray.displayName, "Idle")
    }

    func testDecodeWithSessionName() throws {
        let json = """
        {"state":"green","label":"Running","session_name":"my-api"}
        """.data(using: .utf8)!
        let msg = try JSONDecoder().decode(PulseMessage.self, from: json)
        XCTAssertEqual(msg.sessionName, "my-api")
    }

    func testPriority() {
        XCTAssertGreaterThan(PulseState.red.priority, PulseState.orange.priority)
        XCTAssertGreaterThan(PulseState.orange.priority, PulseState.yellow.priority)
        XCTAssertGreaterThan(PulseState.yellow.priority, PulseState.green.priority)
        XCTAssertGreaterThan(PulseState.green.priority, PulseState.gray.priority)
    }
}

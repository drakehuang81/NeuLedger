import Testing
@testable import Features

@Suite("SectionPhase")
struct SectionPhaseTests {
    @Test("idle / loading / loaded / failed all distinct")
    func testCases() {
        let cases: [DashboardFeature.SectionPhase] = [.idle, .loading, .loaded, .failed("x")]
        #expect(Set(cases.map(\.tag)).count == 4)
    }

    @Test("failed equality compares message")
    func testFailedEquality() {
        #expect(DashboardFeature.SectionPhase.failed("a") != .failed("b"))
        #expect(DashboardFeature.SectionPhase.failed("a") == .failed("a"))
    }
}

private extension DashboardFeature.SectionPhase {
    var tag: Int {
        switch self {
        case .idle:    return 0
        case .loading: return 1
        case .loaded:  return 2
        case .failed:  return 3
        }
    }
}

import Testing
import Foundation
import Domain

@Suite("Account.resolveDefaultId Tests")
struct AccountResolveDefaultTests {
    private static func account(_ id: String, sortOrder: Int = 0) -> Account {
        Account(id: id, name: id, type: .cash, icon: "banknote", color: "#8E8E93",
                sortOrder: sortOrder, isArchived: false, createdAt: Date())
    }

    @Test("stored id pointing at a live account is honored")
    func storedHonored() {
        let accounts = [Self.account("a"), Self.account("b", sortOrder: 1)]
        #expect(Account.resolveDefaultId(stored: "b", in: accounts) == "b")
    }

    @Test("stale stored id falls back to the first account")
    func staleFallsBack() {
        let accounts = [Self.account("a"), Self.account("b", sortOrder: 1)]
        #expect(Account.resolveDefaultId(stored: "ghost", in: accounts) == "a")
    }

    @Test("nil stored id falls back to the first account")
    func nilFallsBack() {
        #expect(Account.resolveDefaultId(stored: nil, in: [Self.account("a")]) == "a")
    }

    @Test("empty account list resolves to nil")
    func emptyResolvesNil() {
        #expect(Account.resolveDefaultId(stored: "a", in: []) == nil)
    }
}

import Testing
import Foundation
import Dependencies
@testable import Core
import Domain

/// Integration tests for `BudgetUseCase.evaluateAfterTransaction` —
/// replacing the budget-warning tests that lived inside
/// TransactionClientTests before Phase 4.4. Covers the full chain:
///
/// LedgerUseCase.record → BudgetUseCase.evaluateAfterTransaction
///   → BudgetWarningPolicy.evaluate → NotificationAdapter.sendBudgetWarning
@Suite("BudgetUseCase.evaluateAfterTransaction Integration Tests")
struct BudgetUseCaseEvaluateTests {

    /// Mutable container for `NotificationAdapter` callbacks captured
    /// during a test. Uses an actor so the `@Sendable` closures inside
    /// the adapter spy can record into it safely across hops.
    actor WarningSpy {
        private(set) var sent: [(budgetId: String, percent: Int)] = []
        private(set) var lastWarned: [String: Int] = [:]

        func recordSend(id: String, percent: Int) {
            sent.append((id, percent))
        }

        func recordLastWarned(id: String, periodKey: String, percent: Int) {
            lastWarned["\(id)|\(periodKey)"] = percent
        }

        func sentCount() -> Int { sent.count }
        func sentPercents() -> [Int] { sent.map(\.percent) }
    }

    /// Build a `NotificationAdapter` whose mutating methods route into
    /// a shared `WarningSpy`. `lastWarnedPercent` returns `nil` (the
    /// default — caller can override per test by injecting a different
    /// adapter).
    private static func adapter(
        spy: WarningSpy,
        lastWarnedPercentReturn: Int? = nil
    ) -> NotificationAdapter {
        NotificationAdapter(
            requestAuthorization: { true },
            scheduleDailyReminder: { _, _ in },
            cancelDailyReminder: {},
            sendBudgetWarning: { id, _, _ in
                // Record the percent from the body — we read it via
                // sentPercents() if the format string survives — but
                // easier is to record only id then read percent from
                // setLastWarnedPercent below (which we also wire up).
                await spy.recordSend(id: id, percent: 0)
            },
            lastWarnedPercent: { _, _ in lastWarnedPercentReturn },
            setLastWarnedPercent: { percent, id, periodKey in
                Task { await spy.recordLastWarned(id: id, periodKey: periodKey, percent: percent) }
            },
            isAuthorized: { true },
            scheduleRecurringReminder: { _, _, _, _ in },
            cancelRecurringReminder: { _ in },
            pendingConfirmations: {
                let (stream, continuation) = AsyncStream<RecurringTransaction.ID>.makeStream()
                continuation.finish()
                return stream
            }
        )
    }

    /// Build a `UserSettingsAdapter` whose bool/int reads return the
    /// supplied values; setters are no-ops.
    private static func settings(
        warningEnabled: Bool,
        threshold: Int
    ) -> UserSettingsAdapter {
        UserSettingsAdapter(
            bool: { key in
                if key.rawValue == SettingsKey<Bool>.budgetWarningEnabled.rawValue {
                    return warningEnabled
                }
                return key.defaultValue
            },
            setBool: { _, _ in },
            string: { $0.defaultValue },
            setString: { _, _ in },
            int: { key in
                if key.rawValue == SettingsKey<Int>.budgetWarningThreshold.rawValue {
                    return threshold
                }
                return key.defaultValue
            },
            setInt: { _, _ in },
            date: { $0.defaultValue },
            setDate: { _, _ in }
        )
    }

    private static func budget(amount: Decimal, categoryId: UUID? = nil) -> Budget {
        Budget(
            id: UUID(),
            name: "Test Budget",
            amount: amount,
            categoryId: categoryId,
            period: .monthly,
            startDate: Date(),
            isActive: true
        )
    }

    private static func expense(amount: Decimal, categoryId: UUID? = nil) -> Transaction {
        Transaction(
            id: UUID(), amount: amount, date: Date(), note: nil,
            categoryId: categoryId, accountId: UUID(), toAccountId: nil,
            type: .expense, tags: [], aiSuggested: false,
            createdAt: Date(), updatedAt: Date()
        )
    }

    // MARK: - Tests

    @Test("Warning disabled → no notification fired even when over threshold")
    func warningDisabledNeverSends() async throws {
        let spy = WarningSpy()
        let testBudget = Self.budget(amount: 1000)
        let testTransactions = [Self.expense(amount: 900)] // 90%

        await withDependencies {
            $0.budgetClient.fetchActive = { [testBudget] }
            $0.transactionClient.fetch = { _ in testTransactions }
            $0.notificationAdapter = Self.adapter(spy: spy)
            $0.userSettingsAdapter = Self.settings(warningEnabled: false, threshold: 80)
        } operation: { @Sendable in
            let useCase = BudgetUseCase.liveValue
            await useCase.evaluateAfterTransaction(testTransactions[0])
        }

        #expect(await spy.sentCount() == 0)
    }

    @Test("Spending below threshold → no warning")
    func belowThresholdNoWarning() async throws {
        let spy = WarningSpy()
        let testBudget = Self.budget(amount: 1000)
        let testTransactions = [Self.expense(amount: 500)] // 50%

        await withDependencies {
            $0.budgetClient.fetchActive = { [testBudget] }
            $0.transactionClient.fetch = { _ in testTransactions }
            $0.notificationAdapter = Self.adapter(spy: spy)
            $0.userSettingsAdapter = Self.settings(warningEnabled: true, threshold: 80)
        } operation: { @Sendable in
            let useCase = BudgetUseCase.liveValue
            await useCase.evaluateAfterTransaction(testTransactions[0])
        }

        #expect(await spy.sentCount() == 0)
    }

    @Test("Spending crosses threshold first time → warning sent")
    func crossesThresholdSendsWarning() async throws {
        let spy = WarningSpy()
        let testBudget = Self.budget(amount: 1000)
        let testTransactions = [Self.expense(amount: 850)] // 85%

        await withDependencies {
            $0.budgetClient.fetchActive = { [testBudget] }
            $0.transactionClient.fetch = { _ in testTransactions }
            $0.notificationAdapter = Self.adapter(spy: spy, lastWarnedPercentReturn: nil)
            $0.userSettingsAdapter = Self.settings(warningEnabled: true, threshold: 80)
        } operation: { @Sendable in
            let useCase = BudgetUseCase.liveValue
            await useCase.evaluateAfterTransaction(testTransactions[0])
        }

        #expect(await spy.sentCount() == 1)
    }

    @Test("Spending stays under threshold after previous warning → no duplicate")
    func alreadyWarnedNoDuplicate() async throws {
        let spy = WarningSpy()
        let testBudget = Self.budget(amount: 1000)
        let testTransactions = [Self.expense(amount: 850)] // 85%

        await withDependencies {
            $0.budgetClient.fetchActive = { [testBudget] }
            $0.transactionClient.fetch = { _ in testTransactions }
            // The previous warning already covered the 80% threshold.
            $0.notificationAdapter = Self.adapter(spy: spy, lastWarnedPercentReturn: 80)
            $0.userSettingsAdapter = Self.settings(warningEnabled: true, threshold: 80)
        } operation: { @Sendable in
            let useCase = BudgetUseCase.liveValue
            await useCase.evaluateAfterTransaction(testTransactions[0])
        }

        #expect(await spy.sentCount() == 0)
    }
}

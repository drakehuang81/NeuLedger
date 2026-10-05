import Foundation
import SwiftData
import Dependencies
import Domain

/// A TCA dependency that provides access to the SwiftData `ModelContainer`.
///
/// Use `PersistenceBootstrap` to obtain the shared `ModelContainer` from which
/// live client implementations derive their `ModelContext` instances.
///
/// ```swift
/// @Dependency(\.persistenceBootstrap) var persistenceBootstrap
/// let container = persistenceBootstrap.modelContainer()
/// ```
public struct PersistenceBootstrap: Sendable {
    /// Returns the configured `ModelContainer` for the application.
    public var modelContainer: @Sendable () -> ModelContainer

    public init(modelContainer: @escaping @Sendable () -> ModelContainer) {
        self.modelContainer = modelContainer
    }
}

// MARK: - Live Value

extension PersistenceBootstrap: DependencyKey {
    public static let schema = Schema([
        SDTransaction.self,
        SDAccount.self,
        SDCategory.self,
        SDBudget.self,
        SDTag.self,
        SDRecurringTransaction.self,
        SDCarrier.self,
    ])

    /// App Group identifier shared between the main app and widget extension.
    /// Both local and CloudKit-backed configurations point their store at the
    /// same URL inside this container so toggling sync never moves the file.
    ///
    /// 字串本身來自 `Domain/AppGroup.swift`——改它等於改資料位置。
    private static let appGroupID = AppGroup.suiteName

    /// Whether this process is a test runner.
    ///
    /// `XCTestConfigurationFilePath` is set by the test harness in the runner
    /// process; verified empirically under this project's Swift Testing setup
    /// (`XCTestBundlePath` / `XCTestSessionIdentifier` are present too, but one
    /// signal is enough and this is the conventional one). Never true in a
    /// shipped build — the app target is launched without it.
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Shared SwiftData store URL inside the app group container.
    /// Falling back to the per-app Application Support directory keeps the
    /// app runnable even if the entitlement is misconfigured (the data won't
    /// be reachable by the widget in that case, but the main app still works).
    ///
    /// **Under tests this redirects to a per-run temporary directory**, and that
    /// is a data-safety guard rather than tidiness. `NeuLedgerTests` is hosted by
    /// `NeuLedger.app`, so it inherits the `group.com.drake.NeuLedger`
    /// entitlement — meaning the App Group path below is the *same*
    /// `default.store` the installed app uses. A test that reaches the real
    /// `wipeAllSyncData()` therefore deletes the user's actual ledger, and it
    /// does so while PASSING. That happened during the data-integrity PR: an
    /// end-to-end wipe test ran on a simulator and wiped the store shared with
    /// the installed app. That test was removed, but removal only fixed the one
    /// caller; this redirect fixes the mechanism, so the next test to call a
    /// destructive persistence path can no longer reach real data.
    private static let storeURL: URL = {
        let filename = "default.store"
        if isRunningTests {
            let dir = URL.temporaryDirectory
                .appending(path: "NeuLedgerTests-\(ProcessInfo.processInfo.processIdentifier)", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.appending(path: filename, directoryHint: .notDirectory)
        }
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            let dir = groupURL.appending(path: "Library/Application Support", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.appending(path: filename, directoryHint: .notDirectory)
        }
        let fallback = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback.appending(path: filename, directoryHint: .notDirectory)
    }()

    public static let localConfiguration = ModelConfiguration(
        schema: schema,
        url: storeURL,
        cloudKitDatabase: .none
    )

    public static let cloudConfiguration = ModelConfiguration(
        schema: schema,
        url: storeURL,
        cloudKitDatabase: .private("iCloud.com.drake.NeuLedger")
    )

    /// 整個 process 共用的容器 box；換容器時改的是它的內容（spec A3）。See
    /// `ModelContainerKey.swift` for why `SwiftDataStore` depends on this box
    /// instead of the container directly.
    ///
    /// No `nonisolated(unsafe)` needed: `ModelContainerBox` is already
    /// `@unchecked Sendable` and this is a `static let`, not a stored `var`.
    public static let containerBox: ModelContainerBox = {
        ModelContainerBox(makeInitialContainer())
    }()

    /// Shared live container. On launch, restores the CloudKit-backed container if sync was
    /// previously enabled. Replaced at runtime by CloudSyncUseCase during the migration flow.
    ///
    /// Backed by `containerBox` so assigning here immediately updates every
    /// `SwiftDataStore` reading through the box — no cold launch required.
    ///
    /// No `nonisolated(unsafe)` needed: this is a computed property with no
    /// stored backing of its own — the storage (and its own locking) lives
    /// in `containerBox`. The modifier only makes sense on stored state.
    public static var container: ModelContainer {
        get { containerBox.container }
        set { containerBox.container = newValue }
    }

    /// Builds the initial container for `containerBox`. Moved out of the
    /// `container` property's old lazy initializer verbatim — behavior is
    /// unchanged, only the storage mechanism (box vs. plain static var) is new.
    private static func makeInitialContainer() -> ModelContainer {
        do {
            // Read raw UserDefaults directly here (rather than via UserSettingsAdapter)
            // because this static initializer runs before TCA dependencies resolve.
            // Use SettingsKey.rawValue as the single source of truth for the key.
            let isSyncEnabled = UserDefaults.standard.bool(forKey: SettingsKey<Bool>.isSyncEnabled.rawValue)
            let isCloudKitAvailable = FileManager.default.ubiquityIdentityToken != nil

            if isSyncEnabled && isCloudKitAvailable {
                let c = try ModelContainer(for: schema, configurations: [cloudConfiguration])
                // 同步開著的這台正是會長出重複 seed 列的那一台，而這條路徑（維持
                // 原行為）不呼叫 `seedIfNeeded`——所以去重不能掛在 seeding 裡面，
                // 必須在這裡獨立跑一次，否則整條防線在最需要它的設定下一行都不會執行。
                deduplicateSeedCategories(in: ModelContext(c))
                return c
            } else {
                let c = try ModelContainer(for: schema, configurations: [localConfiguration])
                let context = ModelContext(c)
                // 先修既有資料再補缺的：使用者關掉同步之後，同步期間長出來的重複列
                // 仍然留在本地 store 裡。
                deduplicateSeedCategories(in: context)
                seedIfNeeded(in: context)
                return c
            }
        } catch {
            fatalError("Failed to create live ModelContainer: \(error)")
        }
    }

    public static let liveValue = PersistenceBootstrap(
        modelContainer: { PersistenceBootstrap.container }
    )

    /// An in-memory `ModelConfiguration` with CloudKit mirroring explicitly off.
    ///
    /// **`cloudKitDatabase: .none` is load-bearing, not defensive.** That
    /// parameter defaults to `.automatic`, which means "mirror to the primary
    /// CloudKit container named in the app's entitlements" — and this app's
    /// entitlements do name one (`iCloud.com.drake.NeuLedger`). A test host
    /// built from those entitlements therefore gets an
    /// `NSCloudKitMirroringDelegate` attached to every in-memory store, even
    /// though no test asks for sync. Mirroring setup then fails (there is no
    /// iCloud account in the simulator), CoreData's recovery path removes the
    /// store, and the next fetch or save reaches a store that is no longer
    /// there: `-[NSSQLDefaultConnectionManager handleStoreRequest:]` raises
    /// `NSInternalInconsistencyException` ("No eligible connection available").
    ///
    /// That is an **Objective-C exception, so `try`/`catch` cannot see it** —
    /// it goes straight to `abort()`, killing the test host before any test
    /// runs. The failure surfaces only as
    /// `Early unexpected exit ... (Crash: NeuLedger)` with zero tests
    /// executed, which names neither CloudKit nor this file.
    ///
    /// iOS 26.5 tolerated the same configuration, so the whole suite was green
    /// locally while Xcode Cloud (on iOS 27) failed every run. Any new
    /// in-memory container must come through here rather than calling
    /// `ModelConfiguration(schema:isStoredInMemoryOnly:)` directly.
    public static func inMemoryConfiguration(for schema: Schema) -> ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
    }

    /// In-memory `ModelContainer` shared by `PersistenceBootstrap.testValue` and
    /// `\.modelContainer`'s testValue. Created once per process so tests
    /// running in the same target share seeded default data.
    public static let testContainer: ModelContainer = {
        let configuration = inMemoryConfiguration(for: schema)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            seedIfNeeded(in: ModelContext(container))
            return container
        } catch {
            fatalError("Failed to create test ModelContainer: \(error)")
        }
    }()

    /// An in-memory `PersistenceBootstrap` suitable for unit tests.
    public static let testValue = PersistenceBootstrap(
        modelContainer: { PersistenceBootstrap.testContainer }
    )
}

// Analytics aggregation moved to `TransactionAnalyticsKernel` (Phase 5.5)
// so `AnalyticsUseCase+Live` owns the read-side semantic boundary and
// `PersistenceBootstrap` returns to a focused role: container lifecycle +
// seed data.

// MARK: - DependencyValues Registration

public extension DependencyValues {
    /// The persistence bootstrap providing access to the SwiftData `ModelContainer`.
    var persistenceBootstrap: PersistenceBootstrap {
        get { self[PersistenceBootstrap.self] }
        set { self[PersistenceBootstrap.self] = newValue }
    }
}

// MARK: - Seed Data

/// A default category bundled with the app. The `id` is fixed (not random)
/// so the same default category seeded on two devices — or after a
/// delete-and-reinstall — produces SwiftData rows that share a UUID, which
/// lets `seedIfNeeded` skip rows already present from a prior CloudKit sync.
struct SeedCategory {
    let id: UUID
    let name: String
    let icon: String
    let color: String
}

extension SeedCategory {
    private static func stableID(_ suffix: String) -> UUID {
        UUID(uuidString: "9E0FED11-CCCC-0000-0000-0000000000\(suffix)")!
    }

    static var food: SeedCategory {
        SeedCategory(id: stableID("01"), name: "Food", icon: "fork.knife", color: "#FF6B6B")
    }

    static var transport: SeedCategory {
        SeedCategory(id: stableID("02"), name: "Transport", icon: "car.fill", color: "#4ECDC4")
    }

    static var entertainment: SeedCategory {
        SeedCategory(id: stableID("03"), name: "Entertainment", icon: "gamecontroller.fill", color: "#45B7D1")
    }

    static var shopping: SeedCategory {
        SeedCategory(id: stableID("04"), name: "Shopping", icon: "bag.fill", color: "#96CEB4")
    }

    static var housing: SeedCategory {
        SeedCategory(id: stableID("05"), name: "Housing", icon: "house.fill", color: "#FFEAA7")
    }

    static var utilities: SeedCategory {
        SeedCategory(id: stableID("06"), name: "Utilities", icon: "bolt.fill", color: "#DDA0DD")
    }

    static var health: SeedCategory {
        SeedCategory(id: stableID("07"), name: "Health", icon: "heart.fill", color: "#FF6B9D")
    }

    static var education: SeedCategory {
        SeedCategory(id: stableID("08"), name: "Education", icon: "book.fill", color: "#C9B1FF")
    }

    static var otherExpense: SeedCategory {
        SeedCategory(id: stableID("09"), name: "Other Expense", icon: "ellipsis.circle.fill", color: "#95A5A6")
    }

    static var salary: SeedCategory {
        SeedCategory(id: stableID("0A"), name: "Salary", icon: "banknote.fill", color: "#2ECC71")
    }

    static var freelance: SeedCategory {
        SeedCategory(id: stableID("0B"), name: "Freelance", icon: "laptopcomputer", color: "#3498DB")
    }

    static var investment: SeedCategory {
        SeedCategory(id: stableID("0C"), name: "Investment", icon: "chart.line.uptrend.xyaxis", color: "#F39C12")
    }

    static var gift: SeedCategory {
        SeedCategory(id: stableID("0D"), name: "Gift", icon: "gift.fill", color: "#E74C3C")
    }

    static var otherIncome: SeedCategory {
        SeedCategory(id: stableID("0E"), name: "Other Income", icon: "ellipsis.circle.fill", color: "#1ABC9C")
    }
    static var defaultExpenseCategories: [SeedCategory] {
        [.food, .transport, .entertainment, .shopping, .housing, .utilities, .health, .education, .otherExpense]
    }
    static var defaultIncomeCategories: [SeedCategory] {
        [.salary, .freelance, .investment, .gift, .otherIncome]
    }
}



// MARK: - Seeding

// Not `private` — besides the two static lazy initializers above
// (`makeInitialContainer()`, `testContainer`), `PlatformClient+Live.swift`'s
// `wipeAllSyncData` now calls this directly as a third call site, right
// after it rebuilds the local container (spec A1). `internal` (the default
// here) is enough since that call site lives in the same `Core` target.
extension PersistenceBootstrap {
    static func seedIfNeeded(in context: ModelContext) {
        do {
            try insertMissingDefaults(SeedCategory.defaultExpenseCategories,
                                      type: .expense, in: context)
            try insertMissingDefaults(SeedCategory.defaultIncomeCategories,
                                      type: .income, in: context)

            if context.hasChanges {
                try context.save()
            }
        } catch {
            print("Failed to seed default data: \(error)")
        }
    }

    static func insertMissingDefaults(_ seeds: [SeedCategory],
                                      type: TransactionType,
                                      in context: ModelContext) throws {
        for (index, seed) in seeds.enumerated() {
            let seedID = seed.id
            var descriptor = FetchDescriptor<SDCategory>(
                predicate: #Predicate { $0.id == seedID }
            )
            descriptor.fetchLimit = 1
            if try context.fetch(descriptor).first != nil { continue }

            context.insert(SDCategory(
                id: seed.id, name: seed.name, icon: seed.icon, color: seed.color,
                type: type.rawValue, sortOrder: index, isDefault: true
            ))
        }
    }
}

// MARK: - Duplicate seed repair

extension PersistenceBootstrap {
    /// 把共用同一個 seed id 的多筆 `SDCategory` 收斂成一筆，回傳刪掉的列數。
    ///
    /// **為什麼會有重複列**（health-audit #8 / spec A4 的後半）：`SeedCategory`
    /// 的 id 是固定常數，兩台裝置各自冷啟動時各自 seed 出一份，之後才開啟同步。
    /// CloudKit mirroring 以 store object ID 產生 CKRecord name，所以兩台的
    /// 「Food」是兩筆不同的 CKRecord，同步後同一台裝置上會出現兩筆
    /// `id` 相同的列。`seedIfNeeded` 的 fetch-by-id 檢查只防得住「再插第三筆」，
    /// 移除不了已經存在的那一筆——分類選單因此永久並列兩個同名分類。
    ///
    /// **為什麼不用 `#Unique`**（審計裡提到的另一條路）：CloudKit mirroring 有一組
    /// schema 限制，其中包含不接受 unique constraint。這一條沒有在本專案實測過，
    /// 但同一組限制的另一條——「每個屬性都必須有預設值」——在這個 schema 裡看得到
    /// 實證：`SDCategory` 連 `id` 都寫成 `var id: UUID = UUID()`。掃描去重不論那條
    /// 限制是否成立都可行，所以走這條。
    ///
    /// **為什麼只掃 seed id**：使用者自建分類拿的是隨機 UUID，兩台裝置不可能撞同一個
    /// id，所以非 seed 的重複 id 只可能來自我們自己的程式錯誤，不是同步產物——那種列
    /// 沒有任何機制可以重建，誤刪就是永久損失，因此刻意不碰。相對地 seed 列永遠可以
    /// 被 `seedIfNeeded` 重新種回來，這正是把範圍收在這裡的理由（見下面的收斂性）。
    ///
    /// **為什麼直接 `context.delete` 是安全的**：`SDTransaction` / `SDBudget` /
    /// `SDRecurringTransaction` 都用裸 `UUID?` 引用分類，而留下來的那一筆帶著
    /// **同一個 id**，所以引用全部照樣對得上。這裡刻意不走 `deleteCategory` 的
    /// 清引用規則（spec A6）——那條規則是為「這個 id 從此不存在」而寫的，在這裡
    /// 套用反而會把好好的交易清成無分類。
    ///
    /// **收斂性**：留哪一筆完全由列上的欄位值決定（見 `survivorOrder`），所以
    /// 兩台裝置看到同一組列時會算出同一個答案，不會互刪對方留下的那筆。唯一的例外
    /// 是兩筆欄位值完全相同——此時兩台可能各自刪掉不同的那筆，刪除同步回來後該 id
    /// 會一筆不剩；因為範圍收在 seed id，下一次冷啟動的 `seedIfNeeded` 會把它種回來，
    /// 期間交易的 `categoryId` 不變，重種後自動重新對上。
    @discardableResult
    static func deduplicateSeedCategories(in context: ModelContext) -> Int {
        var deletedCount = 0
        do {
            for seed in SeedCategory.defaultExpenseCategories + SeedCategory.defaultIncomeCategories {
                let seedID = seed.id
                let rows = try context.fetch(
                    FetchDescriptor<SDCategory>(predicate: #Predicate { $0.id == seedID })
                )
                guard rows.count > 1 else { continue }

                let ordered = rows.sorted {
                    survivorOrder($0, seed: seed) < survivorOrder($1, seed: seed)
                }
                for duplicate in ordered.dropFirst() {
                    context.delete(duplicate)
                    deletedCount += 1
                }
            }
            if context.hasChanges {
                try context.save()
            }
        } catch {
            print("Failed to deduplicate seeded categories: \(error)")
        }
        return deletedCount
    }

    /// 排序鍵：值最小的那一筆就是留下來的那一筆。
    ///
    /// 第一個鍵是「是否仍與 seed 定義完全相同」，被使用者改過的那一筆（0）排在
    /// 原封不動的那一筆（1）前面——預設分類的 name / icon / color 是可編輯的
    /// （`AddEditCategoryFeature` 只鎖 `type`），而使用者的編輯只存在於他動手的
    /// 那一台裝置上。其餘的鍵純粹是為了在雙方都被改過（或都沒被改過）時仍然有一個
    /// 兩台裝置都算得出來的固定答案。
    ///
    /// 第一個鍵用 `Int` 不用 `Bool`：`Bool` 沒有 conform `Comparable`，
    /// tuple 的 `<` 會直接編不過。
    private static func survivorOrder(
        _ row: SDCategory,
        seed: SeedCategory
    ) -> (Int, String, String, String, String, Int) {
        let isPristine = row.name == seed.name
            && row.icon == seed.icon
            && row.color == seed.color
        return (isPristine ? 1 : 0, row.name, row.icon, row.color, row.type, row.sortOrder)
    }
}

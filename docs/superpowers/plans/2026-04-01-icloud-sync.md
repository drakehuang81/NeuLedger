# iCloud Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add iCloud sync via CloudKit private database as a paid feature, with a mock subscription gate and dynamic container swap (no app restart required).

**Architecture:** `SyncClient` interface in Domain; live implementation in Core handles CloudKit container creation and one-time data migration from local SQLite to CloudKit-backed store via `DatabaseClient.container` static swap. `SyncSettingsFeature` in Features drives the UI with three states (upsell / enable / enabled).

**Tech Stack:** SwiftData + CloudKit (`ModelConfiguration(cloudKitDatabase:)`), TCA 1.23.1, Swift Testing, `AsyncThrowingStream` for migration progress.

---

## File Map

| Action | Path | Responsibility |
|--------|------|---------------|
| Modify | `Features/Sources/Domain/Clients/UserSettingsClient.swift` | Add `.isSubscribed`, `.isSyncEnabled` Bool keys |
| Modify | `Features/Sources/Core/Persistence/DatabaseClient.swift` | Add `nonisolated(unsafe) static var container` |
| Modify | `Features/Sources/Core/Persistence/Models/SDTransaction.swift` | CloudKit schema compat |
| Modify | `Features/Sources/Core/Persistence/Models/SDAccount.swift` | CloudKit schema compat |
| Modify | `Features/Sources/Core/Persistence/Models/SDCategory.swift` | CloudKit schema compat |
| Modify | `Features/Sources/Core/Persistence/Models/SDBudget.swift` | CloudKit schema compat |
| Modify | `Features/Sources/Core/Persistence/Models/SDTag.swift` | CloudKit schema compat |
| Modify | `Features/Sources/Core/Persistence/Models/SDRecurringTransaction.swift` | CloudKit schema compat |
| Create | `Features/Sources/Domain/Clients/SyncClient.swift` | Client interface + DependencyValues |
| Create | `Features/Sources/Core/Clients/SyncClient+Live.swift` | Migration + CloudKit container |
| Create | `Features/Sources/Features/Settings/SyncSettings/SyncSettingsFeature.swift` | TCA Reducer |
| Create | `Features/Sources/Features/Settings/SyncSettings/SyncSettingsView.swift` | SwiftUI View (3 states) |
| Create | `Features/Tests/FeaturesTests/SyncSettingsFeatureTests.swift` | TestStore tests |
| Modify | `Features/Sources/Features/Settings/SettingsFeature.swift` | Add `.syncSettings` destination |
| Modify | `Features/Sources/Features/Settings/SettingsView.swift` | Add Sync row |
| Manual | Xcode project entitlements | iCloud + CloudKit capability (see Task 9) |

---

## Task 1: UserSettingsKey — add isSubscribed + isSyncEnabled

**Files:**
- Modify: `Features/Sources/Domain/Clients/UserSettingsClient.swift`

- [ ] **Step 1: Add the two new Bool keys**

  Open `Features/Sources/Domain/Clients/UserSettingsClient.swift`. In the `extension SettingsKey where Value == Bool` block, add after the last existing Bool key:

  ```swift
  /// Mock subscription gate. Replace with StoreKit entitlement check in the subscription cycle.
  public static let isSubscribed = SettingsKey<Bool>(rawValue: "isSubscribed", defaultValue: false)
  /// Set to true once the one-time local → CloudKit migration has completed.
  public static let isSyncEnabled = SettingsKey<Bool>(rawValue: "isSyncEnabled", defaultValue: false)
  ```

- [ ] **Step 2: Build to confirm no errors**

  ```bash
  xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    | grep -E "error:|Build succeeded"
  ```

  Expected: `Build succeeded`

- [ ] **Step 3: Commit**

  ```bash
  git add Features/Sources/Domain/Clients/UserSettingsClient.swift
  git commit -m "feat(domain): add isSubscribed and isSyncEnabled settings keys"
  ```

---

## Task 2: DatabaseClient — swappable static container

**Files:**
- Modify: `Features/Sources/Core/Persistence/DatabaseClient.swift`

- [ ] **Step 1: Replace liveValue with static container pattern**

  In `DatabaseClient.swift`, replace the `liveValue` computed property and add a `nonisolated(unsafe) static var container`. The section currently looks like:

  ```swift
  extension DatabaseClient: DependencyKey {
      public static let liveValue: DatabaseClient = {
          let schema = Schema([...])
          let configuration = ModelConfiguration(schema: schema)
          let container: ModelContainer
          do {
              container = try ModelContainer(for: schema, configurations: [configuration])
              let context = ModelContext(container)
              seedIfNeeded(in: context)
          } catch {
              fatalError("Failed to create live ModelContainer: \(error)")
          }
          return DatabaseClient(modelContainer: { container })
      }()
  ```

  Replace it with:

  ```swift
  extension DatabaseClient: DependencyKey {
      /// Shared live container. Replaced once by SyncClient when user enables CloudKit sync.
      nonisolated(unsafe) public static var container: ModelContainer = {
          let schema = Schema([
              SDTransaction.self,
              SDAccount.self,
              SDCategory.self,
              SDBudget.self,
              SDTag.self,
              SDRecurringTransaction.self,
          ])
          do {
              let c = try ModelContainer(
                  for: schema,
                  configurations: [ModelConfiguration(schema: schema)]
              )
              seedIfNeeded(in: ModelContext(c))
              return c
          } catch {
              fatalError("Failed to create live ModelContainer: \(error)")
          }
      }()

      public static let liveValue = DatabaseClient(
          modelContainer: { DatabaseClient.container }
      )
  ```

  The `testValue` block is unchanged — it creates its own isolated in-memory container and does NOT reference `DatabaseClient.container`.

- [ ] **Step 2: Build to confirm no errors**

  ```bash
  xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    | grep -E "error:|Build succeeded"
  ```

  Expected: `Build succeeded`

- [ ] **Step 3: Commit**

  ```bash
  git add Features/Sources/Core/Persistence/DatabaseClient.swift
  git commit -m "feat(core): make DatabaseClient.container a swappable static var for CloudKit migration"
  ```

---

## Task 3: SD Models — CloudKit schema compatibility

CloudKit requires every SwiftData model property to have a default value. `@Attribute(.unique)` is also unsupported (CloudKit ignores it and can throw migration errors). Apply changes to all six models.

**Files:**
- Modify: `Features/Sources/Core/Persistence/Models/SDTransaction.swift`
- Modify: `Features/Sources/Core/Persistence/Models/SDAccount.swift`
- Modify: `Features/Sources/Core/Persistence/Models/SDCategory.swift`
- Modify: `Features/Sources/Core/Persistence/Models/SDBudget.swift`
- Modify: `Features/Sources/Core/Persistence/Models/SDTag.swift`
- Modify: `Features/Sources/Core/Persistence/Models/SDRecurringTransaction.swift`

- [ ] **Step 1: Update SDTransaction**

  Change the property declarations (not the init — the init stays the same since callers already pass all values explicitly). Update the `@Attribute(.unique)` line and add defaults to non-optional properties:

  ```swift
  @Model
  public final class SDTransaction {
      public var id: UUID = UUID()                    // was: @Attribute(.unique) var id: UUID
      public var amount: Decimal = Decimal(0)
      public var date: Date = Date()
      public var note: String? = nil
      public var categoryId: UUID? = nil
      public var accountId: UUID = UUID()
      public var toAccountId: UUID? = nil
      public var type: String = ""
      public var aiSuggested: Bool = false
      public var createdAt: Date = Date()
      public var updatedAt: Date = Date()
      @Relationship public var tags: [SDTag] = []
      // init is unchanged
  ```

- [ ] **Step 2: Update SDAccount**

  ```swift
  @Model
  public final class SDAccount {
      public var id: UUID = UUID()                    // was: @Attribute(.unique)
      public var name: String = ""
      public var type: String = ""
      public var icon: String = ""
      public var color: String = ""
      public var sortOrder: Int = 0
      public var isArchived: Bool = false
      public var createdAt: Date = Date()
      // init is unchanged
  ```

- [ ] **Step 3: Update SDCategory**

  ```swift
  @Model
  public final class SDCategory {
      public var id: UUID = UUID()                    // was: @Attribute(.unique)
      public var name: String = ""
      public var icon: String = ""
      public var color: String = ""
      public var type: String = ""
      public var sortOrder: Int = 0
      public var isDefault: Bool = false
      // init is unchanged
  ```

- [ ] **Step 4: Update SDBudget**

  ```swift
  @Model
  public final class SDBudget {
      public var id: UUID = UUID()                    // was: @Attribute(.unique)
      public var name: String = ""
      public var amount: Decimal = Decimal(0)
      public var categoryId: UUID? = nil
      public var period: String = ""
      public var startDate: Date = Date()
      public var isActive: Bool = true
      // init is unchanged
  ```

- [ ] **Step 5: Update SDTag**

  ```swift
  @Model
  public final class SDTag {
      public var id: UUID = UUID()                    // was: @Attribute(.unique)
      public var name: String = ""
      public var color: String? = nil
      @Relationship(inverse: \SDTransaction.tags) public var transactions: [SDTransaction] = []
      // init is unchanged
  ```

- [ ] **Step 6: Update SDRecurringTransaction**

  ```swift
  @Model
  public final class SDRecurringTransaction {
      public var id: UUID = UUID()                    // was: @Attribute(.unique)
      public var amount: Decimal = Decimal(0)
      public var note: String? = nil
      public var categoryId: UUID? = nil
      public var accountId: UUID = UUID()
      public var toAccountId: UUID? = nil
      public var typeRaw: String = ""
      public var tagIds: [UUID] = []
      public var frequencyRaw: String = ""
      public var nextDueDate: Date = Date()
      public var isActive: Bool = true
      public var createdAt: Date = Date()
      // init is unchanged
  ```

- [ ] **Step 7: Build and run all tests**

  ```bash
  xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    | grep -E "error:|Test Suite|passed|failed"
  ```

  Expected: All existing tests pass. The schema change is backward-compatible (adding defaults to properties is a lightweight SwiftData migration).

- [ ] **Step 8: Commit**

  ```bash
  git add Features/Sources/Core/Persistence/Models/
  git commit -m "feat(core): remove @Attribute(.unique) and add CloudKit-compatible property defaults to all SD models"
  ```

---

## Task 4: SyncClient — Domain interface

**Files:**
- Create: `Features/Sources/Domain/Clients/SyncClient.swift`

- [ ] **Step 1: Create the file**

  ```swift
  // Features/Sources/Domain/Clients/SyncClient.swift
  import Dependencies
  import DependenciesMacros

  /// Manages iCloud sync state and drives the one-time local → CloudKit migration.
  @DependencyClient
  public struct SyncClient: Sendable {
      /// Returns true if the device has an active iCloud account.
      public var isCloudKitAvailable: @Sendable () -> Bool = { false }

      /// Performs the one-time migration from local SwiftData to CloudKit-backed store.
      /// Yields Double progress values (0.0 – 1.0) and finishes when complete.
      /// Throws on failure; the caller is responsible for rollback UI.
      public var enableSync: @Sendable () -> AsyncThrowingStream<Double, Error> = { .finished }
  }

  extension SyncClient: DependencyKey {
      public static let testValue = SyncClient()
  }

  public extension DependencyValues {
      var syncClient: SyncClient {
          get { self[SyncClient.self] }
          set { self[SyncClient.self] = newValue }
      }
  }
  ```

- [ ] **Step 2: Build to confirm no errors**

  ```bash
  xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    | grep -E "error:|Build succeeded"
  ```

  Expected: `Build succeeded`

- [ ] **Step 3: Commit**

  ```bash
  git add Features/Sources/Domain/Clients/SyncClient.swift
  git commit -m "feat(domain): add SyncClient interface with isCloudKitAvailable and enableSync"
  ```

---

## Task 5: SyncClient+Live — migration implementation

**Files:**
- Create: `Features/Sources/Core/Clients/SyncClient+Live.swift`

- [ ] **Step 1: Create the live implementation**

  Replace `iCloud.com.yourcompany.NeuLedger` with your actual CloudKit container identifier (set up in App Store Connect — see Task 9).

  ```swift
  // Features/Sources/Core/Clients/SyncClient+Live.swift
  import CloudKit
  import Dependencies
  import Domain
  import Foundation
  import SwiftData

  extension SyncClient: DependencyKey {
      public static var liveValue: SyncClient {
          @Dependency(\.userSettingsClient) var userSettingsClient

          return SyncClient(
              isCloudKitAvailable: {
                  FileManager.default.ubiquityIdentityToken != nil
              },
              enableSync: {
                  AsyncThrowingStream { continuation in
                      Task {
                          do {
                              let schema = Schema([
                                  SDTransaction.self,
                                  SDAccount.self,
                                  SDCategory.self,
                                  SDBudget.self,
                                  SDTag.self,
                                  SDRecurringTransaction.self,
                              ])
                              let cloudConfig = ModelConfiguration(
                                  schema: schema,
                                  cloudKitDatabase: .private("iCloud.com.yourcompany.NeuLedger") // configure in App Store Connect + Entitlements
                              )
                              let cloudContainer = try ModelContainer(
                                  for: schema,
                                  configurations: [cloudConfig]
                              )
                              let cloudContext = ModelContext(cloudContainer)
                              let localContext = ModelContext(DatabaseClient.container)

                              // Step 1: SDTag (no dependencies)
                              let tags = try localContext.fetch(FetchDescriptor<SDTag>())
                              var tagMap: [UUID: SDTag] = [:]
                              for tag in tags {
                                  let newTag = SDTag(id: tag.id, name: tag.name, color: tag.color)
                                  cloudContext.insert(newTag)
                                  tagMap[tag.id] = newTag
                              }
                              try cloudContext.save()
                              continuation.yield(0.1)

                              // Step 2: SDCategory (no dependencies)
                              let categories = try localContext.fetch(FetchDescriptor<SDCategory>())
                              for cat in categories {
                                  cloudContext.insert(SDCategory(
                                      id: cat.id,
                                      name: cat.name,
                                      icon: cat.icon,
                                      color: cat.color,
                                      type: cat.type,
                                      sortOrder: cat.sortOrder,
                                      isDefault: cat.isDefault
                                  ))
                              }
                              try cloudContext.save()
                              continuation.yield(0.25)

                              // Step 3: SDAccount (no dependencies)
                              let accounts = try localContext.fetch(FetchDescriptor<SDAccount>())
                              for acc in accounts {
                                  cloudContext.insert(SDAccount(
                                      id: acc.id,
                                      name: acc.name,
                                      type: acc.type,
                                      icon: acc.icon,
                                      color: acc.color,
                                      sortOrder: acc.sortOrder,
                                      isArchived: acc.isArchived,
                                      createdAt: acc.createdAt
                                  ))
                              }
                              try cloudContext.save()
                              continuation.yield(0.4)

                              // Step 4: SDBudget (no dependencies)
                              let budgets = try localContext.fetch(FetchDescriptor<SDBudget>())
                              for b in budgets {
                                  cloudContext.insert(SDBudget(
                                      id: b.id,
                                      name: b.name,
                                      amount: b.amount,
                                      categoryId: b.categoryId,
                                      period: b.period,
                                      startDate: b.startDate,
                                      isActive: b.isActive
                                  ))
                              }
                              try cloudContext.save()
                              continuation.yield(0.55)

                              // Step 5: SDRecurringTransaction (no relationships)
                              let recurring = try localContext.fetch(FetchDescriptor<SDRecurringTransaction>())
                              for r in recurring {
                                  cloudContext.insert(SDRecurringTransaction(
                                      id: r.id,
                                      amount: r.amount,
                                      note: r.note,
                                      categoryId: r.categoryId,
                                      accountId: r.accountId,
                                      toAccountId: r.toAccountId,
                                      typeRaw: r.typeRaw,
                                      tagIds: r.tagIds,
                                      frequencyRaw: r.frequencyRaw,
                                      nextDueDate: r.nextDueDate,
                                      isActive: r.isActive,
                                      createdAt: r.createdAt
                                  ))
                              }
                              try cloudContext.save()
                              continuation.yield(0.7)

                              // Step 6: SDTransaction (depends on SDTag via relationship)
                              let transactions = try localContext.fetch(FetchDescriptor<SDTransaction>())
                              for tx in transactions {
                                  let newTx = SDTransaction(
                                      id: tx.id,
                                      amount: tx.amount,
                                      date: tx.date,
                                      note: tx.note,
                                      categoryId: tx.categoryId,
                                      accountId: tx.accountId,
                                      toAccountId: tx.toAccountId,
                                      type: tx.type,
                                      aiSuggested: tx.aiSuggested,
                                      createdAt: tx.createdAt,
                                      updatedAt: tx.updatedAt
                                  )
                                  newTx.tags = tx.tags.compactMap { tagMap[$0.id] }
                                  cloudContext.insert(newTx)
                              }
                              try cloudContext.save()
                              continuation.yield(0.9)

                              // Swap container — all subsequent databaseClient operations use CloudKit
                              DatabaseClient.container = cloudContainer
                              userSettingsClient.setBool(true, .isSyncEnabled)

                              continuation.yield(1.0)
                              continuation.finish()
                          } catch {
                              continuation.finish(throwing: error)
                          }
                      }
                  }
              }
          )
      }
  }
  ```

- [ ] **Step 2: Build to confirm no errors**

  ```bash
  xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    | grep -E "error:|Build succeeded"
  ```

  Expected: `Build succeeded`

- [ ] **Step 3: Commit**

  ```bash
  git add Features/Sources/Core/Clients/SyncClient+Live.swift
  git commit -m "feat(core): add SyncClient live implementation with CloudKit migration and container swap"
  ```

---

## Task 6: SyncSettingsFeature — Reducer + tests (TDD)

**Files:**
- Create: `Features/Tests/FeaturesTests/SyncSettingsFeatureTests.swift` (write first)
- Create: `Features/Sources/Features/Settings/SyncSettings/SyncSettingsFeature.swift`

- [ ] **Step 1: Write the failing tests**

  ```swift
  // Features/Tests/FeaturesTests/SyncSettingsFeatureTests.swift
  import ComposableArchitecture
  import Testing
  @testable import Features

  @Suite("SyncSettingsFeature Tests")
  struct SyncSettingsFeatureTests {

      @Test("task loads isSubscribed, isSyncEnabled, isCloudKitAvailable from dependencies")
      func taskLoadsState() async {
          let store = await TestStore(initialState: SyncSettingsFeature.State()) {
              SyncSettingsFeature()
          } withDependencies: {
              $0.userSettingsClient.bool = { key in
                  switch key.rawValue {
                  case "isSubscribed": return true
                  case "isSyncEnabled": return false
                  default: return key.defaultValue
                  }
              }
              $0.syncClient.isCloudKitAvailable = { true }
          }
          await store.send(.task) {
              $0.isSubscribed = true
              $0.isSyncEnabled = false
              $0.isCloudKitAvailable = true
          }
      }

      @Test("subscribeNowTapped sets isSubscribed true and persists to settings")
      func subscribeNowPersists() async {
          var stored: [String: Bool] = [:]
          let store = await TestStore(initialState: SyncSettingsFeature.State()) {
              SyncSettingsFeature()
          } withDependencies: {
              $0.userSettingsClient.bool = { _ in false }
              $0.userSettingsClient.setBool = { value, key in stored[key.rawValue] = value }
              $0.syncClient.isCloudKitAvailable = { false }
          }
          await store.send(.subscribeNowTapped) {
              $0.isSubscribed = true
          }
          #expect(stored["isSubscribed"] == true)
      }

      @Test("enableSyncTapped streams progress and completes")
      func enableSyncCompletes() async {
          let store = await TestStore(
              initialState: SyncSettingsFeature.State(isSubscribed: true)
          ) {
              SyncSettingsFeature()
          } withDependencies: {
              $0.syncClient.enableSync = {
                  AsyncThrowingStream { continuation in
                      continuation.yield(0.5)
                      continuation.yield(1.0)
                      continuation.finish()
                  }
              }
              $0.userSettingsClient.bool = { _ in false }
              $0.userSettingsClient.setBool = { _, _ in }
          }
          await store.send(.enableSyncTapped) {
              $0.migrationState = .migrating(progress: 0)
          }
          await store.receive(.migrationProgressUpdated(0.5)) {
              $0.migrationState = .migrating(progress: 0.5)
          }
          await store.receive(.migrationProgressUpdated(1.0)) {
              $0.migrationState = .migrating(progress: 1.0)
          }
          await store.receive(.migrationCompleted) {
              $0.migrationState = .completed
              $0.isSyncEnabled = true
          }
      }

      @Test("enableSyncTapped shows failure on error")
      func enableSyncFails() async {
          struct SyncError: Error, LocalizedError {
              var errorDescription: String? { "iCloud not available" }
          }
          let store = await TestStore(
              initialState: SyncSettingsFeature.State(isSubscribed: true)
          ) {
              SyncSettingsFeature()
          } withDependencies: {
              $0.syncClient.enableSync = {
                  AsyncThrowingStream { continuation in
                      continuation.finish(throwing: SyncError())
                  }
              }
              $0.userSettingsClient.bool = { _ in false }
          }
          await store.send(.enableSyncTapped) {
              $0.migrationState = .migrating(progress: 0)
          }
          await store.receive(.migrationFailed("iCloud not available")) {
              $0.migrationState = .failed("iCloud not available")
          }
      }
  }
  ```

- [ ] **Step 2: Run tests to confirm they fail (SyncSettingsFeature not defined yet)**

  ```bash
  xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing:FeaturesTests/SyncSettingsFeatureTests \
    | grep -E "error:|failed"
  ```

  Expected: compile error — `SyncSettingsFeature` not found.

- [ ] **Step 3: Create the Reducer**

  ```swift
  // Features/Sources/Features/Settings/SyncSettings/SyncSettingsFeature.swift
  import ComposableArchitecture
  import Domain
  import Foundation

  @Reducer
  public struct SyncSettingsFeature {
      @ObservableState
      public struct State: Equatable {
          public var isSubscribed: Bool = false
          public var isSyncEnabled: Bool = false
          public var isCloudKitAvailable: Bool = true
          public var migrationState: MigrationState = .idle
          public var lastSyncDate: Date? = nil

          public enum MigrationState: Equatable {
              case idle
              case migrating(progress: Double)
              case completed
              case failed(String)
          }

          public init(
              isSubscribed: Bool = false,
              isSyncEnabled: Bool = false,
              isCloudKitAvailable: Bool = true,
              migrationState: MigrationState = .idle,
              lastSyncDate: Date? = nil
          ) {
              self.isSubscribed = isSubscribed
              self.isSyncEnabled = isSyncEnabled
              self.isCloudKitAvailable = isCloudKitAvailable
              self.migrationState = migrationState
              self.lastSyncDate = lastSyncDate
          }
      }

      public enum Action {
          case task
          case enableSyncTapped
          case subscribeNowTapped
          case migrationProgressUpdated(Double)
          case migrationCompleted
          case migrationFailed(String)
      }

      @Dependency(\.syncClient) var syncClient
      @Dependency(\.userSettingsClient) var userSettingsClient

      public init() {}

      public var body: some ReducerOf<Self> {
          Reduce { state, action in
              switch action {
              case .task:
                  state.isSubscribed = userSettingsClient.bool(.isSubscribed)
                  state.isSyncEnabled = userSettingsClient.bool(.isSyncEnabled)
                  state.isCloudKitAvailable = syncClient.isCloudKitAvailable()
                  return .none

              case .subscribeNowTapped:
                  state.isSubscribed = true
                  userSettingsClient.setBool(true, .isSubscribed)
                  return .none

              case .enableSyncTapped:
                  state.migrationState = .migrating(progress: 0)
                  return .run { send in
                      for try await progress in syncClient.enableSync() {
                          await send(.migrationProgressUpdated(progress))
                      }
                      await send(.migrationCompleted)
                  } catch: { error, send in
                      await send(.migrationFailed(error.localizedDescription))
                  }

              case .migrationProgressUpdated(let progress):
                  state.migrationState = .migrating(progress: progress)
                  return .none

              case .migrationCompleted:
                  state.migrationState = .completed
                  state.isSyncEnabled = true
                  state.lastSyncDate = Date()
                  return .none

              case .migrationFailed(let message):
                  state.migrationState = .failed(message)
                  return .none
              }
          }
      }
  }
  ```

- [ ] **Step 4: Run tests to confirm they pass**

  ```bash
  xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing:FeaturesTests/SyncSettingsFeatureTests \
    | grep -E "error:|Test Suite|passed|failed"
  ```

  Expected: `Test Suite 'SyncSettingsFeatureTests' passed`

- [ ] **Step 5: Commit**

  ```bash
  git add Features/Sources/Features/Settings/SyncSettings/SyncSettingsFeature.swift \
          Features/Tests/FeaturesTests/SyncSettingsFeatureTests.swift
  git commit -m "feat(features): add SyncSettingsFeature reducer with TDD tests"
  ```

---

## Task 7: SyncSettingsView

**Files:**
- Create: `Features/Sources/Features/Settings/SyncSettings/SyncSettingsView.swift`

- [ ] **Step 1: Create the view**

  ```swift
  // Features/Sources/Features/Settings/SyncSettings/SyncSettingsView.swift
  import ComposableArchitecture
  import SwiftUI

  struct SyncSettingsView: View {
      @Bindable var store: StoreOf<SyncSettingsFeature>

      var body: some View {
          Group {
              if store.isSubscribed {
                  subscribedContent
              } else {
                  upsellContent
              }
          }
          .navigationTitle(String(localized: "sync_title"))
          .navigationBarTitleDisplayMode(.large)
          .task { store.send(.task) }
      }

      // MARK: - Upsell (not subscribed)

      private var upsellContent: some View {
          ScrollView {
              VStack(spacing: 32) {
                  Image(systemName: "icloud.and.arrow.up")
                      .font(.system(size: 64))
                      .symbolRenderingMode(.hierarchical)
                      .foregroundStyle(Color.accentColor)
                      .padding(.top, 48)

                  VStack(spacing: 12) {
                      Text(String(localized: "sync_upsell_headline"))
                          .font(Font.Design.title2)
                          .fontWeight(.bold)
                          .multilineTextAlignment(.center)

                      VStack(alignment: .leading, spacing: 8) {
                          Label(String(localized: "sync_upsell_feature_devices"), systemImage: "iphone.and.ipad")
                          Label(String(localized: "sync_upsell_feature_backup"), systemImage: "checkmark.shield")
                      }
                      .font(Font.Design.body)
                      .foregroundStyle(Color.secondary)
                  }

                  Button {
                      store.send(.subscribeNowTapped)
                  } label: {
                      Text(String(localized: "sync_subscribe_now"))
                          .frame(maxWidth: .infinity)
                          .padding(.vertical, 14)
                  }
                  .buttonStyle(.glassProminent)
                  .padding(.horizontal, 24)

                  Spacer()
              }
              .padding()
          }
      }

      // MARK: - Subscribed content

      @ViewBuilder
      private var subscribedContent: some View {
          Form {
              if !store.isCloudKitAvailable {
                  Section {
                      Label(
                          String(localized: "sync_icloud_unavailable"),
                          systemImage: "exclamationmark.icloud"
                      )
                      .foregroundStyle(Color.Design.expenseRed)
                  }
              }

              Section {
                  switch store.migrationState {
                  case .idle where !store.isSyncEnabled:
                      Button {
                          store.send(.enableSyncTapped)
                      } label: {
                          Label(
                              String(localized: "sync_enable_button"),
                              systemImage: "icloud.and.arrow.up"
                          )
                      }
                      .disabled(!store.isCloudKitAvailable)

                  case .migrating(let progress):
                      VStack(alignment: .leading, spacing: 8) {
                          Text(String(localized: "sync_migrating"))
                              .font(Font.Design.subheadline)
                          ProgressView(value: progress)
                          Text("\(Int(progress * 100))%")
                              .font(Font.Design.caption)
                              .foregroundStyle(Color.secondary)
                      }
                      .padding(.vertical, 4)

                  case .completed, .idle:
                      Label(
                          String(localized: "sync_enabled_label"),
                          systemImage: "checkmark.icloud.fill"
                      )
                      .foregroundStyle(Color.Design.incomeGreen)

                  case .failed(let message):
                      VStack(alignment: .leading, spacing: 4) {
                          Label(String(localized: "sync_failed"), systemImage: "xmark.icloud")
                              .foregroundStyle(Color.Design.expenseRed)
                          Text(message)
                              .font(Font.Design.caption)
                              .foregroundStyle(Color.secondary)
                          Button(String(localized: "sync_retry")) {
                              store.send(.enableSyncTapped)
                          }
                          .font(Font.Design.caption)
                      }
                  }
              } header: {
                  Text(String(localized: "sync_title"))
              }

              if store.isSyncEnabled {
                  Section {
                      Label(String(localized: "sync_icloud_account_active"), systemImage: "person.icloud")
                  } header: {
                      Text(String(localized: "sync_account_section_header"))
                  }
              }
          }
      }
  }
  ```

- [ ] **Step 2: Build to confirm no errors**

  ```bash
  xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    | grep -E "error:|Build succeeded"
  ```

  Expected: `Build succeeded`

- [ ] **Step 3: Commit**

  ```bash
  git add Features/Sources/Features/Settings/SyncSettings/SyncSettingsView.swift
  git commit -m "feat(features): add SyncSettingsView with upsell and subscribed states"
  ```

---

## Task 8: Settings integration + localization

**Files:**
- Modify: `Features/Sources/Features/Settings/SettingsFeature.swift`
- Modify: `Features/Sources/Features/Settings/SettingsView.swift`
- Modify: project Localizable.strings / .xcstrings file (find path by searching for an existing key like "settings_sync" or "accessory_add")

- [ ] **Step 1: Add syncSettings to SettingsFeature.Destination**

  In `SettingsFeature.swift`, locate the `Destination` enum and add:

  ```swift
  @Reducer(state: .equatable, action: .equatable)
  public enum Destination {
      case accountManagement(AccountManagementFeature)
      case categoryManagement(CategoryManagementFeature)
      case budgetManagement(BudgetManagementFeature)
      case tagManagement(TagManagementFeature)
      case notificationSettings(NotificationSettingsFeature)
      case syncSettings(SyncSettingsFeature)           // ADD THIS
  }
  ```

- [ ] **Step 2: Add syncSettingsTapped action and reducer case**

  In `SettingsFeature.Action`, add:

  ```swift
  case syncSettingsTapped
  ```

  In the Reducer `body`, alongside the other `Tapped` cases, add:

  ```swift
  case .syncSettingsTapped:
      state.path.append(.syncSettings(SyncSettingsFeature.State()))
      return .none
  ```

- [ ] **Step 3: Add Sync row to SettingsView**

  In `SettingsView.swift`, find `sectionManage` and add a row after `notificationSettings`:

  ```swift
  settingsRow(
      icon: "icloud.and.arrow.up",
      title: String(localized: "settings_sync")
  ) {
      chevron
  } action: {
      store.send(.syncSettingsTapped)
  }
  ```

  Also add `.syncSettings` to the `NavigationStack`'s `navigationDestination` — follow the existing pattern used for `notificationSettings`:

  ```swift
  .navigationDestination(for: SettingsFeature.Destination.State.self) { state in
      // existing cases...
      // ADD:
      case .syncSettings(let syncState):
          SyncSettingsView(store: store.scope(
              state: \.path[id: ...],  // follow existing pattern exactly
              action: \.path
          ))
  }
  ```

  > Note: Follow the exact `NavigationStack` + `Store.scope` pattern already used for `notificationSettings` in the file — copy that pattern verbatim.

- [ ] **Step 4: Add localization strings**

  Find the Localizable.strings or .xcstrings file by running:

  ```bash
  find . -name "*.xcstrings" -o -name "Localizable.strings" | grep -v ".build" | grep -v "DerivedData"
  ```

  Add these keys (English values — add Traditional Chinese translations as a second step following the existing pattern in the file):

  ```
  "settings_sync" = "iCloud Sync";
  "sync_title" = "iCloud Sync";
  "sync_upsell_headline" = "Sync Across All Your Devices";
  "sync_upsell_feature_devices" = "Access your ledger on iPhone and iPad";
  "sync_upsell_feature_backup" = "Your data is safe in iCloud";
  "sync_subscribe_now" = "Subscribe Now";
  "sync_enable_button" = "Enable iCloud Sync";
  "sync_enabled_label" = "iCloud Sync Enabled";
  "sync_migrating" = "Migrating data to iCloud…";
  "sync_failed" = "Sync Failed";
  "sync_retry" = "Retry";
  "sync_icloud_unavailable" = "Sign in to iCloud in Settings to enable sync";
  "sync_icloud_account_active" = "Connected to iCloud";
  "sync_account_section_header" = "Account";
  ```

- [ ] **Step 5: Build and run all tests**

  ```bash
  xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    | grep -E "error:|Test Suite|passed|failed"
  ```

  Expected: All tests pass.

- [ ] **Step 6: Commit**

  ```bash
  git add Features/Sources/Features/Settings/SettingsFeature.swift \
          Features/Sources/Features/Settings/SettingsView.swift
  git add -u  # pick up any localization file changes
  git commit -m "feat(features): integrate SyncSettings into Settings navigation and add localization keys"
  ```

---

## Task 9: App entitlements — iCloud + CloudKit (Manual Xcode step)

This task cannot be automated via code. It requires clicking in Xcode.

- [ ] **Step 1: Add iCloud capability in Xcode**

  1. Open `NeuLedger.xcodeproj` in Xcode
  2. Select the `NeuLedger` target → **Signing & Capabilities** tab
  3. Click **+ Capability** → add **iCloud**
  4. Under iCloud, tick **CloudKit**
  5. Under Containers, click **+** and create a new container named `iCloud.com.yourcompany.NeuLedger` (replace with your actual bundle ID prefix)

- [ ] **Step 2: Update the container identifier in SyncClient+Live**

  Open `Features/Sources/Core/Clients/SyncClient+Live.swift` and replace `iCloud.com.yourcompany.NeuLedger` with the actual container identifier you just created.

- [ ] **Step 3: Verify entitlements file was updated**

  ```bash
  cat NeuLedger/NeuLedger.entitlements 2>/dev/null || cat NeuLedger.entitlements 2>/dev/null
  ```

  Expected output includes:
  ```xml
  <key>com.apple.developer.icloud-container-identifiers</key>
  <array>
      <string>iCloud.com.yourcompany.NeuLedger</string>
  </array>
  <key>com.apple.developer.icloud-services</key>
  <array>
      <string>CloudKit</string>
  </array>
  ```

- [ ] **Step 4: Build to confirm entitlements work**

  ```bash
  xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    | grep -E "error:|Build succeeded"
  ```

  Expected: `Build succeeded`

- [ ] **Step 5: Commit**

  ```bash
  git add NeuLedger.entitlements 2>/dev/null || git add NeuLedger/NeuLedger.entitlements
  git add Features/Sources/Core/Clients/SyncClient+Live.swift
  git commit -m "feat(app): add iCloud and CloudKit entitlements, set CloudKit container identifier"
  ```

---

## End-to-End Manual Test Checklist

After all tasks complete, verify on Simulator:

1. Open Settings → confirm "iCloud Sync" row appears
2. Tap row → confirm upsell page shows (not subscribed)
3. Tap "Subscribe Now" → confirm page switches to "Enable iCloud Sync"
4. Tap "Enable iCloud Sync" → confirm progress bar animates and "Enabled" label appears
5. Force-quit and relaunch → confirm "Sync Enabled" state persists
6. Confirm existing transaction data is still visible after enabling sync

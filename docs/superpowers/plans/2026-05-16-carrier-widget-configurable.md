# Carrier Widget Configurable — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make CarrierWidget user-configurable so each widget instance binds to a specific carrier via the system "Edit Widget" sheet (long-press menu), with a graceful "deleted" state when the bound carrier no longer exists.

**Architecture:** Switch from `StaticConfiguration` to `AppIntentConfiguration` with a `CarrierSelectionIntent`. Sync the full carrier list to the App Group as JSON; the widget reads it on each timeline refresh, matches against the intent's selected carrier ID, and renders one of three states (`loaded` / `empty` / `deleted`).

**Tech Stack:** WidgetKit · AppIntents · TCA · SwiftData · App Group UserDefaults · Swift Testing

**Spec:** `docs/superpowers/specs/2026-05-16-carrier-widget-configurable-design.md`

---

## File Structure

| File | Responsibility |
|------|----------------|
| `Shared/WidgetAppGroup.swift` | App Group I/O: `CarrierEntry` (now with `id`, `Codable`) + `readAllCarriers` / `writeAllCarriers` |
| `Features/Sources/Domain/Clients/WidgetSyncClient.swift` | Protocol: add `syncAllCarriers` closure |
| `Features/Sources/Core/Clients/WidgetSyncClient+Live.swift` | Live impl: encode `[Carrier]` → JSON → App Group + reload timelines |
| `Features/Sources/Features/CarrierManagement/CarrierManagementFeature.swift` | Call `syncAllCarriers` after task / add / edit / delete |
| `Features/Sources/Features/CarrierManagement/CarrierManagementView.swift` | Cell subtitle: show `carrier.barcode` instead of fixed type label |
| `NeuLedgerWidget/CarrierAppEntity.swift` | NEW: `CarrierAppEntity`, `CarrierEntityQuery`, `CarrierSelectionIntent` |
| `NeuLedgerWidget/CarrierWidget.swift` | Migrate to `AppIntentConfiguration`, replace single carrier entry with state enum, add `.deleted` view branch |
| `Features/Tests/FeaturesTests/CarrierManagementFeatureTests.swift` | Tests for new sync behaviour |

---

## Task 1: Extend `CarrierEntry` + App Group list I/O

**Files:**
- Modify: `Shared/WidgetAppGroup.swift`

- [ ] **Step 1: Replace `CarrierEntry` and add list I/O**

Open `Shared/WidgetAppGroup.swift` and replace the entire file with:

```swift
// Shared/WidgetAppGroup.swift
import Foundation

/// Shared App Group helper for reading and writing widget configuration
/// between the main app and the Widget Extension.
///
/// The main app is the sole writer; the Widget Extension is read-only.
enum WidgetAppGroup {
    static let suiteName = "group.com.drakehuang.NeuLedger"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    // MARK: - Keys

    private enum Key: String {
        // Legacy single-carrier keys (kept for backward compat during transition)
        case carrierBarcode
        case carrierType
        case carrierName
        case carrierUpdatedAt
        // New list key (JSON-encoded [CarrierEntry])
        case carrierList
    }

    // MARK: - Legacy single-carrier read (kept for compat)

    /// Reads the legacy single carrier configuration from App Group.
    /// Returns `nil` if no carrier is configured or data is inconsistent.
    static func readCarrier() -> CarrierEntry? {
        guard let defaults,
              let barcode = defaults.string(forKey: Key.carrierBarcode.rawValue),
              !barcode.isEmpty,
              let typeRaw = defaults.string(forKey: Key.carrierType.rawValue),
              !typeRaw.isEmpty else {
            return nil
        }
        let name = defaults.string(forKey: Key.carrierName.rawValue) ?? ""
        let updatedAt = defaults.object(forKey: Key.carrierUpdatedAt.rawValue) as? Date
        // Legacy entry has no ID — use a deterministic placeholder so callers can
        // still identify it; new code should prefer readAllCarriers().
        return CarrierEntry(
            id: "legacy",
            barcode: barcode,
            typeRawValue: typeRaw,
            name: name,
            updatedAt: updatedAt
        )
    }

    // MARK: - Legacy single-carrier write (main app only)

    /// Writes legacy single carrier configuration to App Group.
    static func writeCarrier(barcode: String, type: String, name: String) {
        guard let defaults else { return }
        defaults.set(barcode, forKey: Key.carrierBarcode.rawValue)
        defaults.set(type, forKey: Key.carrierType.rawValue)
        defaults.set(name, forKey: Key.carrierName.rawValue)
        defaults.set(Date(), forKey: Key.carrierUpdatedAt.rawValue)
    }

    /// Clears legacy single carrier data from App Group.
    static func clearCarrier() {
        guard let defaults else { return }
        for key in [Key.carrierBarcode, .carrierType, .carrierName, .carrierUpdatedAt] {
            defaults.removeObject(forKey: key.rawValue)
        }
    }

    // MARK: - Full carrier list I/O (new)

    /// Reads all carriers from the App Group. Returns an empty array on missing/corrupt data.
    static func readAllCarriers() -> [CarrierEntry] {
        guard let defaults,
              let data = defaults.data(forKey: Key.carrierList.rawValue) else {
            return []
        }
        return (try? JSONDecoder().decode([CarrierEntry].self, from: data)) ?? []
    }

    /// Writes all carriers to the App Group. Main app only.
    static func writeAllCarriers(_ carriers: [CarrierEntry]) {
        guard let defaults else { return }
        guard let data = try? JSONEncoder().encode(carriers) else { return }
        defaults.set(data, forKey: Key.carrierList.rawValue)
    }
}

// MARK: - CarrierEntry

/// A lightweight value type representing carrier data read from App Group.
/// Used by the Widget Extension — no dependency on Domain layer.
struct CarrierEntry: Codable, Hashable {
    let id: String              // UUID string (or "legacy" for migration entries)
    let barcode: String
    let typeRawValue: String    // "phoneBarcodeCarrier" or "citizenDigitalCertificate"
    let name: String
    let updatedAt: Date?

    var typeDisplayName: String {
        switch typeRawValue {
        case "phoneBarcodeCarrier":
            return String(localized: "carrier_type_phone_barcode")
        case "citizenDigitalCertificate":
            return String(localized: "carrier_type_citizen_cert")
        default:
            return typeRawValue
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5`
Expected: exit code 0 (build success). Existing callers of `readCarrier` / `writeCarrier` keep working because the legacy API is preserved.

- [ ] **Step 3: Commit**

```bash
git add Shared/WidgetAppGroup.swift
git commit -m "feat(widget): add CarrierEntry.id and full-list App Group I/O

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 2: Add `syncAllCarriers` to WidgetSyncClient (Domain)

**Files:**
- Modify: `Features/Sources/Domain/Clients/WidgetSyncClient.swift`

- [ ] **Step 1: Add the new closure property**

Open `Features/Sources/Domain/Clients/WidgetSyncClient.swift` and replace the existing struct with:

```swift
import Foundation
import Dependencies
import DependenciesMacros

/// A client interface for synchronising carrier data to the Widget Extension
/// via the App Group container and requesting a WidgetKit timeline reload.
///
/// The Features layer must **never** import `WidgetKit` or access `UserDefaults(suiteName:)`
/// directly. All widget sync operations go through this client.
@DependencyClient
public struct WidgetSyncClient: Sendable {
    /// Writes carrier data to the shared App Group container and triggers a
    /// WidgetKit timeline reload so the `CarrierWidget` reflects the latest carrier.
    public var syncCarrier: @Sendable (_ barcode: String, _ type: String, _ name: String) async -> Void

    /// Removes all carrier data from the shared App Group container and triggers
    /// a WidgetKit timeline reload so the `CarrierWidget` shows the empty state.
    public var clearCarrier: @Sendable () async -> Void

    /// Writes the full list of carriers to the App Group as JSON and triggers
    /// a CarrierWidget timeline reload. Called after every CRUD operation in
    /// `CarrierManagementFeature` so configurable widgets can resolve their
    /// bound carrier by ID.
    public var syncAllCarriers: @Sendable (_ carriers: [Carrier]) async -> Void
}

extension WidgetSyncClient: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var widgetSyncClient: WidgetSyncClient {
        get { self[WidgetSyncClient.self] }
        set { self[WidgetSyncClient.self] = newValue }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5`
Expected: exit code 0. (Live impl will be missing the new key path — `@DependencyClient` generates a default unimplemented closure, so the build succeeds.)

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Domain/Clients/WidgetSyncClient.swift
git commit -m "feat(widget-sync): add syncAllCarriers domain interface

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 3: Implement `syncAllCarriers` (Core/Live)

**Files:**
- Modify: `Features/Sources/Core/Clients/WidgetSyncClient+Live.swift`

- [ ] **Step 1: Add the live implementation**

Replace the entire file with:

```swift
/// NOTE: Suite name and keys MUST stay in sync with Shared/WidgetAppGroup.swift,
/// which is the Widget-side reader (outside Features SPM package).
import Foundation
import WidgetKit
import Dependencies
import Domain

extension WidgetSyncClient: DependencyKey {
    // MARK: - App Group constants
    //
    // Keep in sync with Shared/WidgetAppGroup.swift:
    //   static let suiteName = "group.com.drakehuang.NeuLedger"
    //   enum Key: String { case carrierBarcode, carrierType, carrierName, carrierUpdatedAt, carrierList }
    //
    // Widget kind keeps in sync with NeuLedgerWidget/CarrierWidget.swift:
    //   let kind: String = "CarrierWidget"

    private static let appGroupSuiteName = "group.com.drakehuang.NeuLedger"
    private static let keyBarcode        = "carrierBarcode"
    private static let keyType           = "carrierType"
    private static let keyName           = "carrierName"
    private static let keyUpdatedAt      = "carrierUpdatedAt"
    private static let keyList           = "carrierList"
    private static let widgetKind        = "CarrierWidget"

    public static let liveValue = Self(
        syncCarrier: { barcode, type, name in
            guard let defaults = UserDefaults(suiteName: appGroupSuiteName) else { return }
            defaults.set(barcode, forKey: keyBarcode)
            defaults.set(type,    forKey: keyType)
            defaults.set(name,    forKey: keyName)
            defaults.set(Date(),  forKey: keyUpdatedAt)
            await WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        },
        clearCarrier: {
            guard let defaults = UserDefaults(suiteName: appGroupSuiteName) else { return }
            for key in [keyBarcode, keyType, keyName, keyUpdatedAt] {
                defaults.removeObject(forKey: key)
            }
            await WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        },
        syncAllCarriers: { carriers in
            guard let defaults = UserDefaults(suiteName: appGroupSuiteName) else { return }
            // Mirror Shared/WidgetAppGroup.CarrierEntry — Core cannot import Shared/.
            struct CarrierEntryDTO: Codable {
                let id: String
                let barcode: String
                let typeRawValue: String
                let name: String
                let updatedAt: Date?
            }
            let dtos = carriers.map {
                CarrierEntryDTO(
                    id: $0.id.uuidString,
                    barcode: $0.barcode,
                    typeRawValue: $0.type.rawValue,
                    name: $0.name,
                    updatedAt: Date()
                )
            }
            guard let data = try? JSONEncoder().encode(dtos) else { return }
            defaults.set(data, forKey: keyList)
            await WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        }
    )
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5`
Expected: exit code 0.

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Core/Clients/WidgetSyncClient+Live.swift
git commit -m "feat(widget-sync): implement syncAllCarriers live impl

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 4: Wire `syncAllCarriers` into CarrierManagementFeature (TDD)

**Files:**
- Modify: `Features/Sources/Features/CarrierManagement/CarrierManagementFeature.swift`
- Test:   `Features/Tests/FeaturesTests/CarrierManagementFeatureTests.swift`

- [ ] **Step 1: Write the failing test**

Append the following test inside `@Suite("CarrierManagementFeature Tests")` (after the existing tests, before the closing `}` of the suite):

```swift
@Test("task triggers syncAllCarriers with fetched list")
func testTaskTriggersSyncAllCarriers() async {
    let sample = Carrier(
        id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
        name: "Phone Carrier",
        type: .phoneBarcodeCarrier,
        barcode: "/ABC1234",
        createdAt: Date(timeIntervalSince1970: 0)
    )
    let syncedCarriers = LockIsolated<[Carrier]?>(nil)
    let store = await TestStore(
        initialState: CarrierManagementFeature.State()
    ) {
        CarrierManagementFeature()
    } withDependencies: {
        $0.carrierClient.fetchAll = { [sample] }
        $0.widgetSyncClient.syncAllCarriers = { carriers in
            syncedCarriers.setValue(carriers)
        }
    }

    await store.send(.task) {
        $0.isLoading = true
    }
    await store.receive(\.carriersLoaded) {
        $0.isLoading = false
        $0.carriers = [sample]
    }
    #expect(syncedCarriers.value == [sample])
}

@Test("deleteTapped triggers syncAllCarriers with refreshed list")
func testDeleteTappedTriggersSyncAllCarriers() async {
    let remaining = Carrier(
        id: UUID(uuidString: "40000000-0000-0000-0000-000000000002")!,
        name: "Cert Carrier",
        type: .citizenDigitalCertificate,
        barcode: "/PA1B2C3D4E5F6G7H8",
        createdAt: Date(timeIntervalSince1970: 0)
    )
    let deletedId = UUID(uuidString: "40000000-0000-0000-0000-000000000003")!
    let syncedCarriers = LockIsolated<[Carrier]?>(nil)
    let store = await TestStore(
        initialState: CarrierManagementFeature.State()
    ) {
        CarrierManagementFeature()
    } withDependencies: {
        $0.carrierClient.delete = { _ in }
        $0.carrierClient.fetchAll = { [remaining] }
        $0.userSettingsClient.string = { _ in "" }
        $0.widgetSyncClient.syncAllCarriers = { carriers in
            syncedCarriers.setValue(carriers)
        }
    }

    await store.send(.deleteTapped(deletedId))
    await store.receive(\.carriersLoaded) {
        $0.carriers = [remaining]
    }
    #expect(syncedCarriers.value == [remaining])
}

@Test("save delegate triggers syncAllCarriers with refreshed list")
func testSaveDelegateTriggersSyncAllCarriers() async {
    let saved = Carrier(
        id: UUID(uuidString: "40000000-0000-0000-0000-000000000004")!,
        name: "New",
        type: .phoneBarcodeCarrier,
        barcode: "/ZZZ9999",
        createdAt: Date(timeIntervalSince1970: 0)
    )
    let syncedCarriers = LockIsolated<[Carrier]?>(nil)
    var initial = CarrierManagementFeature.State()
    initial.addEdit = AddEditCarrierFeature.State(mode: .add)
    let store = await TestStore(initialState: initial) {
        CarrierManagementFeature()
    } withDependencies: {
        $0.carrierClient.fetchAll = { [saved] }
        $0.userSettingsClient.string = { _ in "" }
        $0.userSettingsClient.setString = { _, _ in }
        $0.widgetSyncClient.syncCarrier = { _, _, _ in }
        $0.widgetSyncClient.syncAllCarriers = { carriers in
            syncedCarriers.setValue(carriers)
        }
    }

    await store.send(\.addEdit.presented.delegate.saved) {
        $0.addEdit = nil
    }
    await store.receive(\.carriersLoaded) {
        $0.carriers = [saved]
    }
    #expect(syncedCarriers.value == [saved])
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FeaturesTests/CarrierManagementFeatureTests 2>&1 | tail -30`

Expected: 3 failures with "unimplemented: WidgetSyncClient.syncAllCarriers" or similar. The new tests fail because the reducer doesn't call `syncAllCarriers` yet.

- [ ] **Step 3: Wire `syncAllCarriers` into the reducer**

Modify the three call sites in `Features/Sources/Features/CarrierManagement/CarrierManagementFeature.swift`:

(a) `.task` case — replace the existing `.run` block with:
```swift
case .task:
    state.isLoading = true
    return .run { [widgetSyncClient] send in
        let carriers = try await carrierClient.fetchAll()
        await widgetSyncClient.syncAllCarriers(carriers)
        await send(.carriersLoaded(carriers))
    }
    .cancellable(id: CancelID.task)
```

(b) `.deleteTapped(id)` case — replace the existing `.run` block with:
```swift
case let .deleteTapped(id):
    state.expandedCarrierId = nil
    return .run { [userSettingsClient, widgetSyncClient] send in
        try await carrierClient.delete(id)
        let carriers = try await carrierClient.fetchAll()
        // If the deleted carrier was the active widget carrier, clear App Group
        let widgetCarrierId = userSettingsClient.string(.widgetCarrierId)
        if widgetCarrierId == id.uuidString {
            userSettingsClient.setString("", .widgetCarrierId)
            await widgetSyncClient.clearCarrier()
        }
        await widgetSyncClient.syncAllCarriers(carriers)
        await send(.carriersLoaded(carriers))
    } catch: { _, send in
        let carriers = (try? await carrierClient.fetchAll()) ?? []
        await send(.carriersLoaded(carriers))
    }
```

(c) `.addEdit(.presented(.delegate(.saved)))` case — replace the existing `.run` block with:
```swift
case .addEdit(.presented(.delegate(.saved))):
    state.addEdit = nil
    return .run { [userSettingsClient, widgetSyncClient] send in
        let carriers = try await carrierClient.fetchAll()
        let widgetCarrierId = userSettingsClient.string(.widgetCarrierId)

        if widgetCarrierId.isEmpty, let first = carriers.first {
            // P0: Auto-assign the first ever carrier as the widget carrier
            userSettingsClient.setString(first.id.uuidString, .widgetCarrierId)
            await widgetSyncClient.syncCarrier(
                first.barcode,
                first.type.rawValue,
                first.name
            )
        } else if !widgetCarrierId.isEmpty,
                  let carrier = carriers.first(where: {
                      $0.id.uuidString == widgetCarrierId
                  }) {
            // If the widget carrier was edited, update App Group
            await widgetSyncClient.syncCarrier(
                carrier.barcode,
                carrier.type.rawValue,
                carrier.name
            )
        }

        await widgetSyncClient.syncAllCarriers(carriers)
        await send(.carriersLoaded(carriers))
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FeaturesTests/CarrierManagementFeatureTests 2>&1 | tail -20`
Expected: all green (existing + 3 new tests pass).

- [ ] **Step 5: Run full Features test scheme for side-effect safety**

Run: `xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Features/CarrierManagement/CarrierManagementFeature.swift Features/Tests/FeaturesTests/CarrierManagementFeatureTests.swift
git commit -m "feat(carrier): sync full carrier list to App Group on every CRUD

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 5: Side fix — CarrierManagement cell subtitle shows barcode

**Files:**
- Modify: `Features/Sources/Features/CarrierManagement/CarrierManagementView.swift`

- [ ] **Step 1: Change subtitle text**

In `Features/Sources/Features/CarrierManagement/CarrierManagementView.swift`, find the carrier row VStack (currently around line 146–153):

```swift
VStack(alignment: .leading, spacing: 2) {
    Text(carrier.name)
        .font(Font.Design.body.weight(.semibold))
        .foregroundStyle(Color.Design.textPrimary)
    Text(carrier.type.defaultName)
        .font(.system(size: 12))
        .foregroundStyle(Color.Design.textSecondary)
}
```

Replace with:

```swift
VStack(alignment: .leading, spacing: 2) {
    Text(carrier.name)
        .font(Font.Design.body.weight(.semibold))
        .foregroundStyle(Color.Design.textPrimary)
    Text(carrier.barcode)
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(Color.Design.textSecondary)
        .lineLimit(1)
        .truncationMode(.middle)
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5`
Expected: exit code 0.

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Features/CarrierManagement/CarrierManagementView.swift
git commit -m "refactor(carrier): cell subtitle shows raw barcode instead of type label

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 6: Add `CarrierAppEntity` + `CarrierSelectionIntent` (Widget Target)

**Files:**
- Create: `NeuLedgerWidget/CarrierAppEntity.swift`

- [ ] **Step 1: Create the new file**

Create `NeuLedgerWidget/CarrierAppEntity.swift` with:

```swift
// NeuLedgerWidget/CarrierAppEntity.swift
import AppIntents
import Foundation

// MARK: - CarrierAppEntity

/// An `AppEntity` wrapper around a `CarrierEntry` so that
/// `CarrierSelectionIntent` can offer a system-native picker
/// in the widget's Edit sheet.
struct CarrierAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "carrier_entity_type_name")
    }

    static var defaultQuery = CarrierEntityQuery()

    let id: String
    let name: String
    let typeDisplayName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(typeDisplayName)"
        )
    }
}

// MARK: - CarrierEntityQuery

/// Provides `CarrierAppEntity` instances to the AppIntents framework so the
/// system can render the carrier picker and resolve previously-selected entities.
struct CarrierEntityQuery: EntityQuery {
    /// Resolve specific entities by ID (used when the system reads back the
    /// previously selected carrier on each widget render).
    func entities(for identifiers: [CarrierAppEntity.ID]) async throws -> [CarrierAppEntity] {
        let all = WidgetAppGroup.readAllCarriers()
        let lookup = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        return identifiers.compactMap { id in
            guard let entry = lookup[id] else { return nil }
            return CarrierAppEntity(
                id: entry.id,
                name: entry.name,
                typeDisplayName: entry.typeDisplayName
            )
        }
    }

    /// Suggested entities shown in the picker.
    func suggestedEntities() async throws -> [CarrierAppEntity] {
        WidgetAppGroup.readAllCarriers().map { entry in
            CarrierAppEntity(
                id: entry.id,
                name: entry.name,
                typeDisplayName: entry.typeDisplayName
            )
        }
    }
}

// MARK: - CarrierSelectionIntent

/// The configurable intent that drives `CarrierWidget`.
/// User long-presses the widget → "Edit Widget" → picks a carrier.
struct CarrierSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "carrier_intent_title"
    static var description = IntentDescription("carrier_intent_description")

    @Parameter(title: "carrier_intent_parameter_title")
    var carrier: CarrierAppEntity?

    init() {}

    init(carrier: CarrierAppEntity?) {
        self.carrier = carrier
    }
}
```

- [ ] **Step 2: Add the localization keys**

Open `NeuLedgerWidget/Localizable.xcstrings` and add these 4 new keys inside `"strings": { ... }` (alphabetical order). The file already follows this format — append/insert as needed:

```json
"carrier_entity_type_name" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Carrier"
      }
    },
    "zh-Hant" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "載具"
      }
    }
  }
},
"carrier_intent_description" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Choose which carrier this widget displays."
      }
    },
    "zh-Hant" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "選擇此 Widget 要顯示的載具"
      }
    }
  }
},
"carrier_intent_parameter_title" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Carrier"
      }
    },
    "zh-Hant" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "載具"
      }
    }
  }
},
"carrier_intent_title" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Choose Carrier"
      }
    },
    "zh-Hant" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "選擇載具"
      }
    }
  }
}
```

- [ ] **Step 3: Add the file to the NeuLedgerWidget Xcode target**

In Xcode:
1. Right-click the `NeuLedgerWidget` group in Project Navigator → "Add Files to NeuLedger…"
2. Select `NeuLedgerWidget/CarrierAppEntity.swift`
3. In the dialog, ensure ONLY `NeuLedgerWidget` is checked under "Add to targets"
4. Click "Add"

> If the engineer prefers, they can also drag the file from Finder into the `NeuLedgerWidget` group and verify target membership in the File Inspector.

- [ ] **Step 4: Build to verify**

Run: `xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5`
Expected: exit code 0. (`AppIntents` framework is available on iOS 17+; this project targets iOS 26.)

- [ ] **Step 5: Commit**

```bash
git add NeuLedgerWidget/CarrierAppEntity.swift NeuLedgerWidget/Localizable.xcstrings NeuLedger.xcodeproj
git commit -m "feat(widget): add CarrierAppEntity and CarrierSelectionIntent

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 7: Migrate `CarrierWidget` to `AppIntentConfiguration` + 3-state machine

**Files:**
- Modify: `NeuLedgerWidget/CarrierWidget.swift`
- Modify: `NeuLedgerWidget/Localizable.xcstrings`

- [ ] **Step 1: Add localization keys for the `.deleted` state**

Open `NeuLedgerWidget/Localizable.xcstrings` and add:

```json
"widget_carrier_deleted_body" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "“%@” has been removed."
      }
    },
    "zh-Hant" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "「%@」已從 app 移除"
      }
    }
  }
},
"widget_carrier_deleted_cta" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Reconfigure"
      }
    },
    "zh-Hant" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "重新設定"
      }
    }
  }
}
```

- [ ] **Step 2: Rewrite `CarrierWidget.swift`**

Replace the entire file `NeuLedgerWidget/CarrierWidget.swift` with:

```swift
// NeuLedgerWidget/CarrierWidget.swift

import WidgetKit
import SwiftUI
import UIKit
import AppIntents
import CoreImage.CIFilterBuiltins

// MARK: - Widget State

enum CarrierWidgetState: Equatable {
    case loaded(CarrierEntry)
    case empty
    case deleted(name: String)
}

// MARK: - Timeline Entry

struct CarrierTimelineEntry: TimelineEntry {
    let date: Date
    let state: CarrierWidgetState
}

// MARK: - Timeline Provider

struct CarrierTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = CarrierTimelineEntry
    typealias Intent = CarrierSelectionIntent

    func placeholder(in context: Context) -> CarrierTimelineEntry {
        CarrierTimelineEntry(
            date: Date(),
            state: .loaded(CarrierEntry(
                id: "placeholder",
                barcode: "/ABC-12345678",
                typeRawValue: "phoneBarcodeCarrier",
                name: String(localized: "widget_carrier_placeholder_name"),
                updatedAt: nil
            ))
        )
    }

    func snapshot(for configuration: CarrierSelectionIntent, in context: Context) async -> CarrierTimelineEntry {
        CarrierTimelineEntry(date: Date(), state: resolveState(for: configuration))
    }

    func timeline(for configuration: CarrierSelectionIntent, in context: Context) async -> Timeline<CarrierTimelineEntry> {
        let entry = CarrierTimelineEntry(date: Date(), state: resolveState(for: configuration))
        return Timeline(entries: [entry], policy: .never)
    }

    private func resolveState(for configuration: CarrierSelectionIntent) -> CarrierWidgetState {
        guard let selected = configuration.carrier else {
            // No selection yet → empty state (also covers fresh installs)
            return .empty
        }
        let all = WidgetAppGroup.readAllCarriers()
        if let match = all.first(where: { $0.id == selected.id }) {
            return .loaded(match)
        }
        return .deleted(name: selected.name)
    }
}

// MARK: - Barcode Generation

private func generateBarcode(from string: String) -> UIImage? {
    let filter = CIFilter.code128BarcodeGenerator()
    guard let data = string.data(using: .ascii) else { return nil }
    filter.message = data
    filter.quietSpace = 10

    guard let outputImage = filter.outputImage else { return nil }

    let scaled = outputImage.transformed(
        by: CGAffineTransform(scaleX: 3.0, y: 1.5)
    )

    let context = CIContext()
    guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
    return UIImage(cgImage: cgImage)
}

// MARK: - Widget View

struct CarrierWidgetView: View {
    @Environment(\.redactionReasons) private var redactionReasons

    let entry: CarrierTimelineEntry

    private static let staleThreshold: TimeInterval = 90 * 24 * 60 * 60

    private var isPlaceholder: Bool {
        redactionReasons.contains(.placeholder)
    }

    var body: some View {
        Group {
            switch entry.state {
            case let .loaded(carrier):
                carrierContent(carrier)
            case .empty:
                emptyState
            case let .deleted(name):
                deletedState(name: name)
            }
        }
        .widgetURL(URL(string: "neuledger://carrier-management"))
        .containerBackground(for: .widget) {
            Color(.systemGroupedBackground)
        }
    }

    // MARK: Carrier Content

    @ViewBuilder
    private func carrierContent(_ carrier: CarrierEntry) -> some View {
        let isStale: Bool = {
            guard let updatedAt = carrier.updatedAt else { return false }
            return Date().timeIntervalSince(updatedAt) > Self.staleThreshold
        }()

        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack(spacing: 8) {
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)

                Text(carrier.name)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if isStale {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange)
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityLabel(Text("widget_carrier_stale_warning"))
                }

                Text(carrier.typeDisplayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(.secondarySystemFill))
                    )
                    .lineLimit(1)
            }

            // Barcode area
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)

                if isPlaceholder {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .unredacted()
                } else if let barcodeImage = generateBarcode(from: carrier.barcode) {
                    Image(uiImage: barcodeImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 16)
                } else {
                    Text(carrier.barcode)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
        }
        .padding(12)
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "creditcard")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.orange)
                .symbolRenderingMode(.hierarchical)

            Text("widget_carrier_empty")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Link(destination: URL(string: "neuledger://carrier-management")!) {
                HStack(spacing: 4) {
                    Text("widget_carrier_empty_cta")
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.orange.opacity(0.15)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }

    // MARK: Deleted State

    private func deletedState(name: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.orange)
                .symbolRenderingMode(.hierarchical)

            Text(String(format: String(localized: "widget_carrier_deleted_body"), name))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Link(destination: URL(string: "neuledger://carrier-management")!) {
                HStack(spacing: 4) {
                    Text("widget_carrier_deleted_cta")
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.orange.opacity(0.15)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }
}

// MARK: - Widget Definition

struct CarrierWidget: Widget {
    let kind: String = "CarrierWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: CarrierSelectionIntent.self,
            provider: CarrierTimelineProvider()
        ) { entry in
            CarrierWidgetView(entry: entry)
        }
        .configurationDisplayName(Text("widget_carrier_display_name"))
        .description(Text("widget_carrier_description"))
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Previews

#Preview("Loaded", as: .systemMedium) {
    CarrierWidget()
} timeline: {
    CarrierTimelineEntry(
        date: .now,
        state: .loaded(CarrierEntry(
            id: "preview-1",
            barcode: "/ABC-12345678",
            typeRawValue: "phoneBarcodeCarrier",
            name: "手機條碼載具",
            updatedAt: .now
        ))
    )
}

#Preview("Empty", as: .systemMedium) {
    CarrierWidget()
} timeline: {
    CarrierTimelineEntry(date: .now, state: .empty)
}

#Preview("Deleted", as: .systemMedium) {
    CarrierWidget()
} timeline: {
    CarrierTimelineEntry(date: .now, state: .deleted(name: "我的舊載具"))
}

#Preview("Stale", as: .systemMedium) {
    CarrierWidget()
} timeline: {
    CarrierTimelineEntry(
        date: .now,
        state: .loaded(CarrierEntry(
            id: "preview-stale",
            barcode: "/ABC-12345678",
            typeRawValue: "phoneBarcodeCarrier",
            name: "手機條碼載具",
            updatedAt: Calendar.current.date(byAdding: .day, value: -120, to: .now)
        ))
    )
}
```

- [ ] **Step 3: Build to verify the widget compiles**

Run: `xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5`
Expected: exit code 0.

- [ ] **Step 4: Manual verification on simulator**

1. Build and run the `NeuLedger` scheme on iPhone 17 Pro simulator.
2. Add the CarrierWidget to the home screen.
3. Long-press the widget → "Edit Widget" → confirm the carrier picker appears with name + type subtitle.
4. Select a carrier → confirm the widget refreshes with the chosen carrier's barcode.
5. In the app, delete that carrier → return to home screen → confirm the widget shows the deleted state with "重新設定" CTA.
6. Tap the deleted CTA → confirm it deeplinks into Settings → Carrier Management.
7. Reconfigure the widget to a different carrier → confirm the loaded state returns.

- [ ] **Step 5: Commit**

```bash
git add NeuLedgerWidget/CarrierWidget.swift NeuLedgerWidget/Localizable.xcstrings
git commit -m "feat(widget): migrate CarrierWidget to AppIntentConfiguration

Each widget instance now independently binds to a carrier via the system
Edit sheet. Adds .deleted state for carriers that have been removed from
the app.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Done

All seven tasks complete. Verify final state:

- [ ] Run all Features tests: `xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5` → all green
- [ ] Run app build: `xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5` → exit 0
- [ ] Manual smoke test of widget configuration flow (Task 7 Step 4)

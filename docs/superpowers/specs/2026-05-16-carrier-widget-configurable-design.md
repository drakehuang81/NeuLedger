# Carrier Widget — Configurable Per-Instance Carrier Selection

**Date:** 2026-05-16  
**Status:** Approved  

---

## Goal

Allow users to long-press the CarrierWidget and select which carrier to display. Each widget instance independently binds to one carrier. When the bound carrier is deleted from the app, the widget shows a "carrier deleted" prompt.

---

## Decisions

| Question | Decision |
|----------|----------|
| Per-instance or shared? | Per-instance independent binding |
| Deleted carrier display | Show "此載具已被刪除" with CTA to reconfigure |
| Sync trigger | Sync all carriers after every CRUD operation in CarrierManagementFeature (Option A only) |
| Picker display | Carrier name (title) + type label (subtitle) |
| CarrierManagement cell subtitle | Show user-entered barcode string (not fixed type name) |

---

## Architecture

### 1. App Group Data Contract

**New key:** `carrierList` — JSON-encoded array of all carriers.

`CarrierEntry` gains an `id: String` field (UUID string). Old single-carrier keys (`carrierBarcode`, `carrierType`, `carrierName`, `carrierUpdatedAt`) are **kept for backward compatibility** during the transition; they may be removed in a future version.

```swift
struct CarrierEntry: Codable {
    let id: String
    let barcode: String
    let typeRawValue: String   // "phoneBarcodeCarrier" | "citizenDigitalCertificate"
    let name: String
    let updatedAt: Date?
}
```

`WidgetAppGroup` additions:
```swift
static func readAllCarriers() -> [CarrierEntry]
static func writeAllCarriers(_ carriers: [CarrierEntry])
```

---

### 2. AppEntity + Intent (Widget Target)

**File:** `NeuLedgerWidget/CarrierAppEntity.swift`

```swift
struct CarrierAppEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "載具")
    static var defaultQuery = CarrierEntityQuery()

    var id: String
    var name: String
    var typeDisplayName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(typeDisplayName)")
    }
}

struct CarrierEntityQuery: EntityQuery {
    func entities(for ids: [String]) async throws -> [CarrierAppEntity]
    func suggestedEntities() async throws -> [CarrierAppEntity]
    // Both read from WidgetAppGroup.readAllCarriers()
}

struct CarrierSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "選擇載具"
    @Parameter(title: "載具") var carrier: CarrierAppEntity?
}
```

---

### 3. WidgetSyncClient

**Domain** (`Domain/Clients/WidgetSyncClient.swift`):
```swift
var syncAllCarriers: @Sendable ([Carrier]) async -> Void
```

**Core** (`Core/Clients/WidgetSyncClient+Live.swift`):
- Map `[Carrier]` → `[CarrierEntry]` (using `id.uuidString`)
- JSON encode → write to App Group `carrierList` key
- Call `WidgetCenter.shared.reloadAllTimelines()`

---

### 4. CarrierManagementFeature Sync Trigger

After each of the following actions, call `widgetSyncClient.syncAllCarriers(carriers)` where `carriers` is the refreshed active carrier list:
- `addEdit(.presented(.delegate(.saved)))` (add or edit)
- `deleteConfirmed` (after delete completes)

---

### 5. CarrierWidget States

```swift
enum CarrierWidgetState {
    case loaded(CarrierEntry)
    case empty               // intent.carrier == nil, or no carriers configured
    case deleted(name: String)  // carrier ID not found in current list
}

struct CarrierTimelineEntry: TimelineEntry {
    let date: Date
    let state: CarrierWidgetState
}
```

**Timeline provider logic:**
1. Read `intent.carrier?.id`
2. Call `WidgetAppGroup.readAllCarriers()`
3. If `intent.carrier == nil` → `.empty`
4. If ID found → `.loaded(entry)`
5. If ID not found → `.deleted(name: intent.carrier.name)`

**Widget configuration:**
```swift
AppIntentConfiguration(kind: kind, intent: CarrierSelectionIntent.self, provider: ...) { entry in
    CarrierWidgetView(entry: entry)
}
```

---

### 6. CarrierWidgetView State Rendering

| State | View |
|-------|------|
| `.loaded(entry)` | Existing barcode + header UI |
| `.empty` | Existing empty state with Link CTA |
| `.deleted(name:)` | Icon + "「{name}」已從 app 移除" + "重新設定" Link CTA |

---

### 7. CarrierManagement Cell Subtitle (Side Fix)

Change `carrierRow` subtitle from `carrier.type.defaultName` (fixed type string) to `carrier.barcode` (user-entered raw barcode string).

---

## Files Changed

| File | Change |
|------|--------|
| `Shared/WidgetAppGroup.swift` | Add `id` to `CarrierEntry`; add `readAllCarriers` / `writeAllCarriers` |
| `Domain/Clients/WidgetSyncClient.swift` | Add `syncAllCarriers` method |
| `Core/Clients/WidgetSyncClient+Live.swift` | Implement `syncAllCarriers` |
| `Features/CarrierManagement/CarrierManagementFeature.swift` | Call `syncAllCarriers` after add/edit/delete |
| `NeuLedgerWidget/CarrierAppEntity.swift` | New file: `CarrierAppEntity`, `CarrierEntityQuery`, `CarrierSelectionIntent` |
| `NeuLedgerWidget/CarrierWidget.swift` | Switch to `AppIntentConfiguration`; update entry/provider; add `.deleted` state view |
| `Features/CarrierManagement/CarrierManagementView.swift` | Cell subtitle: `carrier.barcode` |

## Out of Scope

- VoiceWidget configuration (separate feature)
- Removing old single-carrier App Group keys (cleanup in future)
- CloudKit / multi-device sync for carrier list

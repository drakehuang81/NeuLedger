# Widget Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship CarrierWidget (displays carrier barcode on Home Screen) with Settings integration, App Group data sharing, deep link routing, and VoiceWidget scaffolding (gated, not user-facing).

**Architecture:** New `NeuLedgerWidget` Extension target reads carrier data from App Group UserDefaults. Main app writes carrier config on Settings/CarrierManagement changes and calls `WidgetCenter.reloadTimelines`. Deep link `neuledger://carrier-management` routes to CarrierManagement via `onOpenURL` in AppView. VoiceWidget code exists but is not registered in WidgetBundle.

**Tech Stack:** WidgetKit, App Groups (UserDefaults), CoreImage (Code128 barcode generation), TCA 1.23.1, Swift Testing

**Spec:** `docs/superpowers/specs/2026-04-06-widget-design.md` (Phase 1 section only)

---

## File Structure

### New Files

| File | Target | Responsibility |
|------|--------|----------------|
| `Shared/WidgetAppGroup.swift` | App + Widget Extension | App Group read/write helper (suite name, typed keys, read/write/clear methods) |
| `NeuLedgerWidget/NeuLedgerWidgetBundle.swift` | Widget Extension | `@main WidgetBundle` — registers only CarrierWidget |
| `NeuLedgerWidget/CarrierWidget.swift` | Widget Extension | `TimelineProvider`, `TimelineEntry`, widget `View` (barcode + empty state) |
| `NeuLedgerWidget/VoiceWidget.swift` | Widget Extension | Scaffolding only — `TimelineProvider` + placeholder View (not in bundle) |

### Modified Files

| File | Changes |
|------|---------|
| `Features/Sources/Domain/Clients/UserSettingsClient.swift` | Add `widgetCarrierId` SettingsKey |
| `Features/Sources/Features/Settings/SettingsFeature.swift` | Add widget state/actions, load carriers in `.task`, write App Group on selection |
| `Features/Sources/Features/Settings/SettingsView.swift` | Add "Widget 設定" section |
| `Features/Sources/Features/CarrierManagement/CarrierManagementFeature.swift` | Sync App Group on delete/edit of active widget carrier |
| `Features/Sources/Features/AppFeature.swift` | Add `deepLinkReceived(URL)` action |
| `Features/Sources/Features/AppView.swift` | Add `.onOpenURL` modifier |
| `NeuLedger/NeuLedger.entitlements` | Add `com.apple.security.application-groups` |
| `NeuLedger/Info.plist` | Add `CFBundleURLTypes` for `neuledger` scheme |
| `NeuLedger/Resources/Localizable.xcstrings` | Add widget-related localization keys |

### Test Files

| File | Tests |
|------|-------|
| `Features/Tests/FeaturesTests/SettingsFeatureTests.swift` | Extend with widget carrier selection, loading, App Group write |
| `Features/Tests/FeaturesTests/CarrierManagementFeatureTests.swift` | Extend with App Group sync on delete/edit |

---

## Task 1: Xcode Project Setup (Manual)

> This task involves Xcode UI operations that cannot be automated via code. The engineer must perform these manually.

**Files:**
- Create: `NeuLedgerWidget/` directory (via Xcode)
- Modify: `NeuLedger.xcodeproj`
- Modify: `NeuLedger/NeuLedger.entitlements`

- [ ] **Step 1: Add Widget Extension target in Xcode**

Open `NeuLedger.xcodeproj` in Xcode → File → New → Target → Widget Extension.

Settings:
- Product Name: `NeuLedgerWidget`
- Team: (your team)
- Bundle Identifier: `com.drakehuang.NeuLedger.NeuLedgerWidget`
- Include Configuration App Intent: **No** (uncheck)
- Include Live Activity: **No** (uncheck — Phase 2)
- Embed in Application: `NeuLedger`

Xcode will create `NeuLedgerWidget/` with template files. **Delete all template-generated `.swift` files** — we will write them from scratch in subsequent tasks.

- [ ] **Step 2: Add App Group capability to main app**

Select `NeuLedger` target → Signing & Capabilities → + Capability → App Groups.

Add group: `group.com.drakehuang.NeuLedger`

Verify `NeuLedger/NeuLedger.entitlements` now contains:

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.drakehuang.NeuLedger</string>
</array>
```

- [ ] **Step 3: Add App Group capability to Widget Extension**

Select `NeuLedgerWidget` target → Signing & Capabilities → + Capability → App Groups.

Add the **same** group: `group.com.drakehuang.NeuLedger`

Verify `NeuLedgerWidget/NeuLedgerWidget.entitlements` contains the same entry.

- [ ] **Step 4: Add Shared folder to both targets**

In Xcode project navigator, create a group `Shared/` at the project root level.

Ensure `Shared/` files will be added to **both** `NeuLedger` and `NeuLedgerWidget` targets (check Target Membership when adding files).

- [ ] **Step 5: Register `neuledger` URL scheme**

Edit `NeuLedger/Info.plist` — add URL Types:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>neuledger</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.drakehuang.NeuLedger</string>
    </dict>
</array>
```

- [ ] **Step 6: Build to verify project compiles**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore: add NeuLedgerWidget extension target with App Group and URL scheme"
```

---

## Task 2: WidgetAppGroup Shared Helper

**Files:**
- Create: `Shared/WidgetAppGroup.swift`

- [ ] **Step 1: Write WidgetAppGroup**

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
        case carrierBarcode
        case carrierType
        case carrierName
        case carrierUpdatedAt
    }

    // MARK: - Carrier Read

    /// Reads the current carrier configuration from App Group.
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
        return CarrierEntry(barcode: barcode, typeRawValue: typeRaw, name: name, updatedAt: updatedAt)
    }

    // MARK: - Carrier Write (main app only)

    /// Writes carrier configuration to App Group.
    static func writeCarrier(barcode: String, type: String, name: String) {
        guard let defaults else { return }
        defaults.set(barcode, forKey: Key.carrierBarcode.rawValue)
        defaults.set(type, forKey: Key.carrierType.rawValue)
        defaults.set(name, forKey: Key.carrierName.rawValue)
        defaults.set(Date(), forKey: Key.carrierUpdatedAt.rawValue)
    }

    /// Clears all carrier data from App Group (e.g. when the active widget carrier is deleted).
    static func clearCarrier() {
        guard let defaults else { return }
        for key in [Key.carrierBarcode, .carrierType, .carrierName, .carrierUpdatedAt] {
            defaults.removeObject(forKey: key.rawValue)
        }
    }
}

// MARK: - CarrierEntry

/// A lightweight value type representing carrier data read from App Group.
/// Used by the Widget Extension — no dependency on Domain layer.
struct CarrierEntry {
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

- [ ] **Step 2: Add file to both targets**

In Xcode, select `WidgetAppGroup.swift` → check Target Membership for both `NeuLedger` and `NeuLedgerWidget`.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- [ ] **Step 4: Commit**

```bash
git add Shared/WidgetAppGroup.swift
git commit -m "feat(widget): add WidgetAppGroup shared helper for App Group read/write"
```

---

## Task 3: CarrierWidget (TimelineProvider + View)

**Files:**
- Create: `NeuLedgerWidget/CarrierWidget.swift`
- Create: `NeuLedgerWidget/NeuLedgerWidgetBundle.swift`

- [ ] **Step 1: Write CarrierWidget**

```swift
// NeuLedgerWidget/CarrierWidget.swift
import WidgetKit
import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Timeline Entry

struct CarrierTimelineEntry: TimelineEntry {
    let date: Date
    let carrier: CarrierEntry?
}

// MARK: - Timeline Provider

struct CarrierTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CarrierTimelineEntry {
        CarrierTimelineEntry(
            date: .now,
            carrier: CarrierEntry(
                barcode: "/ABC1234",
                typeRawValue: "phoneBarcodeCarrier",
                name: "我的手機條碼",
                updatedAt: nil
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CarrierTimelineEntry) -> Void) {
        let entry = CarrierTimelineEntry(date: .now, carrier: WidgetAppGroup.readCarrier())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CarrierTimelineEntry>) -> Void) {
        let entry = CarrierTimelineEntry(date: .now, carrier: WidgetAppGroup.readCarrier())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Widget View

struct CarrierWidgetView: View {
    let entry: CarrierTimelineEntry

    var body: some View {
        if let carrier = entry.carrier {
            carrierContent(carrier)
        } else {
            emptyState
        }
    }

    // MARK: - Carrier Content

    private func carrierContent(_ carrier: CarrierEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(spacing: 6) {
                Image(systemName: "creditcard.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.orange)
                    .font(.system(size: 14, weight: .semibold))

                Text(carrier.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                Text(carrier.typeDisplayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }

            // Barcode area
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white)

                if let barcodeImage = generateBarcode(from: carrier.barcode) {
                    Image(uiImage: barcodeImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 16) // quiet zone
                        .padding(.vertical, 6)
                } else {
                    Text(carrier.barcode)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.black)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(URL(string: "neuledger://carrier-management"))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .font(.system(size: 28))

            Text("widget_carrier_empty")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(URL(string: "neuledger://carrier-management"))
    }

    // MARK: - Barcode Generation

    private func generateBarcode(from string: String) -> UIImage? {
        guard let data = string.data(using: .ascii) else { return nil }

        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = data
        filter.quietSpace = 10

        guard let ciImage = filter.outputImage else { return nil }

        // Scale up for crisp rendering (original is very small)
        let scaleX = 3.0
        let scaleY = 1.5
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Widget Definition

struct CarrierWidget: Widget {
    let kind: String = "CarrierWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CarrierTimelineProvider()) { entry in
            CarrierWidgetView(entry: entry)
        }
        .configurationDisplayName(Text("widget_carrier_display_name"))
        .description(Text("widget_carrier_description"))
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    CarrierWidget()
} timeline: {
    CarrierTimelineEntry(
        date: .now,
        carrier: CarrierEntry(
            barcode: "/ABC1234",
            typeRawValue: "phoneBarcodeCarrier",
            name: "我的手機條碼",
            updatedAt: .now
        )
    )
    CarrierTimelineEntry(date: .now, carrier: nil)
}
```

- [ ] **Step 2: Write NeuLedgerWidgetBundle**

```swift
// NeuLedgerWidget/NeuLedgerWidgetBundle.swift
import WidgetKit
import SwiftUI

@main
struct NeuLedgerWidgetBundle: WidgetBundle {
    var body: some Widget {
        CarrierWidget()
        // VoiceWidget()  // Phase 2: uncomment to enable
    }
}
```

- [ ] **Step 3: Build Widget Extension to verify**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedgerWidgetExtension \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

If the scheme is named differently, check with:
```bash
xcodebuild -project NeuLedger.xcodeproj -list
```

- [ ] **Step 4: Commit**

```bash
git add NeuLedgerWidget/CarrierWidget.swift NeuLedgerWidget/NeuLedgerWidgetBundle.swift
git commit -m "feat(widget): implement CarrierWidget with Code128 barcode and empty state"
```

---

## Task 4: VoiceWidget Scaffolding (Gated)

**Files:**
- Create: `NeuLedgerWidget/VoiceWidget.swift`

- [ ] **Step 1: Write VoiceWidget scaffold**

```swift
// NeuLedgerWidget/VoiceWidget.swift
import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct VoiceTimelineEntry: TimelineEntry {
    let date: Date
    let accountName: String
}

// MARK: - Timeline Provider

struct VoiceTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> VoiceTimelineEntry {
        VoiceTimelineEntry(date: .now, accountName: "現金帳戶")
    }

    func getSnapshot(in context: Context, completion: @escaping (VoiceTimelineEntry) -> Void) {
        completion(VoiceTimelineEntry(date: .now, accountName: "現金帳戶"))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VoiceTimelineEntry>) -> Void) {
        let entry = VoiceTimelineEntry(date: .now, accountName: "現金帳戶")
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Widget View

struct VoiceWidgetView: View {
    let entry: VoiceTimelineEntry

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color.orange)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                }
                .shadow(color: .orange.opacity(0.4), radius: 8, y: 4)

            Text("widget_voice_title")
                .font(.system(size: 12, weight: .semibold))

            Text(entry.accountName)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Widget Definition (NOT registered in WidgetBundle — Phase 2)

struct VoiceWidget: Widget {
    let kind: String = "VoiceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VoiceTimelineProvider()) { entry in
            VoiceWidgetView(entry: entry)
        }
        .configurationDisplayName(Text("widget_voice_display_name"))
        .description(Text("widget_voice_description"))
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    VoiceWidget()
} timeline: {
    VoiceTimelineEntry(date: .now, accountName: "現金帳戶")
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- [ ] **Step 3: Commit**

```bash
git add NeuLedgerWidget/VoiceWidget.swift
git commit -m "feat(widget): add VoiceWidget scaffolding (gated, not registered in bundle)"
```

---

## Task 5: Add Localization Keys

**Files:**
- Modify: `NeuLedger/Resources/Localizable.xcstrings`

- [ ] **Step 1: Add widget localization entries**

Add the following entries to `Localizable.xcstrings` (insert near the existing `carrier_*` keys or at the end of the `strings` object). Each entry follows the existing format:

```json
"widget_carrier_display_name": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "我的載具" } },
    "en": { "stringUnit": { "state": "translated", "value": "My Carrier" } }
  }
},
"widget_carrier_description": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "顯示載具條碼供店員掃描" } },
    "en": { "stringUnit": { "state": "translated", "value": "Display carrier barcode for scanning" } }
  }
},
"widget_carrier_empty": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "請在 NeuLedger 設定 Widget 載具" } },
    "en": { "stringUnit": { "state": "translated", "value": "Set up a carrier in NeuLedger settings" } }
  }
},
"widget_voice_display_name": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "語音記帳" } },
    "en": { "stringUnit": { "state": "translated", "value": "Voice Bookkeeping" } }
  }
},
"widget_voice_description": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "快速語音記帳" } },
    "en": { "stringUnit": { "state": "translated", "value": "Quick voice bookkeeping" } }
  }
},
"widget_voice_title": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "語音記帳" } },
    "en": { "stringUnit": { "state": "translated", "value": "Voice" } }
  }
},
"settings_widget": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "Widget 設定" } },
    "en": { "stringUnit": { "state": "translated", "value": "Widget Settings" } }
  }
},
"settings_widget_carrier": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "顯示的載具" } },
    "en": { "stringUnit": { "state": "translated", "value": "Display Carrier" } }
  }
},
"settings_widget_voice_account": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "語音記帳帳戶" } },
    "en": { "stringUnit": { "state": "translated", "value": "Voice Account" } }
  }
},
"settings_widget_coming_soon": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "即將推出" } },
    "en": { "stringUnit": { "state": "translated", "value": "Coming Soon" } }
  }
},
"settings_widget_no_carrier": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "尚無載具" } },
    "en": { "stringUnit": { "state": "translated", "value": "No carriers" } }
  }
}
```

- [ ] **Step 2: Build to verify strings compile**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- [ ] **Step 3: Commit**

```bash
git add NeuLedger/Resources/Localizable.xcstrings
git commit -m "feat(widget): add widget localization keys for carrier and voice widgets"
```

---

## Task 6: SettingsKey + SettingsFeature Widget Integration

**Files:**
- Modify: `Features/Sources/Domain/Clients/UserSettingsClient.swift`
- Modify: `Features/Sources/Features/Settings/SettingsFeature.swift`
- Modify: `Features/Sources/Features/Settings/SettingsView.swift`
- Test: `Features/Tests/FeaturesTests/SettingsFeatureTests.swift`

- [ ] **Step 1: Add `widgetCarrierId` SettingsKey**

In `Features/Sources/Domain/Clients/UserSettingsClient.swift`, add to the `String` keys extension:

```swift
// Inside: public extension SettingsKey where Value == String {
    /// The UUID of the carrier selected for the CarrierWidget.
    static let widgetCarrierId = SettingsKey(
        rawValue: "widgetCarrierId",
        defaultValue: ""
    )
```

- [ ] **Step 2: Write failing tests for widget carrier selection**

Append to `Features/Tests/FeaturesTests/SettingsFeatureTests.swift`:

```swift
// MARK: - Widget Carrier

private static let sampleCarriers: [Carrier] = [
    Carrier(name: "我的手機條碼", type: .phoneBarcodeCarrier, barcode: "/ABC1234"),
    Carrier(name: "自然人憑證", type: .citizenDigitalCertificate, barcode: "/PCERT1234567890AB"),
]

@Test(".task loads widget carriers and selected carrier name")
func testTaskLoadsWidgetCarriers() async throws {
    let carrier = Self.sampleCarriers[0]
    let store = await TestStore(
        initialState: SettingsFeature.State()
    ) {
        SettingsFeature()
    } withDependencies: {
        $0.userSettingsClient.bool = { _ in false }
        $0.userSettingsClient.string = { key in
            if key.rawValue == "widgetCarrierId" {
                return carrier.id.uuidString
            }
            return ""
        }
        $0.userSettingsClient.setString = { _, _ in }
        $0.accountClient.fetchActive = { Self.sampleAccounts }
        $0.carrierClient.fetchAll = { Self.sampleCarriers }
    }

    await store.send(.task)

    await store.receive(\.accountsLoaded) {
        $0.accounts = Self.sampleAccounts
        $0.defaultAccountName = "現金錢包"
    }
    await store.receive(\.defaultAccountSelected)
    await store.receive(\.languageLoaded) {
        $0.currentLanguage = Locale.current.localizedString(
            forLanguageCode: Locale.current.language.languageCode?.identifier ?? "zh"
        )?.localizedCapitalized ?? "zh"
    }
    await store.receive(\.accessoryBarToggleChanged) {
        $0.showAccessoryBar = false
    }
    await store.receive(\.widgetCarriersLoaded) {
        $0.carriers = Self.sampleCarriers
        $0.widgetCarrierId = carrier.id.uuidString
        $0.widgetCarrierName = "我的手機條碼"
    }
}

@Test("widgetCarrierSelected writes to UserSettings")
func testWidgetCarrierSelected() async throws {
    let carriers = Self.sampleCarriers
    let target = carriers[1]
    var savedId: String?
    let store = await TestStore(
        initialState: SettingsFeature.State(carriers: carriers)
    ) {
        SettingsFeature()
    } withDependencies: {
        $0.userSettingsClient.setString = { value, key in
            if key.rawValue == "widgetCarrierId" { savedId = value }
        }
    }

    await store.send(.widgetCarrierSelected(target.id)) {
        $0.widgetCarrierId = target.id.uuidString
        $0.widgetCarrierName = "自然人憑證"
    }

    #expect(savedId == target.id.uuidString)
}
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/SettingsFeatureTests 2>&1 | tail -20
```

Expected: FAIL — `widgetCarriersLoaded`, `widgetCarrierSelected`, `carriers`, `widgetCarrierId`, `widgetCarrierName` don't exist yet.

- [ ] **Step 4: Add widget state and actions to SettingsFeature**

In `Features/Sources/Features/Settings/SettingsFeature.swift`:

**State** — add inside `State`:

```swift
public var carriers: [Carrier] = []
public var widgetCarrierId: String = ""
public var widgetCarrierName: String = ""
```

Update `State.init` to accept new params (with defaults):

```swift
public init(
    accounts: [Account] = [],
    selectedDefaultAccountId: String = "",
    defaultAccountName: String = "",
    currentLanguage: String = "",
    showAccessoryBar: Bool = true,
    carriers: [Carrier] = [],
    widgetCarrierId: String = "",
    widgetCarrierName: String = ""
) {
    self.accounts = accounts
    self.selectedDefaultAccountId = selectedDefaultAccountId
    self.defaultAccountName = defaultAccountName
    self.currentLanguage = currentLanguage
    self.showAccessoryBar = showAccessoryBar
    self.carriers = carriers
    self.widgetCarrierId = widgetCarrierId
    self.widgetCarrierName = widgetCarrierName
}
```

**Action** — add cases:

```swift
case widgetCarrierSelected(Carrier.ID)
case widgetCarriersLoaded([Carrier])
```

**Dependencies** — add:

```swift
@Dependency(\.carrierClient) var carrierClient
```

**Reducer body** — add in `.task` effect (append after existing sends):

```swift
let carriers = try await carrierClient.fetchAll()
let widgetCarrierId = userSettingsClient.string(.widgetCarrierId)
await send(.widgetCarriersLoaded(carriers))
```

Note: the `widgetCarrierId` is read inside the `.widgetCarriersLoaded` handler (see below), so just pass carriers.

Update the `.task` to also load the `widgetCarrierId`:

```swift
case .task:
    return .run { send in
        async let accounts = accountClient.fetchActive()
        async let carriers = carrierClient.fetchAll()
        let defaultId = userSettingsClient.string(.defaultAccountId)
        let widgetCarrierId = userSettingsClient.string(.widgetCarrierId)
        let showAccessoryBar = userSettingsClient.bool(.showAccessoryBar)
        let fetched = try await accounts
        await send(.accountsLoaded(fetched))
        await send(.defaultAccountSelected(defaultId))
        let langCode = Locale.current.language.languageCode?.identifier ?? "zh"
        let displayName = Locale.current.localizedString(forLanguageCode: langCode)?.localizedCapitalized ?? langCode
        await send(.languageLoaded(displayName))
        await send(.accessoryBarToggleChanged(showAccessoryBar))
        let fetchedCarriers = try await carriers
        await send(.widgetCarriersLoaded(fetchedCarriers))
    }
    .cancellable(id: CancelID.task)
```

Add new case handlers:

```swift
case let .widgetCarriersLoaded(carriers):
    state.carriers = carriers
    let savedId = userSettingsClient.string(.widgetCarrierId)
    state.widgetCarrierId = savedId
    if let carrier = carriers.first(where: { $0.id.uuidString == savedId }) {
        state.widgetCarrierName = carrier.name
    } else {
        state.widgetCarrierName = ""
    }
    return .none

case let .widgetCarrierSelected(id):
    state.widgetCarrierId = id.uuidString
    userSettingsClient.setString(id.uuidString, .widgetCarrierId)
    if let carrier = state.carriers.first(where: { $0.id == id }) {
        state.widgetCarrierName = carrier.name
        WidgetAppGroup.writeCarrier(
            barcode: carrier.barcode,
            type: carrier.type.rawValue,
            name: carrier.name
        )
    }
    return .run { _ in
        #if canImport(WidgetKit)
        await WidgetCenter.shared.reloadTimelines(ofKind: "CarrierWidget")
        #endif
    }
```

Add import at the top of the file:

```swift
import WidgetKit
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/SettingsFeatureTests 2>&1 | tail -20
```

Expected: PASS

- [ ] **Step 6: Add Widget section to SettingsView**

In `Features/Sources/Features/Settings/SettingsView.swift`, add a new `sectionWidget` property and insert it in `body` between `sectionPreferences` and `sectionData`:

```swift
// In the body VStack, add:
// MARK: Widget 設定
sectionWidget
```

```swift
// MARK: - Widget 設定

private var sectionWidget: some View {
    VStack(spacing: 6) {
        sectionHeader(String(localized: "settings_widget"))
        GlassContainer(cornerRadius: 16, padding: 0) {
            VStack(spacing: 0) {
                // Carrier picker
                if store.carriers.isEmpty {
                    settingsRow(
                        icon: "creditcard.fill",
                        iconColor: Color.Design.brandPrimary,
                        label: String(localized: "settings_widget_carrier"),
                        trailing: Text(String(localized: "settings_widget_no_carrier"))
                            .font(.body)
                            .foregroundStyle(Color.Design.textTertiary)
                    )
                } else {
                    Picker(selection: Binding(
                        get: { store.widgetCarrierId },
                        set: { newValue in
                            if let uuid = UUID(uuidString: newValue) {
                                store.send(.widgetCarrierSelected(uuid))
                            }
                        }
                    ), label: settingsRow(
                        icon: "creditcard.fill",
                        iconColor: Color.Design.brandPrimary,
                        label: String(localized: "settings_widget_carrier"),
                        trailing: EmptyView()
                    )) {
                        ForEach(store.carriers) { carrier in
                            Text(carrier.name).tag(carrier.id.uuidString)
                        }
                    }
                }

                // Voice account — Phase 2 (coming soon)
                settingsRow(
                    icon: "mic.fill",
                    iconColor: Color.Design.textTertiary,
                    label: String(localized: "settings_widget_voice_account"),
                    trailing: Text(String(localized: "settings_widget_coming_soon"))
                        .font(.body)
                        .foregroundStyle(Color.Design.textTertiary)
                )
            }
            .frame(maxWidth: .infinity)
        }
    }
}
```

- [ ] **Step 7: Build app to verify**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- [ ] **Step 8: Commit**

```bash
git add Features/Sources/Domain/Clients/UserSettingsClient.swift \
  Features/Sources/Features/Settings/SettingsFeature.swift \
  Features/Sources/Features/Settings/SettingsView.swift \
  Features/Tests/FeaturesTests/SettingsFeatureTests.swift
git commit -m "feat(settings): add Widget settings section with carrier picker and tests"
```

---

## Task 7: CarrierManagement App Group Sync

**Files:**
- Modify: `Features/Sources/Features/CarrierManagement/CarrierManagementFeature.swift`
- Test: `Features/Tests/FeaturesTests/SettingsFeatureTests.swift` (or create `CarrierManagementFeatureTests.swift`)

- [ ] **Step 1: Write failing test for delete-sync**

In `Features/Tests/FeaturesTests/SettingsFeatureTests.swift` (or a new carrier management test file), add:

```swift
@Test("deleting the widget carrier clears App Group")
func testDeleteWidgetCarrierClearsAppGroup() async throws {
    let carrier = Self.sampleCarriers[0]
    var deletedId: Carrier.ID?
    let store = await TestStore(
        initialState: CarrierManagementFeature.State()
    ) {
        CarrierManagementFeature()
    } withDependencies: {
        $0.carrierClient.delete = { id in deletedId = id }
        $0.carrierClient.fetchAll = { [] }
        $0.userSettingsClient.string = { key in
            if key.rawValue == "widgetCarrierId" { return carrier.id.uuidString }
            return ""
        }
        $0.userSettingsClient.setString = { _, _ in }
    }

    await store.send(.deleteTapped(carrier.id))

    await store.receive(\.carriersLoaded) {
        $0.carriers = []
        $0.expandedCarrierId = nil
    }

    #expect(deletedId == carrier.id)
}
```

- [ ] **Step 2: Run test to verify it fails or passes baseline**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/SettingsFeatureTests 2>&1 | tail -20
```

- [ ] **Step 3: Add App Group sync to CarrierManagementFeature**

In `Features/Sources/Features/CarrierManagement/CarrierManagementFeature.swift`:

Add dependency:

```swift
@Dependency(\.userSettingsClient) var userSettingsClient
```

Add import:

```swift
import WidgetKit
```

In the `.deleteTapped` case, after successful delete and reload, check if the deleted carrier was the widget carrier and clear App Group:

Replace the existing `.deleteTapped` case:

```swift
case let .deleteTapped(id):
    state.expandedCarrierId = nil
    return .run { [userSettingsClient] send in
        try await carrierClient.delete(id)
        let carriers = try await carrierClient.fetchAll()
        // If deleted carrier was the widget carrier, clear App Group
        let widgetCarrierId = userSettingsClient.string(.widgetCarrierId)
        if widgetCarrierId == id.uuidString {
            WidgetAppGroup.clearCarrier()
            userSettingsClient.setString("", .widgetCarrierId)
            await WidgetCenter.shared.reloadTimelines(ofKind: "CarrierWidget")
        }
        await send(.carriersLoaded(carriers))
    } catch: { _, send in
        let carriers = (try? await carrierClient.fetchAll()) ?? []
        await send(.carriersLoaded(carriers))
    }
```

For the `.addEdit(.presented(.delegate(.saved)))` case, also sync if the edited carrier is the widget carrier. Replace:

```swift
case .addEdit(.presented(.delegate(.saved))):
    state.addEdit = nil
    return .run { [userSettingsClient] send in
        let carriers = try await carrierClient.fetchAll()
        // If the widget carrier was edited, update App Group
        let widgetCarrierId = userSettingsClient.string(.widgetCarrierId)
        if !widgetCarrierId.isEmpty,
           let carrier = carriers.first(where: { $0.id.uuidString == widgetCarrierId }) {
            WidgetAppGroup.writeCarrier(
                barcode: carrier.barcode,
                type: carrier.type.rawValue,
                name: carrier.name
            )
            await WidgetCenter.shared.reloadTimelines(ofKind: "CarrierWidget")
        }
        await send(.carriersLoaded(carriers))
    }
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/SettingsFeatureTests 2>&1 | tail -20
```

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Features/CarrierManagement/CarrierManagementFeature.swift \
  Features/Tests/FeaturesTests/SettingsFeatureTests.swift
git commit -m "feat(carrier): sync App Group on carrier delete/edit for widget invalidation"
```

---

## Task 8: Deep Link Routing

**Files:**
- Modify: `Features/Sources/Features/AppFeature.swift`
- Modify: `Features/Sources/Features/AppView.swift`

- [ ] **Step 1: Add deepLinkReceived action to AppFeature**

In `Features/Sources/Features/AppFeature.swift`:

Add action case:

```swift
case deepLinkReceived(URL)
```

Add handler in reducer body:

```swift
case let .deepLinkReceived(url):
    guard url.scheme == "neuledger",
          url.host == "carrier-management" else { return .none }
    guard case .main(var mainState) = state.destination else { return .none }
    mainState.selectedTab = .settings
    mainState.settings.path.append(.carrierManagement(CarrierManagementFeature.State()))
    state.destination = .main(mainState)
    return .none
```

- [ ] **Step 2: Add `.onOpenURL` to AppView**

In `Features/Sources/Features/AppView.swift`, add `.onOpenURL` modifier to `contentView`:

```swift
// After the existing .task modifier, add:
.onOpenURL { url in
    Self.store.send(.deepLinkReceived(url))
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Features/AppFeature.swift \
  Features/Sources/Features/AppView.swift
git commit -m "feat(navigation): add deep link routing for neuledger://carrier-management"
```

---

## Task 9: Full Build + Run All Tests

- [ ] **Step 1: Build full app**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- [ ] **Step 2: Run all tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: All tests PASS, including new widget-related tests.

- [ ] **Step 3: Verify no regressions in existing tests**

Check that `SettingsFeatureTests.testTaskLoadsAccountName` still passes (the `.task` effect now has additional `receive` calls for `widgetCarriersLoaded`).

If this test now fails because it doesn't expect the `widgetCarriersLoaded` action, update it to add:

```swift
await store.receive(\.widgetCarriersLoaded) {
    $0.carriers = []  // or mock carriers as needed
}
```

- [ ] **Step 4: Commit if any test fixes were needed**

```bash
git add -A
git commit -m "test: fix existing SettingsFeature tests to handle new widget actions"
```

# iCloud Sync Design

**Date:** 2026-04-01
**Status:** Approved

## Overview

Add iCloud sync via CloudKit private database as a paid feature. Free users keep data local only. Paid users can migrate all existing data to CloudKit and sync across devices. Subscription status is mocked via `UserSettingsClient` for now; real StoreKit integration comes in a later cycle.

CSV/JSON export is retained as a debug-only feature and is not user-facing.

---

## Goals

- Cross-device sync tied to a paid subscription
- No app restart required when enabling sync (dynamic container swap)
- Full migration of existing local data when sync is first enabled
- Settings page exposes sync controls (or upsell) based on subscription state
- CloudKit inherently provides iCloud backup; no separate backup mechanism needed

## Non-Goals

- StoreKit 2 / real payment flow (deferred to subscription cycle)
- Disabling sync after it is enabled (V1: once migrated, stay on CloudKit container)
- iCloud Drive file export as a user-facing feature

---

## Architecture

### Layer Responsibilities

```
Domain/
├── Clients/SyncClient.swift              # New: interface
Core/
├── Clients/SyncClient+Live.swift         # New: CloudKit container + migration
├── Persistence/DatabaseClient.swift      # Modified: static var container (swappable)
├── Persistence/Models/SD*.swift          # Modified: CloudKit schema compatibility
Features/
├── Settings/SyncSettings/
│   ├── SyncSettingsFeature.swift         # New: TCA Reducer
│   └── SyncSettingsView.swift            # New: sync settings / upsell UI
├── Settings/SettingsFeature.swift        # Modified: add .sync destination
└── Settings/SettingsView.swift           # Modified: add Sync row
```

### Data Flow

1. User opens Settings → taps Sync row → pushes `SyncSettingsView`
2. View reads `isSubscribed` (mock flag from `UserSettingsClient`)
   - Not subscribed → upsell page with "Subscribe Now" CTA
   - Subscribed, sync not enabled → "Enable iCloud Sync" button
   - Subscribed, sync enabled → status row showing last sync / iCloud account
3. Tapping "Enable iCloud Sync" → dispatches `.enableSyncTapped`
4. Reducer calls `SyncClient.enableSync()` and streams `migrationProgress`
5. On completion, `DatabaseClient.container` is swapped to CloudKit-backed container

---

## Domain Layer

### `SyncClient`

```swift
@DependencyClient
public struct SyncClient: Sendable {
    public var isCloudKitAvailable: @Sendable () -> Bool = { false }
    public var enableSync: @Sendable () async throws -> Void
    public var migrationProgress: @Sendable () -> AsyncStream<Double> = { .finished }
}
```

### `UserSettingsKey` additions

| Key | Type | Purpose |
|-----|------|---------|
| `.isSubscribed` | `Bool` | Mock subscription gate; replaced by StoreKit later |
| `.isSyncEnabled` | `Bool` | Records that migration completed and CloudKit container is active |

---

## Core Layer

### `DatabaseClient` — swappable container

```swift
public struct DatabaseClient: Sendable {
    nonisolated(unsafe) public static var container: ModelContainer = Self.makeLocalContainer()
    public var modelContainer: @Sendable () -> ModelContainer = { DatabaseClient.container }
}
```

`nonisolated(unsafe)` is safe here because the swap happens exactly once (at subscription upgrade), coordinated on the main actor before any concurrent effects resume.

### `SyncClient+Live` — migration flow

```swift
enableSync: {
    // 1. Build CloudKit-backed ModelContainer
    let cloudContainer = try ModelContainer(
        for: schema,
        configurations: [ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.YOUR_CONTAINER_ID") // configure in App Store Connect + Entitlements
        )]
    )

    // 2. Read all entities from local container (ordered by dependency)
    //    SDTag, SDCategory → SDAccount → SDTransaction, SDRecurringTransaction
    //    Emit progress updates via AsyncStream continuation

    // 3. Insert into CloudKit container context, save in batches
    //    Each batch emits a progress update (0.0 – 1.0)

    // 4. Swap container
    DatabaseClient.container = cloudContainer

    // 5. Persist sync-enabled state
    userSettings.set(true, for: .isSyncEnabled)
}
```

**Migration order (dependency-safe):**
1. `SDTag`
2. `SDCategory`
3. `SDAccount`
4. `SDBudget`
5. `SDRecurringTransaction`
6. `SDTransaction` (depends on account, category, tags)

### CloudKit Schema Compatibility — SD Model changes

CloudKit requires all attributes to have default values or be Optional. Changes per model:

| Model | Required changes |
|-------|-----------------|
| `SDTransaction` | `String` fields → default `""`, `Date` fields → default `Date()`, `Int`/`Double` → default `0`. Remove any `@Attribute(.unique)`. |
| `SDAccount` | Same pattern. |
| `SDCategory` | Same pattern. |
| `SDBudget` | Same pattern. |
| `SDTag` | Same pattern. |
| `SDRecurringTransaction` | Same pattern. |

No `@Attribute(.unique)` constraints. CloudKit does not support unique enforcement — uniqueness must be enforced at the application layer.

---

## Features Layer

### `SyncSettingsFeature`

```swift
@Reducer
struct SyncSettingsFeature {
    @ObservableState
    struct State: Equatable {
        var isSubscribed: Bool = false
        var isSyncEnabled: Bool = false
        var isCloudKitAvailable: Bool = true
        var migrationState: MigrationState = .idle
        var lastSyncDate: Date? = nil

        enum MigrationState: Equatable {
            case idle
            case migrating(progress: Double)
            case completed
            case failed(String)
        }
    }

    enum Action {
        case task
        case enableSyncTapped
        case subscribeNowTapped           // mock: sets isSubscribed = true via UserSettingsClient
        case migrationProgressUpdated(Double)
        case migrationCompleted
        case migrationFailed(String)
    }

    // Dependencies: syncClient, userSettingsClient
}
```

### `SyncSettingsView` — three states

**Not subscribed:**
- Illustration + headline "Sync Across Devices"
- Feature bullets: cross-device sync, backup on iCloud
- "Subscribe Now" CTA button (mock: sets `isSubscribed = true`)

**Subscribed, sync not yet enabled:**
- Section header "iCloud Sync"
- Description of what enabling sync does
- "Enable iCloud Sync" button
- While migrating: `ProgressView` with percentage label

**Subscribed, sync enabled:**
- Row: "iCloud Sync" with green checkmark + "Enabled"
- Row: "iCloud Account" — show a checkmark only; fetching the actual Apple ID email requires `CKContainer.default().fetchUserRecordID` which is async and not necessary for V1

### Settings Integration

- `SettingsFeature.Destination` gains `.sync(SyncSettingsFeature.State)`
- `SettingsView` gains a row: icon `icloud.and.arrow.up`, label `String(localized: "settings_sync")`
- Localisation keys to add: `settings_sync`, `sync_title`, `sync_upsell_headline`, `sync_upsell_feature_devices`, `sync_upsell_feature_backup`, `sync_subscribe_now`, `sync_enable_button`, `sync_enabled_label`, `sync_migrating`, `sync_failed`

---

## Error Handling

| Error | Handling |
|-------|---------|
| iCloud not signed in | Show inline message "Please sign in to iCloud in Settings" — no migration attempted |
| Migration failure mid-way | Roll back: do not swap container, show `.failed` state with retry option |
| CloudKit container creation error | Show error message, keep local container unchanged |

---

## Testing

- `SyncClient.testValue` returns unimplemented stubs (default `@DependencyClient` behaviour)
- `SyncSettingsFeatureTests` covers all three view states and migration state transitions using `TestStore` with overridden `syncClient` and `userSettingsClient`
- Schema compatibility: existing `DatabaseClient.testValue` (in-memory) continues to work; no CloudKit needed in tests

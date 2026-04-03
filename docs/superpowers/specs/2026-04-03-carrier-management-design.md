# 載具管理功能設計

**Date:** 2026-04-03
**Status:** Approved

## Overview

在 Settings 頁新增「載具管理」入口，讓使用者儲存與管理台灣政府電子發票載具資訊（手機條碼載具、自然人憑證條碼）。純儲存/查閱用途——記帳流程不關聯載具。查閱時可複製條碼字串，也可展開顯示 QR Code 圖片。

---

## Goals

- 支援兩種政府發票載具類型的新增、編輯、刪除
- 列表頁 inline 展開顯示條碼字串（複製按鈕）與 QR Code 圖片
- 嚴格的格式驗證，錯誤以 inline 訊息顯示
- 完全遵循現有 Clean Architecture + TCA 模式

## Non-Goals

- 與交易記錄關聯（記錄某筆消費用了哪張載具）
- 整合財政部電子發票 API 自動拉取發票
- 支援非政府發票的店家載具或第三方載具

---

## Architecture

```
Domain/
├── Entities/Carrier.swift              # New: Carrier struct + CarrierType enum
├── Clients/CarrierClient.swift         # New: @DependencyClient interface
Core/
├── Persistence/Models/SDCarrier.swift  # New: SwiftData model
├── Persistence/Models/SDCarrier+Mapping.swift  # New: DomainConvertible
├── Clients/CarrierClient+Live.swift    # New: live implementation
├── Persistence/DatabaseClient.swift    # Modified: add SDCarrier to Schema
Features/
├── CarrierManagement/
│   ├── CarrierManagementFeature.swift  # New: TCA Reducer
│   ├── CarrierManagementView.swift     # New: list + inline expand
│   ├── AddEditCarrierFeature.swift     # New: TCA Reducer
│   └── AddEditCarrierView.swift        # New: add/edit form
├── Settings/SettingsFeature.swift      # Modified: add .carrierManagement destination
└── Settings/SettingsView.swift         # Modified: add carrier row in 管理 section
```

---

## Domain Layer

### `Carrier`

```swift
public struct Carrier: Identifiable, Equatable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String        // 使用者自訂標籤；空白時 UI 顯示類型預設名稱
    public var type: CarrierType
    public var barcode: String     // 完整條碼字串，含開頭斜線
    public var createdAt: Date
}

public enum CarrierType: String, Codable, CaseIterable, Sendable {
    case phoneBarcodeCarrier       // 手機條碼載具
    case citizenDigitalCertificate // 自然人憑證條碼
}
```

### 格式驗證規則

| 類型 | 正規表達式 | 範例 | 長度 |
|------|-----------|------|------|
| 手機條碼載具 | `/[A-Z0-9+\-.]{7}` | `/ABC1234` | 8 字元 |
| 自然人憑證條碼 | `/P[A-Z0-9]{16}` | `/PA1B2C3D4E5F6G7H8` | 18 字元 |

### `CarrierClient`

```swift
@DependencyClient
public struct CarrierClient: Sendable {
    public var fetchAll: @Sendable () async throws -> [Carrier]
    public var add: @Sendable (Carrier) async throws -> Void
    public var update: @Sendable (Carrier) async throws -> Void
    public var delete: @Sendable (Carrier.ID) async throws -> Void
}

extension DependencyValues {
    public var carrierClient: CarrierClient {
        get { self[CarrierClient.self] }
        set { self[CarrierClient.self] = newValue }
    }
}
```

---

## Core Layer

### `SDCarrier`

```swift
@Model
public final class SDCarrier {
    public var id: String = ""
    public var name: String = ""
    public var typeRaw: String = ""
    public var barcode: String = ""
    public var createdAt: Date = Date()
}
```

- 所有欄位有預設值，符合 CloudKit 相容要求
- 無 `@Attribute(.unique)` 限制
- 加入 `DatabaseClient.liveValue` 與 `testValue` 的 `Schema` 陣列

### `SDCarrier+Mapping`

- `toDomain() -> Carrier`：`typeRaw` → `CarrierType(rawValue:)`
- `static func from(_ carrier: Carrier, context:) -> SDCarrier`

### `CarrierClient+Live`

使用 `databaseClient` helpers：
- `fetchAll`：`databaseClient.fetch(FetchDescriptor<SDCarrier>())`
- `add`：`databaseClient.add(carrier, as: SDCarrier.self)`
- `update`：`databaseClient.update(matching:mutation:)`
- `delete`：`databaseClient.deleteFirst(matching:validation:)`

---

## Features Layer

### `CarrierManagementFeature`

```swift
@ObservableState
struct State: Equatable {
    var carriers: [Carrier] = []
    var isLoading: Bool = false
    var expandedCarrierId: Carrier.ID? = nil
    @Presents var addEdit: AddEditCarrierFeature.State?
}

enum Action {
    case task
    case carriersLoaded([Carrier])
    case carrierRowTapped(Carrier.ID)     // toggle inline expand
    case copyBarcodeTapped(String)        // copy to UIPasteboard
    case addTapped
    case deleteTapped(Carrier.ID)
    case addEdit(PresentationAction<AddEditCarrierFeature.Action>)
}
```

**展開行為：** 點同一列收合，點不同列切換。同一時間只有一列展開。

**展開後顯示：**
1. 條碼字串（monospaced font）+ 複製按鈕（`doc.on.doc` icon）
2. QR Code 圖片（由 `CoreImage.CIFilter(name: "CIQRCodeGenerator")` 生成）
3. QR Code 生成失敗時 fallback 為僅顯示文字 + 複製按鈕

### `AddEditCarrierFeature`

```swift
@ObservableState
struct State: Equatable {
    var mode: Mode                   // .add / .edit(Carrier)
    var name: String = ""
    var type: CarrierType = .phoneBarcodeCarrier
    var barcode: String = ""
    var barcodeError: String? = nil
    var isSaving: Bool = false

    var canSave: Bool { barcodeError == nil && !barcode.isEmpty }

    enum Delegate { case saved }
}

enum Action: BindableAction {
    case binding(BindingAction<State>)
    case barcodeChanged(String)      // 即時驗證
    case saveTapped
    case saveResponse(TaskResult<Void>)
    case delegate(Delegate)
}
```

**驗證邏輯：** 每次 `barcodeChanged` 時對應目前 `type` 執行正規表達式驗證，更新 `barcodeError`。名稱留空時儲存後自動帶入類型中文名稱。

### Settings 整合

**`SettingsFeature.Destination`** 新增：
```swift
case carrierManagement(CarrierManagementFeature)
```

**`SettingsView` 管理 section** 新增列（放在 tagManagement 之後）：
```swift
Button { store.send(.carrierManagementTapped) } label: {
    settingsRow(
        icon: "creditcard.and.123",
        iconColor: Color.Design.brandAccent,
        label: String(localized: "settings_carrier_management"),
        trailing: chevron
    )
}
```

---

## Localisation Keys

| Key | 中文建議值 |
|-----|-----------|
| `settings_carrier_management` | 載具管理 |
| `carrier_management_title` | 我的載具 |
| `carrier_type_phone_barcode` | 手機條碼載具 |
| `carrier_type_citizen_cert` | 自然人憑證條碼 |
| `carrier_name_label` | 名稱（選填） |
| `carrier_barcode_label` | 條碼 |
| `carrier_barcode_error_phone` | 格式應為 /XXXXXXX（斜線加 7 位英數字）|
| `carrier_barcode_error_cert` | 格式應為 /P 加 16 位英數字 |
| `carrier_copy_success` | 已複製 |
| `carrier_empty_state` | 尚未新增載具 |

---

## Error Handling

| 情境 | 處理方式 |
|------|---------|
| 條碼格式錯誤 | inline 錯誤訊息，Save 按鈕 disabled |
| 名稱欄位空白 | 儲存時自動填入類型預設名稱 |
| 無任何載具 | `EmptyStateView`（複用 Common 元件） |
| QR Code 生成失敗 | fallback 只顯示文字 + 複製按鈕，不顯示錯誤 |
| Core 層操作失敗 | 記錄至 console，UI 回復至前一狀態 |

---

## Testing

**`CarrierManagementFeatureTests`（Swift Testing）：**
- `.task` 載入載具列表
- 展開/收合 inline 展開
- 刪除載具

**`AddEditCarrierFeatureTests`（Swift Testing）：**
- 手機條碼載具格式驗證（合法、不合法多種情境）
- 自然人憑證格式驗證（合法、不合法多種情境）
- 新增流程（saveTapped → delegate(.saved)）
- 編輯流程（預填資料 → 修改 → save）
- 名稱空白時自動填入預設名稱

**Domain tests：**
- `Carrier` Equatable / Hashable / Codable round-trip
- `CarrierType.allCases` 完整性
- `CarrierClient.testValue` 可透過 `DependencyValues` key path 存取

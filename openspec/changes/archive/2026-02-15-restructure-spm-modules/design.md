## Context

NeuLedger 目前的專案結構正處於「半模組化」狀態：

- `Features/` 套件已建立（Swift 6.2、iOS 26、依賴 TCA），`@main` 入口已遷移至此
- `NeuLedger/` 主 Target 仍包含 3 個 Glass UI 元件（未搬遷）、空殼 `NeuLedgerApp.swift`、Asset Catalog、Info.plist、Entitlements
- `project.pbxproj` 引用了不存在的 `NeuLedgerUI` packageProductDependency
- Rules.md 定義了三層架構方向（Base → Infrastructure → Features），但尚未落地

現有 Glass 元件引用了未定義的型別：`GlassButtonStyle`、`Color.Design.*`、`Font.Design.*`，代表有一批 Design Token 和 ButtonStyle 定義從未被建立。

## Goals / Non-Goals

**Goals:**
- 建立符合 Rules.md 三層架構的 SPM 本地套件結構
- 移除 `NeuLedgerUI` 幽靈引用，清理 pbxproj
- 以 Pure Code 建立完整的 Design Token 系統（Color + Font），脫離 Asset Catalog 依賴
- 搬遷 Glass 元件至正確的 SPM 層級，補齊缺失的型別定義
- 建立嚴格的單向依賴：Base ← Infrastructure ← Features ← App
- 各套件可獨立編譯（聚焦編譯 / Micro-App 開發體驗）

**Non-Goals:**
- 不處理 Domain Model、Data Layer 或 Networking 的模組化（那些是後續工作）
- 不建立遠端 SPM 套件（維持本地 Monorepo 策略）
- 不移除 Asset Catalog 本身（AppIcon、AccentColor 仍需保留在主 Target）
- 不重構 Features 套件的內部結構（TCA 架構維持不變）
- 不處理 Navigation 套件的建立（屬於後續進階解耦）

## Decisions

### Decision 1: 套件拆分方案 — 兩個本地套件

**選擇：** 建立 `DesignTokens` (Base 層) 套件，Glass 元件直接放入現有 `Features` 套件中

**方案比較：**

| 方案 | 描述 | 優點 | 缺點 |
|------|------|------|------|
| A) 三個獨立套件 | `DesignTokens` + `DesignComponents` + `Features` | 層級最清晰 | 早期過度拆分，維護成本高 |
| **B) 兩個套件 ✅** | `DesignTokens` + `Features`（Glass 元件放 Features 內） | 務實、減少套件數量、Glass 元件與 Feature Views 強相關 | Infrastructure 層與 Features 層合併 |
| C) 單一套件 | 全部放 `Features` | 最簡單 | 無法獨立編譯 Token，違反 Base 層零依賴原則 |

**理由：**
- `DesignTokens` 是純值定義（Color、Font extension），**零依賴**、極度輕量，適合獨立為 Base 層
- Glass 元件（GlassButton、GlassCard、GlassHeader）目前數量少，且僅被 Feature Views 消費，放入 `Features` 更務實
- 遵循 Rules.md 建議：「從最明顯的 Base 開始，逐步提取 Infrastructure」
- 未來若 Glass 元件需跨套件共享（如 Widget），可再提取為獨立 `DesignComponents` 套件

### Decision 2: DesignTokens 套件的位置與結構

**選擇：** 在專案根目錄建立 `DesignTokens/` 套件

```
NeuLedger/                          (project root)
├── DesignTokens/                   (Base 層 — 本地 SPM 套件)
│   ├── Package.swift
│   └── Sources/DesignTokens/
│       ├── ColorTokens.swift       # Color.Design extension
│       └── FontTokens.swift        # Font.Design extension
├── Features/                       (Features 層 — 現有套件，新增 Glass 元件)
│   ├── Package.swift               # 新增 dependency: DesignTokens
│   └── Sources/Features/
│       ├── App.swift
│       ├── Components/
│       │   ├── GlassButton.swift
│       │   ├── GlassButtonStyle.swift  # 新建
│       │   ├── GlassCard.swift
│       │   └── GlassHeader.swift
│       └── ...
├── NeuLedger/                      (App Target — Composer)
│   ├── NeuLedgerApp.swift          # 空殼或移除
│   ├── Assets.xcassets/            # 僅保留 AppIcon、AccentColor
│   ├── Info.plist
│   └── NeuLedger.entitlements
└── NeuLedger.xcodeproj/
```

**理由：**
- 與 `Features/` 平行放置，路徑清晰
- 本地 SPM 套件使用相對路徑引用：`Features/Package.swift` 中用 `.package(path: "../DesignTokens")`
- 主 App Target 透過 Xcode 的 packageProductDependency 引用兩個套件

### Decision 3: Color Token 改用 Pure Code

**選擇：** 使用 `Color(red:green:blue:)` 搭配 Light/Dark mode 判斷，定義在 `DesignTokens` 套件中

```swift
// ColorTokens.swift
import SwiftUI

public extension Color {
    enum Design {
        /// Income: Light #34C759 / Dark #30D158
        public static var incomeGreen: Color {
            Color(light: Color(red: 0.204, green: 0.780, blue: 0.349),
                  dark: Color(red: 0.188, green: 0.820, blue: 0.345))
        }
        // ... 其他 Token
    }
}
```

**替代方案考量：**

| 方案 | 優點 | 缺點 |
|------|------|------|
| Asset Catalog Color Set | Xcode 視覺化編輯 | 套件無法存取主 Target 的 xcassets |
| 套件內嵌 xcassets (Bundle.module) | 仍用 Asset Catalog | 增加套件複雜度、命名衝突風險 |
| **Pure Code ✅** | 零資源依賴、型別安全、Git 友善 | 無視覺化編輯 |

**理由：**
- 用戶明確要求不依賴 Asset Catalog
- Pure Code 方式讓 `DesignTokens` 套件保持零資源依賴，真正輕量
- `Color(light:dark:)` 是 iOS 17+ 的原生 API，自動適配 Light/Dark mode

### Decision 4: GlassButtonStyle 的實作方式

**選擇：** 建立 `GlassButtonStyle` 作為 `ButtonStyle` 協議的實作，使用 iOS 26 的 `.glassEffect()` API

```swift
// GlassButtonStyle.swift
import SwiftUI

public struct GlassButtonStyle: ButtonStyle {
    let tint: Glass.Tint

    public init(_ tint: Glass.Tint = .clear) {
        self.tint = tint
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassEffect(
                Glass(tint)
                    .interactive(),
                in: Capsule()
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    public static func glass(_ tint: Glass.Tint = .clear) -> GlassButtonStyle {
        GlassButtonStyle(tint)
    }
}
```

**理由：**
- `GlassButton.swift` 已經在使用 `GlassButtonStyle = .glass(.clear)` 語法，需要一個 `static func glass` 的 extension
- 遵循 design-system spec 中定義的 Liquid Glass 規範
- 使用 iOS 26 原生的 `Glass` 和 `.glassEffect()` API

### Decision 5: pbxproj 清理策略

**選擇：** 直接編輯 `project.pbxproj`，移除 `NeuLedgerUI` 相關的 3 行引用

需移除的引用：
1. `PBXBuildFile`: `A249D8C92F419BCC00CBA03D /* NeuLedgerUI in Frameworks */`
2. `PBXFrameworksBuildPhase` files 中的 `NeuLedgerUI` 條目
3. `XCSwiftPackageProductDependency`: `A2CF1C2F2F40ABE000BDE292 /* NeuLedgerUI */`
4. `PBXNativeTarget.packageProductDependencies` 中的 `NeuLedgerUI` 條目

**理由：**
- 該套件從未被建立，這些是無效引用
- 需同時新增 `DesignTokens` 的 packageProductDependency（建議透過 Xcode UI 操作，避免手動編輯 pbxproj 出錯）

### Decision 6: 主 App Target 的 Composer 角色

**選擇：** `NeuLedger/` 主 Target 精簡為以下內容：

| 保留 | 說明 |
|------|------|
| `NeuLedgerApp.swift` | 空殼（`@main` 在 Features 套件） |
| `Assets.xcassets` | 僅保留 `AppIcon`、`AccentColor`（系統級資源） |
| `Info.plist` | App 層級配置 |
| `NeuLedger.entitlements` | APS + CloudKit 權限 |

**理由：**
- `@main` 已在 `Features/Sources/Features/App.swift`，主 Target 僅需作為「殼」
- `AppIcon` 必須在主 Target 的 Asset Catalog 中
- `AccentColor` 可保留在主 Target（系統級 tint），Design Token 的其他顏色用 Pure Code

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| 手動編輯 pbxproj 可能破壞專案 | 高 — Xcode 無法開啟 | 優先使用 Xcode UI 操作加減套件依賴；若手動編輯，先 git commit 備份 |
| `@main` 在 SPM 套件中可能有 Xcode 限制 | 中 — 可能需要特殊的 target 配置 | 現有結構已驗證可行（`Features/App.swift` 已有 `@main`） |
| Pure Code Color 需手動維護 hex 對照 | 低 — 顏色數量少 | 在 `ColorTokens.swift` 中以註解標記 hex 值，便於對照 |
| Glass 元件放入 Features 後，未來跨套件共享需再次搬遷 | 低 — 目前無此需求 | 設計為 `public`，未來提取時只需搬移檔案 + 調整 Package.swift |
| `DesignTokens` 套件需與 Features 套件版本同步 | 低 — 本地套件隨改隨用 | 本地套件的核心優勢：同倉庫、即時編譯、無版本管理負擔 |

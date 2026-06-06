# Watch 載具功能實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 watchOS app 加入電子發票載具唯讀檢視 — 垂直翻頁切換（記帳 ↔ 載具）、智慧快路徑載具頁、直式 Code 128 全螢幕條碼。

**Architecture:** 載具經既有 `WatchContextSnapshot` 全量鏡像管線送上 watch（`carriers` optional 新欄位，reactive save 觸發零管線改動）；watch 端純 Swift Code 128 編碼器自繪條碼（watchOS 無 CIFilter）；新 root `WatchAppFeature` 以垂直 TabView 組合既有 `WatchRecordFeature` 與新 `WatchCarrierFeature`。

**Tech Stack:** Swift 6 / TCA 1.23 / SwiftUI Canvas / Swift Testing / 本地 SPM package（Domain・Core・Common・WatchFeatures）

**Spec:** `docs/superpowers/specs/2026-06-05-watch-carrier-design.md`（已核可）

---

## 模組邊界須知（每個 task 都適用）

- `WatchFeatures` SPM target **只依賴 TCA + Domain + Common**，絕不 import Core / SwiftData / Application。載具資料只能從 `WatchCacheStore`（snapshot cache）讀。
- `Carrier` / `CarrierType` / `WatchContextSnapshot` 在 **Domain**，watch 可直接 import。
- `CarrierClient`（含 `listAll`）介面在 Domain、live 在 Application — **只有 iPhone 端的 `WatchContextBuilder`（Core）能用它**；watch 端不行。
- 顏色一律 `Color.Design`（hex init 是 fileprivate）；字體一律 `Font.Design`；面向使用者字串一律 `String(localized:)`。
- watch 端字串放 `NeuLedgerWatch Watch App/Localizable.xcstrings`（**xcodeproj target 的檔案，不是 SPM package 內**），key 用 `watch_` 前綴。
- xcodeproj 使用 synchronized folder groups：在 `NeuLedgerTests/` / `NeuLedgerWatchTests/` 資料夾新增檔案會自動進 target，**不需改 pbxproj**。若 build 報 unknown file，再檢查 target membership。
- `Account.ID` 是 `String`；`Carrier.ID` 是 `UUID`。

## 測試指令（全計畫共用）

```bash
# iOS 測試（單一 suite）
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/<SuiteName>

# watch 測試（單一 suite）
xcodebuild test -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -only-testing:NeuLedgerWatchTests/<SuiteName>

# 完整驗證（Task 9）：兩個 scheme 都不帶 -only-testing 跑全量
```

所有 commit 訊息 subject 結尾加 `[ci skip]`（專案慣例：CI opt-in）。

---

### Task 1: Code 128 編碼器（Common，純 Swift）

**Files:**
- Create: `Features/Sources/Common/Components/Code128.swift`
- Test: `NeuLedgerTests/Tests/CommonTests/Code128Tests.swift`

- [ ] **Step 1: 寫失敗測試**

建立 `NeuLedgerTests/Tests/CommonTests/Code128Tests.swift`：

```swift
import Foundation
import Testing
@testable import Common

@Suite("Code128 Tests")
struct Code128Tests {

    @Test("Widths table is structurally valid per ISO/IEC 15417")
    func tableIntegrity() {
        #expect(Code128.widths.count == 107)
        for (index, entry) in Code128.widths.enumerated() {
            let widths = entry.compactMap(\.wholeNumberValue)
            #expect(widths.count == entry.count, "non-digit char in entry \(index)")
            let total = widths.reduce(0, +)
            if index == 106 {
                #expect(total == 13, "stop symbol must span 13 modules")
            } else {
                #expect(total == 11, "symbol \(index) must span 11 modules")
            }
            // Code 128 自檢特性：每個符號的 bar 模組總寬為偶數。
            let barTotal = stride(from: 0, to: widths.count, by: 2)
                .map { widths[$0] }
                .reduce(0, +)
            #expect(barTotal.isMultiple(of: 2), "bar parity broken at \(index)")
        }
    }

    @Test("Phone-barcode carrier encodes in pure code B with checksum 14")
    func phoneCarrierVector() {
        // '/'=15 'A'=33 'B'=34 '1'=17 '2'=18 '+'=11 'C'=35 'D'=36（ASCII-32）
        // 數字串長度 2 < 4 → 全程 code B。
        // checksum = 104 + 15*1+33*2+34*3+17*4+18*5+11*6+35*7+36*8 = 1044 → 1044 % 103 = 14
        #expect(Code128.codeValues(for: "/AB12+CD")
                == [104, 15, 33, 34, 17, 18, 11, 35, 36, 14, 106])
        // 10 個 11-module 符號 + 13-module stop = 123
        #expect(Code128.modules(for: "/AB12+CD")?.count == 123)
    }

    @Test("Citizen-certificate carrier switches to code C for the 14-digit run")
    func certCarrierVector() {
        // 'A'=33 'B'=34，後接 14 位數字（≥4 且偶數）→ switch C(99)，七組兩位數。
        // checksum = 104 + 33*1+34*2+99*3+12*4+34*5+56*6+78*7+90*8+12*9+34*10
        //          = 2770 → 2770 % 103 = 92
        #expect(Code128.codeValues(for: "AB12345678901234")
                == [104, 33, 34, 99, 12, 34, 56, 78, 90, 12, 34, 92, 106])
        // 12 個 11-module 符號 + 13-module stop = 145
        #expect(Code128.modules(for: "AB12345678901234")?.count == 145)
    }

    @Test("All-digit input starts directly in code C")
    func allDigitsStartsInC() {
        // checksum = 105 + 12*1 + 34*2 = 185 → 185 % 103 = 82
        #expect(Code128.codeValues(for: "1234") == [105, 12, 34, 82, 106])
    }

    @Test("Modules begin and end with a bar")
    func modulesBoundedByBars() {
        let modules = Code128.modules(for: "/AB12+CD")
        #expect(modules?.first == true)
        #expect(modules?.last == true)
    }

    @Test("Rejects empty and non-ASCII input")
    func rejectsInvalidInput() {
        #expect(Code128.modules(for: "") == nil)
        #expect(Code128.modules(for: "載具") == nil)
        #expect(Code128.codeValues(for: "") == nil)
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:NeuLedgerTests/Code128Tests`
Expected: **編譯失敗**，`cannot find 'Code128' in scope`

- [ ] **Step 3: 實作編碼器**

建立 `Features/Sources/Common/Components/Code128.swift`：

```swift
import Foundation

/// Pure-Swift Code 128 encoder (code sets B and C with digit-run
/// optimization). Produces the module pattern (bar = `true`, space =
/// `false`) for a barcode body — start code, data, checksum, stop —
/// without quiet zones (the rendering view adds those).
///
/// Exists because watchOS has no `CIFilter` barcode generators. Encoding
/// follows ISO/IEC 15417; `widths` is the standard 107-symbol table.
public enum Code128 {

    /// Widths table for symbols 0...106. Each entry alternates bar/space
    /// widths starting with a bar; symbols 0...105 span 11 modules, the
    /// stop symbol (106) spans 13.
    static let widths: [String] = [
        "212222", "222122", "222221", "121223", "121322", // 0-4
        "131222", "122213", "122312", "132212", "221213", // 5-9
        "221312", "231212", "112232", "122132", "122231", // 10-14
        "113222", "123122", "123221", "223211", "221132", // 15-19
        "221231", "213212", "223112", "312131", "311222", // 20-24
        "321122", "321221", "312212", "322112", "322211", // 25-29
        "212123", "212321", "232121", "111323", "131123", // 30-34
        "131321", "112313", "132113", "132311", "211313", // 35-39
        "231113", "231311", "112133", "112331", "132131", // 40-44
        "113123", "113321", "133121", "313121", "211331", // 45-49
        "231131", "213113", "213311", "213131", "311123", // 50-54
        "311321", "331121", "312113", "312311", "332111", // 55-59
        "314111", "221411", "431111", "111224", "111422", // 60-64
        "121124", "121421", "141122", "141221", "112214", // 65-69
        "112412", "122114", "122411", "142112", "142211", // 70-74
        "241211", "221114", "413111", "241112", "134111", // 75-79
        "111242", "121142", "121241", "114212", "124112", // 80-84
        "124211", "411212", "421112", "421211", "212141", // 85-89
        "214121", "412121", "111143", "111341", "131141", // 90-94
        "114113", "114311", "411113", "411311", "113141", // 95-99
        "114131", "311141", "411131", "211412", "211214", // 100-104
        "211232",                                          // 105
        "2331112",                                         // 106 (stop)
    ]

    private static let startB = 104
    private static let startC = 105
    private static let switchToB = 100
    private static let switchToC = 99
    private static let stop = 106

    /// Encodes `text` into module runs (`true` = bar). Returns `nil` when
    /// `text` is empty or contains characters outside printable ASCII
    /// (32...126).
    public static func modules(for text: String) -> [Bool]? {
        guard let values = codeValues(for: text) else { return nil }
        var modules: [Bool] = []
        for value in values {
            var isBar = true
            for widthChar in widths[value] {
                let width = widthChar.wholeNumberValue ?? 0
                modules.append(contentsOf: Array(repeating: isBar, count: width))
                isBar.toggle()
            }
        }
        return modules
    }

    /// Symbol-value sequence — start, data (B/C optimized), checksum,
    /// stop. Internal so tests can assert exact symbol sequences.
    ///
    /// Set-selection heuristic (deterministic, optimal for the two
    /// carrier formats this app stores; not globally optimal):
    /// - start in C when the leading digit run is ≥ 4 and even,
    /// - in B, switch to C when the digit run at the cursor is ≥ 4 and even,
    /// - in C, consume digit pairs while ≥ 2 digits remain, else switch to B.
    static func codeValues(for text: String) -> [Int]? {
        guard !text.isEmpty else { return nil }
        let scalars = Array(text.unicodeScalars)
        guard scalars.allSatisfy({ (32...126).contains($0.value) }) else { return nil }

        func digitRun(from index: Int) -> Int {
            var count = 0
            while index + count < scalars.count,
                  (48...57).contains(scalars[index + count].value) {
                count += 1
            }
            return count
        }

        let leadingDigits = digitRun(from: 0)
        var inSetC = leadingDigits >= 4 && leadingDigits.isMultiple(of: 2)
        var values: [Int] = [inSetC ? startC : startB]
        var index = 0

        while index < scalars.count {
            if inSetC {
                if digitRun(from: index) >= 2 {
                    let tens = Int(scalars[index].value) - 48
                    let ones = Int(scalars[index + 1].value) - 48
                    values.append(tens * 10 + ones)
                    index += 2
                } else {
                    values.append(switchToB)
                    inSetC = false
                }
            } else {
                let run = digitRun(from: index)
                if run >= 4 && run.isMultiple(of: 2) {
                    values.append(switchToC)
                    inSetC = true
                } else {
                    values.append(Int(scalars[index].value) - 32)
                    index += 1
                }
            }
        }

        var checksum = values[0]
        for (position, value) in values.dropFirst().enumerated() {
            checksum += (position + 1) * value
        }
        values.append(checksum % 103)
        values.append(stop)
        return values
    }
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:NeuLedgerTests/Code128Tests`
Expected: PASS（6 tests）。若 `tableIntegrity` 失敗，逐條核對 widths 表的該 index（測試訊息會指出哪一格）。

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Common/Components/Code128.swift NeuLedgerTests/Tests/CommonTests/Code128Tests.swift
git commit -m "feat(common): add pure-Swift Code 128 encoder with B/C optimization [ci skip]"
```

---

### Task 2: 條碼色票 token + Code128BarcodeView

**Files:**
- Modify: `Features/Sources/Common/DesignSystem/Color+extension.swift`（在 `// MARK: - LedgerCut Icon Palette` 區塊之後、`enum Design` 結尾 `}` 之前加新 MARK）
- Create: `Features/Sources/Common/Components/Code128BarcodeView.swift`

- [ ] **Step 1: 加色票 token**

在 `Color+extension.swift` 的 `Design` enum 內（`ledgerCutChalkAccent` 那行之後）加：

```swift
        // MARK: - Barcode (scannability-critical, theme-invariant)
        // 條碼對比不得隨 Light/Dark 變動 — 永遠純白底、純黑條。
        public static let barcodeSurface = Color(hexLiteral: "#FFFFFF")
        public static let barcodeInk = Color(hexLiteral: "#000000")
```

- [ ] **Step 2: 建立條碼 View**

建立 `Features/Sources/Common/Components/Code128BarcodeView.swift`：

```swift
import SwiftUI

/// Renders a Code 128 module pattern as crisp vector bars. The caller
/// provides pre-encoded modules (see `Code128.modules(for:)`) and is
/// responsible for quiet-zone padding and the white backdrop
/// (`Color.Design.barcodeSurface`).
public struct Code128BarcodeView: View {

    public enum Orientation: Sendable {
        /// Code reads left-to-right (bars are vertical strips).
        case horizontal
        /// Code reads top-to-bottom — rotated 90° to maximize module
        /// width on tall, narrow screens like Apple Watch.
        case vertical
    }

    private let modules: [Bool]
    private let orientation: Orientation

    public init(modules: [Bool], orientation: Orientation = .horizontal) {
        self.modules = modules
        self.orientation = orientation
    }

    public var body: some View {
        Canvas { context, size in
            guard modules.isEmpty == false else { return }
            let count = CGFloat(modules.count)
            for (index, isBar) in modules.enumerated() where isBar {
                let rect: CGRect
                switch orientation {
                case .horizontal:
                    let moduleWidth = size.width / count
                    rect = CGRect(
                        x: CGFloat(index) * moduleWidth, y: 0,
                        width: moduleWidth, height: size.height
                    )
                case .vertical:
                    let moduleHeight = size.height / count
                    rect = CGRect(
                        x: 0, y: CGFloat(index) * moduleHeight,
                        width: size.width, height: moduleHeight
                    )
                }
                context.fill(Path(rect), with: .color(Color.Design.barcodeInk))
            }
        }
    }
}
```

- [ ] **Step 3: 編譯驗證（iOS + watch 兩平台）**

Run:
```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  && xcodebuild build -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```
Expected: 兩個 BUILD SUCCEEDED（Common 是跨平台 target，Canvas/Color 在 watchOS 可用）

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Common/DesignSystem/Color+extension.swift Features/Sources/Common/Components/Code128BarcodeView.swift
git commit -m "feat(common): add barcode color tokens and Code128BarcodeView canvas renderer [ci skip]"
```

---

### Task 3: `WatchContextSnapshot.carriers` 欄位 + 向後相容測試

**Files:**
- Modify: `Features/Sources/Domain/Entities/WatchContextSnapshot.swift`
- Modify: `NeuLedgerWatchTests/WatchCacheStoreTests.swift`

- [ ] **Step 1: 寫失敗測試**

在 `WatchCacheStoreTests.swift` 中：

(a) 把既有 `makeSnapshot` helper 加 `carriers` 參數（預設 `nil`，既有測試不變）：

```swift
    private func makeSnapshot(
        todayTotal: Decimal = 480,
        defaultAccountId: UUID = UUID(),
        carriers: [Carrier]? = nil
    ) -> WatchContextSnapshot {
        WatchContextSnapshot(
            categories: [
                Category(id: UUID(), name: "Food", icon: "fork.knife",
                         color: "#FF9500", type: .expense, sortOrder: 0, isDefault: true)
            ],
            accounts: [
                Account(id: defaultAccountId, name: "Cash", type: .cash,
                        icon: "banknote", color: "#34C759", sortOrder: 0,
                        isArchived: false, createdAt: Date(timeIntervalSince1970: 0))
            ],
            defaultAccountId: defaultAccountId,
            todayTotal: todayTotal,
            todayCount: 2,
            monthBudgetProgress: 0.62,
            snapshotAt: Date(timeIntervalSince1970: 1_700_000_000),
            carriers: carriers
        )
    }
```

> 注意：`makeSnapshot` 內的 `defaultAccountId: UUID = UUID()` 是既有寫法 — `Account.ID` 其實是 `String`，這裡能編譯是因為既有檔案如此（先別動它；若編譯失敗代表既有 helper 用了 `UUID` 變數餵 `String` 參數，照既有寫法保留）。

(b) 在 suite 內新增兩個測試：

```swift
    @Test("Snapshot with carriers round-trips")
    func carriersRoundTrip() {
        let (store, _) = makeStore()
        let carrier = Carrier(
            id: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!,
            name: "手機條碼", type: .phoneBarcodeCarrier,
            barcode: "/AB12+CD",
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let original = makeSnapshot(carriers: [carrier])
        store.save(original)
        #expect(store.load()?.carriers == [carrier])
    }

    @Test("Legacy snapshot JSON without carriers key decodes with nil carriers")
    func legacyJSONDecodesWithNilCarriers() {
        let (store, defaults) = makeStore()
        // 舊版 iPhone wire format：無 carriers key。Date 以
        // timeIntervalSinceReferenceDate 編碼（JSONDecoder 預設）。
        let legacyJSON = """
        {"categories":[],"accounts":[],"defaultAccountId":"ACC-1",\
        "todayTotal":0,"todayCount":0,"snapshotAt":700000000}
        """
        defaults.set(Data(legacyJSON.utf8), forKey: "watch.context_snapshot.v1")
        let loaded = store.load()
        #expect(loaded != nil)
        #expect(loaded?.carriers == nil)
    }
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `xcodebuild test -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -only-testing:NeuLedgerWatchTests/WatchCacheStoreTests`
Expected: **編譯失敗**，`extra argument 'carriers' in call`

- [ ] **Step 3: 加欄位**

`WatchContextSnapshot.swift` — 在 `snapshotAt` property 宣告後加：

```swift
    /// E-invoice carriers mirrored for the Watch carrier page, in the
    /// iPhone list order. `nil` when the snapshot came from an older
    /// iPhone build without carrier support (Watch shows a sync hint);
    /// empty when the user genuinely has none (Watch shows add-on-iPhone
    /// guidance). Optional so legacy cached JSON keeps decoding.
    public let carriers: [Carrier]?
```

init 簽名在 `snapshotAt: Date` 之後加最後一個參數（帶預設值，既有呼叫端零修改）：

```swift
    public init(
        categories: [Category],
        accounts: [Account],
        defaultAccountId: Account.ID,
        todayTotal: Decimal,
        todayCount: Int,
        monthBudgetProgress: Double?,
        snapshotAt: Date,
        carriers: [Carrier]? = nil
    ) {
        self.categories = categories
        self.accounts = accounts
        self.defaultAccountId = defaultAccountId
        self.todayTotal = todayTotal
        self.todayCount = todayCount
        self.monthBudgetProgress = monthBudgetProgress
        self.snapshotAt = snapshotAt
        self.carriers = carriers
    }
```

（synthesized Codable 對 optional 用 `decodeIfPresent` → 舊 JSON 缺 key 自動解成 `nil`，不需手寫 `init(from:)`。）

- [ ] **Step 4: 跑測試確認通過**

Run: 同 Step 2 指令
Expected: PASS（既有 4 + 新 2 = 6 tests）

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Domain/Entities/WatchContextSnapshot.swift NeuLedgerWatchTests/WatchCacheStoreTests.swift
git commit -m "feat(domain): mirror carriers in WatchContextSnapshot (optional, backward-compatible) [ci skip]"
```

---

### Task 4: `WatchContextBuilder` 打包載具

**Files:**
- Modify: `Features/Sources/Core/Adapters/Watch/WatchContextBuilder.swift`
- Modify: `NeuLedgerTests/Tests/CoreTests/WatchContextBuilderTests.swift`

- [ ] **Step 1: 寫失敗測試**

`WatchContextBuilderTests.swift`：

(a) **兩個既有測試**的 `withDependencies` 區塊各加一行 stub（`@DependencyClient` 介面預設值不是 test stub — 血淚規則①）：

```swift
            $0.carrierClient.listAll = { @Sendable in [] }
```

(b) 既有 `aggregatesTodaysExpensesOnly` 測試的 `#expect` 區塊末尾加：

```swift
        #expect(snapshot.carriers == [])
```

(c) 新增測試：

```swift
    @Test("Snapshot mirrors carriers from carrierClient in list order")
    func mirrorsCarriersInListOrder() async throws {
        let container = try await makeSeededContainer()
        let phone = Carrier(
            name: "手機條碼", type: .phoneBarcodeCarrier, barcode: "/AB12+CD"
        )
        let cert = Carrier(
            name: "自然人憑證", type: .citizenDigitalCertificate,
            barcode: "AB12345678901234"
        )

        let snapshot = try await withDependencies {
            $0.calendar = Calendar(identifier: .gregorian)
            $0.modelContainer = container
            $0.planningClient.listActive = { @Sendable in [] }
            $0.carrierClient.listAll = { @Sendable in [phone, cert] }
        } operation: {
            try await WatchContextBuilder.build(
                now: Date(), defaultAccountId: UUID().uuidString
            )
        }

        #expect(snapshot.carriers == [phone, cert])
    }
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:NeuLedgerTests/WatchContextBuilderTests`
Expected: FAIL — `mirrorsCarriersInListOrder` 的 `snapshot.carriers` 是 `nil` 不是 `[phone, cert]`；`aggregatesTodaysExpensesOnly` 的 `carriers == []` 也失敗

- [ ] **Step 3: 改 builder**

`WatchContextBuilder.swift` 的 `build` 函式：

(a) 依賴宣告區（`@Dependency(\.planningClient) var planningClient` 之後）加：

```swift
        @Dependency(\.carrierClient) var carrierClient
```

(b) `let activeBudgets = try await planningClient.listActive()` 之後加：

```swift
        // Carriers ride the same full snapshot. Reactive save observation
        // (WatchSyncObserver) means any CarrierStore mutation re-pushes
        // automatically — never call the bridge from CarrierClient.
        let carriers = try await carrierClient.listAll()
```

(c) return 的 `WatchContextSnapshot(...)` 加最後一個引數：

```swift
            snapshotAt: now,
            carriers: carriers
```

- [ ] **Step 4: 跑測試確認通過**

Run: 同 Step 2 指令
Expected: PASS（3 tests）

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Core/Adapters/Watch/WatchContextBuilder.swift NeuLedgerTests/Tests/CoreTests/WatchContextBuilderTests.swift
git commit -m "feat(core): include carriers in watch context snapshot [ci skip]"
```

---

### Task 5: `WatchCarrierClient`（watch 端讀 cache）

**Files:**
- Create: `Features/Sources/WatchFeatures/Clients/WatchCarrierClient.swift`
- Modify: `Features/Sources/WatchFeatures/Clients/WatchDependencies.swift`
- Test: `NeuLedgerWatchTests/WatchCarrierClientTests.swift`

- [ ] **Step 1: 寫失敗測試**

建立 `NeuLedgerWatchTests/WatchCarrierClientTests.swift`：

```swift
import Foundation
import Testing
import Domain
@testable import WatchFeatures

@Suite("WatchCarrierClient Tests")
struct WatchCarrierClientTests {

    private func makeCache() -> WatchCacheStore {
        let suite = "WatchCarrierClientTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return WatchCacheStore(defaults: defaults)
    }

    private func makeSnapshot(carriers: [Carrier]?) -> WatchContextSnapshot {
        WatchContextSnapshot(
            categories: [], accounts: [], defaultAccountId: "ACC-1",
            todayTotal: 0, todayCount: 0, monthBudgetProgress: nil,
            snapshotAt: Date(timeIntervalSince1970: 1_700_000_000),
            carriers: carriers
        )
    }

    @Test("Empty cache yields nil (not yet synced)")
    func emptyCacheYieldsNil() async {
        let client = WatchCarrierClient.watchLive(cache: makeCache())
        #expect(await client.carriers() == nil)
    }

    @Test("Snapshot without carriers field yields nil")
    func legacySnapshotYieldsNil() async {
        let cache = makeCache()
        cache.save(makeSnapshot(carriers: nil))
        let client = WatchCarrierClient.watchLive(cache: cache)
        #expect(await client.carriers() == nil)
    }

    @Test("Snapshot carriers come back in order")
    func carriersPreserveOrder() async {
        let cache = makeCache()
        let first = Carrier(name: "手機條碼", type: .phoneBarcodeCarrier, barcode: "/AB12+CD")
        let second = Carrier(
            name: "自然人憑證", type: .citizenDigitalCertificate,
            barcode: "AB12345678901234"
        )
        cache.save(makeSnapshot(carriers: [first, second]))
        let client = WatchCarrierClient.watchLive(cache: cache)
        #expect(await client.carriers() == [first, second])
    }

    @Test("Empty carriers array stays empty (synced, none stored)")
    func emptyCarriersStayEmpty() async {
        let cache = makeCache()
        cache.save(makeSnapshot(carriers: []))
        let client = WatchCarrierClient.watchLive(cache: cache)
        #expect(await client.carriers() == [])
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `xcodebuild test -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -only-testing:NeuLedgerWatchTests/WatchCarrierClientTests`
Expected: **編譯失敗**，`cannot find 'WatchCarrierClient' in scope`

- [ ] **Step 3: 實作 client**

建立 `Features/Sources/WatchFeatures/Clients/WatchCarrierClient.swift`：

```swift
import Foundation
import Dependencies
import DependenciesMacros
import Domain

/// Watch-side carrier client — read-only by design. The Watch never
/// creates, edits, or deletes carriers; it renders whatever the iPhone
/// mirrored into the snapshot cache.
@DependencyClient
public struct WatchCarrierClient: Sendable {
    /// Carriers from the iPhone snapshot cache.
    /// `nil` = no snapshot yet, or the snapshot predates carrier support
    /// (UI shows a sync hint). `[]` = synced and genuinely none
    /// (UI shows add-on-iPhone guidance).
    public var carriers: @Sendable () async -> [Carrier]? = { nil }
}

extension WatchCarrierClient: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var watchCarrierClient: WatchCarrierClient {
        get { self[WatchCarrierClient.self] }
        set { self[WatchCarrierClient.self] = newValue }
    }
}

extension WatchCarrierClient {

    /// Watch-side live value: a thin projection over `WatchCacheStore`.
    public static func watchLive(cache: WatchCacheStore) -> WatchCarrierClient {
        WatchCarrierClient(
            carriers: { cache.load()?.carriers }
        )
    }
}
```

- [ ] **Step 4: 註冊依賴**

`WatchDependencies.swift` — 在 `let cache = WatchCacheStore()` 之後（`#if canImport(WatchConnectivity)` 之前，carrier client 只需要 cache 不需要 gateway）加：

```swift
        dependencies.watchCarrierClient = .watchLive(cache: cache)
```

- [ ] **Step 5: 跑測試確認通過**

Run: 同 Step 2 指令
Expected: PASS（4 tests）

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/WatchFeatures/Clients/WatchCarrierClient.swift Features/Sources/WatchFeatures/Clients/WatchDependencies.swift NeuLedgerWatchTests/WatchCarrierClientTests.swift
git commit -m "feat(watch): add read-only WatchCarrierClient backed by snapshot cache [ci skip]"
```

---

### Task 6: `WatchCarrierFeature` reducer

**Files:**
- Create: `Features/Sources/WatchFeatures/Carrier/WatchCarrierFeature.swift`
- Test: `NeuLedgerWatchTests/WatchCarrierFeatureTests.swift`

- [ ] **Step 1: 寫失敗測試**

建立 `NeuLedgerWatchTests/WatchCarrierFeatureTests.swift`：

```swift
import Foundation
import Testing
import Dependencies
import Domain
import ComposableArchitecture
@testable import WatchFeatures

@MainActor
@Suite("WatchCarrierFeature Tests")
struct WatchCarrierFeatureTests {

    private static let phone = Carrier(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "手機條碼", type: .phoneBarcodeCarrier,
        barcode: "/AB12+CD",
        createdAt: Date(timeIntervalSince1970: 0)
    )

    private static let cert = Carrier(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        name: "自然人憑證", type: .citizenDigitalCertificate,
        barcode: "AB12345678901234",
        createdAt: Date(timeIntervalSince1970: 0)
    )

    @Test("Task loads carriers from the client")
    func taskLoadsCarriers() async {
        let store = TestStore(initialState: WatchCarrierFeature.State()) {
            WatchCarrierFeature()
        } withDependencies: {
            $0.watchCarrierClient.carriers = { @Sendable in [Self.phone] }
        }

        await store.send(.task)
        await store.receive(\.carriersUpdated) {
            $0.carriers = [Self.phone]
        }
    }

    @Test("Tapping a row presents that carrier's barcode")
    func tapPresentsBarcode() async {
        let store = TestStore(
            initialState: WatchCarrierFeature.State(carriers: [Self.phone, Self.cert])
        ) {
            WatchCarrierFeature()
        }

        await store.send(.carrierTapped(Self.cert.id)) {
            $0.presentedCarrier = Self.cert
        }
        await store.send(.barcodeDismissed) {
            $0.presentedCarrier = nil
        }
    }

    @Test("Cache update re-resolves the presented carrier by id")
    func updateReresolvesPresented() async {
        var renamed = Self.phone
        renamed.name = "新名字"

        let store = TestStore(
            initialState: WatchCarrierFeature.State(
                carriers: [Self.phone, Self.cert],
                presentedCarrier: Self.phone
            )
        ) {
            WatchCarrierFeature()
        }

        await store.send(.carriersUpdated([renamed, Self.cert])) {
            $0.carriers = [renamed, Self.cert]
            $0.presentedCarrier = renamed
        }
    }

    @Test("Cache update dismisses the presented carrier when it was deleted")
    func updateDismissesDeletedPresented() async {
        let store = TestStore(
            initialState: WatchCarrierFeature.State(
                carriers: [Self.phone, Self.cert],
                presentedCarrier: Self.cert
            )
        ) {
            WatchCarrierFeature()
        }

        await store.send(.carriersUpdated([Self.phone])) {
            $0.carriers = [Self.phone]
            $0.presentedCarrier = nil
        }
    }

    @Test("Sync state degrades to nil when the cache empties")
    func updateToNilClearsList() async {
        let store = TestStore(
            initialState: WatchCarrierFeature.State(carriers: [Self.phone])
        ) {
            WatchCarrierFeature()
        }

        await store.send(.carriersUpdated(nil)) {
            $0.carriers = nil
        }
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `xcodebuild test -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -only-testing:NeuLedgerWatchTests/WatchCarrierFeatureTests`
Expected: **編譯失敗**，`cannot find 'WatchCarrierFeature' in scope`

- [ ] **Step 3: 實作 reducer**

建立 `Features/Sources/WatchFeatures/Carrier/WatchCarrierFeature.swift`：

```swift
import Foundation
import ComposableArchitecture
import Domain

/// Watch carrier viewer reducer. Read-only: state is a projection of the
/// snapshot cache plus which carrier (if any) is shown full-screen.
///
/// The view derives the four-state UI from `carriers`:
/// `nil` → sync hint, `[]` → empty guidance, one → barcode fast path,
/// 2+ → list (tap pushes the barcode via `presentedCarrier`).
@Reducer
public struct WatchCarrierFeature: Sendable {

    @ObservableState
    public struct State: Equatable, Sendable {
        /// `nil` = not yet synced (or pre-carrier iPhone build);
        /// `[]` = synced, none stored.
        public var carriers: [Carrier]?

        /// Carrier currently pushed full-screen from the 2+ list.
        /// (The single-carrier fast path renders directly off
        /// `carriers`, without touching this.)
        public var presentedCarrier: Carrier?

        public init(
            carriers: [Carrier]? = nil,
            presentedCarrier: Carrier? = nil
        ) {
            self.carriers = carriers
            self.presentedCarrier = presentedCarrier
        }
    }

    public enum Action: Sendable {
        case task
        case carriersUpdated([Carrier]?)
        case carrierTapped(Carrier.ID)
        case barcodeDismissed
    }

    @Dependency(\.watchCarrierClient) var carrierClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .task:
                return .run { [carrierClient] send in
                    await send(.carriersUpdated(carrierClient.carriers()))
                    // Re-load whenever a fresh iPhone snapshot lands, same
                    // pattern as WatchRecordFeature.task.
                    for await _ in NotificationCenter.default.notifications(
                        named: WatchCacheStore.didUpdateNotification
                    ) {
                        await send(.carriersUpdated(carrierClient.carriers()))
                    }
                }

            case let .carriersUpdated(carriers):
                state.carriers = carriers
                if let presented = state.presentedCarrier {
                    // Re-resolve by id: pick up renames/barcode edits, and
                    // dismiss if the carrier was deleted on iPhone.
                    state.presentedCarrier = carriers?.first { $0.id == presented.id }
                }
                return .none

            case let .carrierTapped(id):
                state.presentedCarrier = state.carriers?.first { $0.id == id }
                return .none

            case .barcodeDismissed:
                state.presentedCarrier = nil
                return .none
            }
        }
    }
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: 同 Step 2 指令
Expected: PASS（5 tests）

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/WatchFeatures/Carrier/WatchCarrierFeature.swift NeuLedgerWatchTests/WatchCarrierFeatureTests.swift
git commit -m "feat(watch): add WatchCarrierFeature reducer with four-state carrier projection [ci skip]"
```

---

### Task 7: 載具畫面（四態 + 直式條碼頁）+ 字串

**Files:**
- Create: `Features/Sources/WatchFeatures/Carrier/WatchCarrierView.swift`
- Create: `Features/Sources/WatchFeatures/Carrier/CarrierBarcodeView.swift`
- Modify: `NeuLedgerWatch Watch App/Localizable.xcstrings`

- [ ] **Step 1: 加 localization keys**

`NeuLedgerWatch Watch App/Localizable.xcstrings` 的 `"strings"` 物件內加三個 key（與既有 key 同層、保持 JSON 結構）：

```json
    "watch_carrier_title" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : { "state" : "translated", "value" : "Carriers" }
        },
        "zh-Hant" : {
          "stringUnit" : { "state" : "translated", "value" : "載具" }
        }
      }
    },
    "watch_carrier_syncing_hint" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : { "state" : "translated", "value" : "Syncing — open NeuLedger on your iPhone" }
        },
        "zh-Hant" : {
          "stringUnit" : { "state" : "translated", "value" : "資料同步中\n請開啟 iPhone 上的 NeuLedger" }
        }
      }
    },
    "watch_carrier_empty_hint" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : { "state" : "translated", "value" : "No carriers yet — add one on your iPhone" }
        },
        "zh-Hant" : {
          "stringUnit" : { "state" : "translated", "value" : "尚無載具\n請在 iPhone 上新增電子發票載具" }
        }
      }
    },
```

- [ ] **Step 2: 建立條碼頁**

建立 `Features/Sources/WatchFeatures/Carrier/CarrierBarcodeView.swift`：

```swift
import SwiftUI
import Domain
import Common

/// Full-screen scannable barcode. White edge-to-edge backdrop with the
/// Code 128 rotated 90° (vertical) so module width is maximized on the
/// tall, narrow watch display. Content intentionally stays fully visible
/// under AOD luminance reduction — the user may be mid-checkout.
struct CarrierBarcodeView: View {

    let carrier: Carrier

    var body: some View {
        ZStack {
            Color.Design.barcodeSurface.ignoresSafeArea()
            if let modules = Code128.modules(for: carrier.barcode) {
                HStack(spacing: 6) {
                    Code128BarcodeView(modules: modules, orientation: .vertical)
                        // Quiet zones along the code axis.
                        .padding(.vertical, 10)
                    VStack(spacing: 6) {
                        Text(carrier.barcode)
                            .font(Font.Design.size12Monospaced)
                            .foregroundStyle(Color.Design.barcodeInk)
                        Text(carrier.name)
                            .font(Font.Design.size9)
                            .foregroundStyle(Color.Design.textSecondary)
                    }
                    .fixedSize()
                    .rotationEffect(.degrees(90))
                    .frame(width: 30)
                }
                .padding(.horizontal, 8)
            } else {
                // Encoder rejected the stored barcode (shouldn't happen for
                // carriers validated on iPhone) — degrade to a code the
                // clerk can key in by hand.
                VStack(spacing: 6) {
                    Text(carrier.barcode)
                        .font(Font.Design.size20Monospaced)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(Color.Design.barcodeInk)
                    Text(carrier.name)
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.textSecondary)
                }
                .padding()
            }
        }
    }
}
```

- [ ] **Step 3: 建立載具頁**

建立 `Features/Sources/WatchFeatures/Carrier/WatchCarrierView.swift`：

```swift
import SwiftUI
import ComposableArchitecture
import Domain
import Common

/// Page 2 of the Watch app: the e-invoice carrier viewer. Renders one of
/// four states — sync hint (`carriers == nil`), empty guidance (`[]`),
/// single-carrier fast path (barcode immediately, zero taps), or a list
/// for 2+ carriers (tap pushes the barcode).
public struct WatchCarrierView: View {

    @Bindable public var store: StoreOf<WatchCarrierFeature>

    public init(store: StoreOf<WatchCarrierFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle(String(localized: "watch_carrier_title"))
                .navigationDestination(
                    isPresented: Binding(
                        get: { store.presentedCarrier != nil },
                        set: { isPresented in
                            if isPresented == false {
                                store.send(.barcodeDismissed)
                            }
                        }
                    )
                ) {
                    if let carrier = store.presentedCarrier {
                        CarrierBarcodeView(carrier: carrier)
                    }
                }
        }
        .task { await store.send(.task).finish() }
    }

    @ViewBuilder
    private var content: some View {
        if let carriers = store.carriers {
            if carriers.isEmpty {
                hint(icon: "barcode", textKey: "watch_carrier_empty_hint")
            } else if carriers.count == 1, let only = carriers.first {
                // Fast path: one carrier → its barcode IS the page.
                CarrierBarcodeView(carrier: only)
                    .toolbar(.hidden, for: .navigationBar)
            } else {
                carrierList(carriers)
            }
        } else {
            hint(icon: "iphone.gen3", textKey: "watch_carrier_syncing_hint")
        }
    }

    private func carrierList(_ carriers: [Carrier]) -> some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(carriers) { carrier in
                    Button {
                        store.send(.carrierTapped(carrier.id))
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: typeIcon(for: carrier.type))
                                .foregroundStyle(Color.Design.accentOrange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(carrier.name)
                                    .font(Font.Design.body)
                                    .lineLimit(1)
                                Text(carrier.barcode)
                                    .font(Font.Design.size10Monospaced)
                                    .foregroundStyle(Color.Design.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func hint(icon: String, textKey: String.LocalizationValue) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(Font.Design.size22SemiboldRounded)
                .foregroundStyle(Color.Design.textSecondary)
            Text(String(localized: textKey))
                .font(Font.Design.caption)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func typeIcon(for type: CarrierType) -> String {
        switch type {
        case .phoneBarcodeCarrier: "iphone.gen3"
        case .citizenDigitalCertificate: "person.text.rectangle"
        }
    }
}
```

- [ ] **Step 4: 編譯驗證**

Run: `xcodebuild build -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/WatchFeatures/Carrier/WatchCarrierView.swift Features/Sources/WatchFeatures/Carrier/CarrierBarcodeView.swift "NeuLedgerWatch Watch App/Localizable.xcstrings"
git commit -m "feat(watch): add carrier page with four-state UI and vertical barcode screen [ci skip]"
```

---

### Task 8: `WatchAppFeature` root（垂直 TabView）+ 進入點切換

**Files:**
- Create: `Features/Sources/WatchFeatures/App/WatchAppFeature.swift`
- Create: `Features/Sources/WatchFeatures/App/WatchAppView.swift`
- Modify: `NeuLedgerWatch Watch App/NeuLedgerWatchApp.swift`
- Test: `NeuLedgerWatchTests/WatchAppFeatureTests.swift`

- [ ] **Step 1: 寫失敗測試**

建立 `NeuLedgerWatchTests/WatchAppFeatureTests.swift`：

```swift
import Foundation
import Testing
import Dependencies
import Domain
import ComposableArchitecture
@testable import WatchFeatures

@MainActor
@Suite("WatchAppFeature Tests")
struct WatchAppFeatureTests {

    private static let foodCategory = Domain.Category(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "Food", icon: "fork.knife", color: "#FF9500",
        type: .expense, sortOrder: 0, isDefault: true
    )

    @Test("Paging locks while the record flow is past the category step")
    func pagingLocksDuringEntry() async {
        // ⚠️ TCA Scope：parent 測試會走到 child 依賴。此測試只送純狀態
        // action（categoryTapped / cancelTapped 不碰 client），故無需 stub。
        let store = TestStore(
            initialState: WatchAppFeature.State(
                record: WatchRecordFeature.State(categories: [Self.foodCategory])
            )
        ) {
            WatchAppFeature()
        }

        #expect(store.state.isPagingLocked == false)

        await store.send(.record(.categoryTapped(Self.foodCategory.id))) {
            $0.record.draft = WatchRecordFeature.Draft(
                categoryId: Self.foodCategory.id,
                accountIdOverride: nil
            )
            $0.record.step = .amount
        }
        #expect(store.state.isPagingLocked)

        await store.send(.record(.cancelTapped)) {
            $0.record.draft = nil
            $0.record.step = .category
        }
        #expect(store.state.isPagingLocked == false)
    }

    @Test("Tab selection binds")
    func tabSelectionBinds() async {
        let store = TestStore(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        }

        await store.send(.binding(.set(\.tab, .carrier))) {
            $0.tab = .carrier
        }
        await store.send(.binding(.set(\.tab, .record))) {
            $0.tab = .record
        }
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `xcodebuild test -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -only-testing:NeuLedgerWatchTests/WatchAppFeatureTests`
Expected: **編譯失敗**，`cannot find 'WatchAppFeature' in scope`

- [ ] **Step 3: 實作 root reducer**

建立 `Features/Sources/WatchFeatures/App/WatchAppFeature.swift`：

```swift
import Foundation
import ComposableArchitecture

/// Root reducer for the Watch app: composes the quick-record flow
/// (page 1) and the carrier viewer (page 2) behind a vertical-page
/// TabView.
@Reducer
public struct WatchAppFeature: Sendable {

    public enum Tab: Equatable, Sendable {
        case record
        case carrier
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public var tab: Tab
        public var record: WatchRecordFeature.State
        public var carrier: WatchCarrierFeature.State

        public init(
            tab: Tab = .record,
            record: WatchRecordFeature.State = .init(),
            carrier: WatchCarrierFeature.State = .init()
        ) {
            self.tab = tab
            self.record = record
            self.carrier = carrier
        }

        /// Vertical paging is allowed only while the record flow sits on
        /// its first (category) step, so keypad taps can't mis-swipe to
        /// the carrier page mid-entry.
        public var isPagingLocked: Bool { record.step != .category }
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case record(WatchRecordFeature.Action)
        case carrier(WatchCarrierFeature.Action)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.record, action: \.record) {
            WatchRecordFeature()
        }
        Scope(state: \.carrier, action: \.carrier) {
            WatchCarrierFeature()
        }
    }
}
```

- [ ] **Step 4: 實作 root view**

建立 `Features/Sources/WatchFeatures/App/WatchAppView.swift`：

```swift
import SwiftUI
import ComposableArchitecture

/// Top-level Watch view: vertical-page TabView between record (page 1)
/// and carriers (page 2). The carrier page is removed from the hierarchy
/// while paging is locked (mid-entry), which disables the swipe without
/// touching the record flow.
public struct WatchAppView: View {

    @Bindable public var store: StoreOf<WatchAppFeature>

    public init(store: StoreOf<WatchAppFeature>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $store.tab) {
            WatchRootView(
                store: store.scope(state: \.record, action: \.record)
            )
            .tag(WatchAppFeature.Tab.record)

            if store.isPagingLocked == false {
                WatchCarrierView(
                    store: store.scope(state: \.carrier, action: \.carrier)
                )
                .tag(WatchAppFeature.Tab.carrier)
            }
        }
        .tabViewStyle(.verticalPage)
    }
}
```

- [ ] **Step 5: 換進入點**

`NeuLedgerWatch Watch App/NeuLedgerWatchApp.swift` 的 `body` 改為：

```swift
    var body: some Scene {
        WindowGroup {
            WatchAppView(
                store: Store(initialState: WatchAppFeature.State()) {
                    WatchAppFeature()
                }
            )
        }
    }
```

（`init()` 的 `prepareDependencies` 不動。）

- [ ] **Step 6: 跑測試確認通過**

Run: 同 Step 2 指令
Expected: PASS（2 tests）

- [ ] **Step 7: Commit**

```bash
git add Features/Sources/WatchFeatures/App/WatchAppFeature.swift Features/Sources/WatchFeatures/App/WatchAppView.swift "NeuLedgerWatch Watch App/NeuLedgerWatchApp.swift" NeuLedgerWatchTests/WatchAppFeatureTests.swift
git commit -m "feat(watch): vertical-page root composing record and carrier pages [ci skip]"
```

---

### Task 9: 完整驗證

**Files:** 無新增/修改（驗證 task）

- [ ] **Step 1: iOS 完整 test scheme**

Run: `xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: 全數 PASS（含既有所有 suite — 確認 snapshot 欄位與 builder 改動無 side effect）

- [ ] **Step 2: watch 完整 test suite**

Run: `xcodebuild test -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'`
Expected: 全數 PASS（既有 5 suite + 新 3 suite）

- [ ] **Step 3: 模擬器煙霧測試**

在 watch 模擬器啟動 app，確認：
1. 預設落在記帳頁，上滑可到載具頁（未同步時顯示同步提示）
2. 記帳流程進金額步驟後上滑無法切頁；取消後恢復
3. （配對 iPhone 模擬器有載具資料時）載具列表/條碼頁正確顯示

- [ ] **Step 4: 手動驗收清單（記入 PR description，留待實機）**

- [ ] 實機：超商掃描器實測手機條碼（`/`+7 碼）可掃
- [ ] 實機：超商掃描器實測自然人憑證（16 碼）可掃
- [ ] 實機：AOD 手腕放下時條碼仍可見（不打碼）
- [ ] 若掃不到：後備方案 = 依載具型別自動選向（spec §9）

- [ ] **Step 5: 完成分支**

全部通過後依 `superpowers:finishing-a-development-branch` 處理（PR 走 `commit-commands:commit-push-pr`，目標 `developer`）。

---

## Self-Review 紀錄

- **Spec coverage**：snapshot 欄位（T3）、builder（T4）、color tokens（T2）、編碼器 B+C（T1）、條碼 View（T2）、watch client（T5）、四態 reducer（T6）、四態 UI + 直式條碼頁 + 字串（T7）、垂直翻頁 root + 防誤滑 + 進入點（T8）、測試策略 1–5 + 全量驗證 + 實機驗收（各 task + T9）— 無缺口。
- **Placeholder scan**：全部步驟含完整程式碼與指令，無 TBD/「適當處理」類字眼。
- **Type consistency**：`WatchCarrierClient.carriers()`（T5 定義、T6 stub 一致）；`WatchCarrierFeature.Action.carriersUpdated/carrierTapped/barcodeDismissed`（T6 定義、T6/T7 使用一致）；`WatchAppFeature.Tab.record/.carrier`、`isPagingLocked`（T8 內一致）；`Code128.modules/codeValues`（T1 定義、T7 使用一致）；`Carrier.ID = UUID`、`Account.ID = String` 各處吻合。

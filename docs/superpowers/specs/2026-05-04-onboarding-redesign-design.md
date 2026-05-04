# Onboarding Redesign 設計文件（B-Warm）

**日期：** 2026-05-04
**範圍：** `OnboardingFeature` / `OnboardingView` 全面改寫，`AccountType.displayLabel` 改為 localized；新增 `WarmGradientBackground` / `OnboardingPageDots` 共用元件。
**設計來源：** `design/prototypes/onboarding-b-prototype.jsx`、`design/README.md`（B Warm 方向定稿）。

---

## 背景與問題

目前 onboarding Step 2（`accountSetup`）讓使用者困惑：

1. **認知模型錯位** — 採「填一個帳戶」表單模式（TextField 輸入名稱 + Segmented 4 選 1 類型），但記帳工具的多帳戶概念在第一次使用時很難用「填一筆」傳達。
2. **預設值塞滿輸入框** — `accountName` 初始值是 `String(localized: "onboarding_setup_name_placeholder")`，使用者看到 TextField 已有「現金」字樣，看起來像「已填寫」而不是 placeholder hint。
3. **AccountType 顯示英文** — `displayLabel` 寫死英文（`Cash` / `Bank` / `Credit Card` / `E-Wallet`），中文 UI 上違和。
4. **Segmented Picker 太擠** — 4 個英文選項並排無圖示，無法快速辨識。
5. **跳過語意衝突** — 「跳過」按鈕在右上角，但跳過後仍會自動建立 `Cash` 帳戶；使用者可能不知道實際發生了什麼。
6. **Step 3 流程冗餘** — 按 Step 2「下一步」後到 Step 3 的「完成」才實際寫入帳戶，中間多了一次無實質進展的點擊。
7. **視覺與設計稿差距大** — 目前是純色背景 + 漸層方塊，設計稿是 warm radial gradient + blur orbs + glass cards + stagger 入場。

---

## 設計目標

- **重構 Step 2 認知模型**：從「填一個帳戶」改為「勾選你常用的帳戶類型」grid 多選 + 自訂 sheet。
- **整體視覺對齊 B-Warm 設計稿**：warm radial gradient、blur orbs、liquid glass cards、stagger reveal 入場。
- **AccountType 中文化**：`displayLabel` 改用 `String(localized:)`。
- **流程精簡**：跳過時直接到 Done celebration，不繞 Ready；Step 2 Continue 直接送到 Ready 後一鍵完成。
- **保持 Domain 層不變**：不新增 `Account.balance` 欄位；不依賴 `aiServiceClient`。

---

## 設計範圍與決策結果

| 決策點 | 結論 |
|---|---|
| Q1 · Step 2 帳戶卡命名策略 | **A** — 純類型卡片（直接 map `AccountType.allCases`），勾起來用 localized `displayLabel` 當帳戶名稱 |
| Q2 · 起始餘額（starting balance）| **A** — 不做。維持「餘額計算自交易」的 Domain 設計 |
| Q3 · Step 3 try-it 互動 | **C** — 暫不做。沿用 Ready 結構但更新視覺 |
| Welcome 預覽卡 | 不顯示假數字。預覽卡顯示 `NT$ 0` + 「即將開始」/「On-device」chip |
| AccountType.displayLabel | 改為 localized；連帶更新 5 處呼叫端（Onboarding / AccountManagement ×2 / AddEditAccount / Dashboard） |

---

## 流程總覽

```
welcome → accountSelection → ready → done celebration → .delegate(.onboardingCompleted)
                ↓ skip                    ↓ skip
                └────────→ done celebration ─────┘
```

- 4 個 Step（新增 `done` step 包含 1.6s celebration）
- Skip 從 welcome / accountSelection 直接跳 done
- ready → 「完成」 = 寫入帳戶 + done celebration

---

## State 設計（OnboardingFeature 重寫）

```swift
@Reducer
struct OnboardingFeature {
    enum Step: Equatable {
        case welcome
        case accountSelection   // renamed from accountSetup
        case ready
        case done               // 新：1.6s celebration
    }

    @ObservableState
    struct State: Equatable {
        var currentStep: Step = .welcome

        // 預設類型勾選狀態（預設 .cash 已勾）
        var selectedTypes: Set<AccountType> = [.cash]

        // 自訂帳戶（透過 sheet 加入，Step 2 完成才寫入 DB）
        var customAccounts: IdentifiedArrayOf<CustomAccountDraft> = []

        // 自訂帳戶 sheet
        @Presents var customAccountSheet: CustomAccountFormFeature.State?

        var isCreatingAccounts: Bool = false
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case startButtonTapped
        case typeToggled(AccountType)
        case addCustomAccountTapped
        case customAccountSheet(PresentationAction<CustomAccountFormFeature.Action>)
        case customAccountDeleted(CustomAccountDraft.ID)
        case nextButtonTapped       // accountSelection → ready
        case finishButtonTapped     // ready → done (writes accounts)
        case skipButtonTapped       // any → done (writes default cash account)
        case accountsCreated
        case doneAnimationFinished  // 1.6s 後送 delegate
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case onboardingCompleted
        }
    }
}

struct CustomAccountDraft: Equatable, Identifiable {
    let id: UUID
    var name: String
    var type: AccountType
    var color: String       // hex
}
```

### CustomAccountFormFeature（新增 sub-reducer）

`Features/Sources/Features/Onboarding/CustomAccountFormFeature.swift`

```swift
@Reducer
struct CustomAccountFormFeature {
    @ObservableState
    struct State: Equatable {
        var name: String = ""
        var type: AccountType = .bank
        var color: String = "#FF9500"   // accent default

        var canSubmit: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case cancelTapped
        case submitTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case dismissed
            case submitted(CustomAccountDraft)
        }
    }
}
```

預設色票：`["#FF9500","#0A84FF","#5E5CE6","#FF2D55","#34C759","#8E8E93"]`（與設計稿一致）。

---

## 各 Step UI 規格

### Step 1 · Welcome

**Layout（由上而下）：**
1. 暖色 radial gradient 背景（透過 `WarmGradientBackground` view modifier 套用）
2. 頂部右上「跳過」（與 page dots 同層）
3. 預覽 glass card（裝飾用、顯示在主標上方）
   - Eyebrow（mono uppercase, 13px muted）：`onboarding_welcome_card_eyebrow` →「總資產 · 開始追蹤」
   - 大金額：`Decimal(0).twdFormatted`，Bricolage display 44px / -1.4 letterspacing
   - 兩個 chip（橫排）：`onboarding_welcome_chip_starting`「即將開始」 / `onboarding_welcome_chip_on_device`「On-device」
4. 主標：`onboarding_welcome_title` Bricolage display 44px / -1.8 letterspacing；後半部 accent 色 + 斜體（同設計稿 "seen." 處理）
5. 副標：`onboarding_welcome_subtitle`，DM Sans 16px muted
6. 底部 CTA「開始」`PrimaryButton`（CTA gradient + shadow-cta）
7. 下方 row：左 `OnboardingPageDots(active: 0)` / 右側「跳過」

**Stagger reveal：** 預覽卡 120ms / 主標 460ms / CTA 640ms。透過 `@State var visible = false` 在 `.task` 中設為 `true` 觸發 `withAnimation(.easeOut(duration: 0.55))`。

**動作：**
- 「開始」→ `store.send(.startButtonTapped)` → `currentStep = .accountSelection`
- 「跳過」→ `store.send(.skipButtonTapped)`

### Step 2 · Account Selection（核心改動）

**Layout：**
1. 同 warm gradient + 一顆 bottom-right blur orb
2. Header：返回鈕（圓形 glass，34px）+ `onboarding_step_indicator_2`「Step 02 of 03」（DM Sans 13px muted）
3. 主標：`onboarding_selection_title`「選擇你的帳戶」Bricolage 32px / -1.2
4. 副標：`onboarding_selection_subtitle`「點擊新增。隨時可以調整。」
5. **2x2 grid**（GridItem，flexible、12pt spacing）：4 張類型卡（順序 = `AccountType.allCases`）
6. 自訂帳戶 list：每個 `customAccounts` 元素以 1 列 glass row 顯示，左 icon、中名稱、右刪除鈕
7. 全寬「+ 新增其他帳戶」glass pill（dashed outline）
8. CTA「繼續 · {count} 個」（disabled when `count < 1`，count = `selectedTypes.count + customAccounts.count`）
9. 底部 row：左 `OnboardingPageDots(active: 1)` / 右「跳過」

**類型卡設計：**
- 容器：`GlassContainer(cornerRadius: 22)`，padding 16，min height 140
- 左上：類型圖示 36×36 圓角 11px，背景 = `accountType.color.opacity(0.12)`
- 右上：22×22 選擇圈
  - 未選：透明背景 + 1.5px muted 邊
  - 已選：accent 填色 + 14px white check
- 卡內（marginTop 22pt）：
  - Eyebrow：mono uppercase 10px muted（如「CASH」）
  - 名稱：DM Sans 15px / 600（如「現金」← localized `displayLabel`）
- 整張卡 `Tappable` (scale 0.97 press feedback) → `store.send(.typeToggled(.cash))`

**圖示與色票（取自 `AccountType` 既有 default）：**

| Type | Icon (SF Symbol) | Color |
|---|---|---|
| `.cash` | `banknote` | `#8E8E93` |
| `.bank` | `building.columns` | `#0A84FF` |
| `.creditCard` | `creditcard` | `#FF2D55` |
| `.eWallet` | `wallet.bifold` | `#5E5CE6` |

> ⚠️ 設計稿用 `#2ECC71` / `#3498DB` / `#E74C3C` / `#9B59B6` 是現有 `AccountType.defaultColor` 的色值（在 OnboardingFeature 私有 extension 內）。Spec 改採 design tokens 中的 iOS 系統色（`#8E8E93` / `#0A84FF` / `#FF2D55` / `#5E5CE6`），與設計稿 PRESET_ACCOUNTS 一致。`AccountType.defaultColor` extension 同步更新。

**Bottom Sheet（`CustomAccountFormFeature` 呈現）：**
- 透過 `.sheet(item: $store.scope(state: \.$customAccountSheet, action: \.customAccountSheet))` 顯示
- 內容（垂直 stack）：
  1. drag handle 38×5 muted
  2. 標題「新增帳戶」Bricolage 24px / 700
  3. 副標「為它取個名字，選類型與顏色」DM Sans 13px muted
  4. **帳戶名稱** TextField（`onboarding_custom_name_placeholder`「例如：玉山銀行」） — 用 `GlassContainer` 包裝，**不預填**任何字
  5. **類型 chip row**：4 個 chip（icon + 標籤），active 時 outline accent
  6. **顏色 picker**：6 個 30×30 圓點（`COLOR_OPTIONS`），active 時加 2px white border + 2px accent shadow ring
  7. **新增**按鈕（disabled until `canSubmit`）

**動作：**
- type 卡 tap → `typeToggled(.cash)`：toggle in `selectedTypes`
- 「+ 新增其他帳戶」→ `addCustomAccountTapped`（`customAccountSheet = .init()`）
- sheet「新增」→ delegate `.submitted(draft)` → 父 reducer append `customAccounts`，dismiss sheet
- 自訂帳戶 row 的 trash icon → `customAccountDeleted(id)`
- 「繼續」→ `nextButtonTapped` → `currentStep = .ready`

### Step 3 · Ready（沿用結構，視覺更新）

**Layout：**
1. warm gradient + 中央 orb
2. Spacer
3. Success circle 100×100 accent 色 + 48px `checkmark.circle.fill` + `shadow-cta`
4. 標題：`onboarding_ready_title` Bricolage 36px / -1.2（沿用既有 key，但字型/字級對齊設計稿）
5. 副標：`onboarding_ready_subtitle`（沿用）
6. 預覽卡（`GlassContainer`）：
   - eyebrow：`onboarding_ready_total_label`「總餘額」
   - `Decimal(0).twdFormatted` Bricolage 24px monospaced
   - chip：`onboarding_ready_account_count` 用 `String(localized:)` + `count`，顯示「已建立 N 個帳戶」
7. Spacer
8. CTA「完成」 → `finishButtonTapped`
9. 底部 page dots（active: 2）

**動作：**
- `finishButtonTapped` → `state.isCreatingAccounts = true` → `.run` effect：
  1. 對每個 `selectedTypes` 建立 `Account(name: type.displayLabel, type: type, icon: type.defaultIcon, color: type.defaultColor)`
  2. 對每個 `customAccounts` 建立 `Account(name: draft.name, type: draft.type, icon: draft.type.defaultIcon, color: draft.color)`
  3. `userSettingsClient.setBool(true, .hasCompletedOnboarding)`
  4. `await send(.accountsCreated)`
- `.accountsCreated` → `currentStep = .done`，啟動 1.6s 計時 effect → `.doneAnimationFinished` → `.delegate(.onboardingCompleted)`

### Step 4 · Done celebration（新增）

**Layout：**
1. warm gradient（fade in）
2. 中央：accent 圓 88×88 + 42px `checkmark` + `shadow-cta`（scale 0.6 → 1 spring 入場）
3. 主標：`onboarding_done_title`「歡迎加入」Bricolage 36px
4. 副標：`onboarding_done_subtitle`「準備就緒，正在打開儀表板…」
5. 1.6s 後 dispatch `.delegate(.onboardingCompleted)`

不做 confetti（YAGNI）。

### Skip 行為

- `skipButtonTapped` → `.run` effect：
  1. 建立預設帳戶 `Account(name: AccountType.cash.displayLabel, type: .cash, icon: "banknote", color: AccountType.cash.defaultColor)`
  2. `userSettingsClient.setBool(true, .hasCompletedOnboarding)`
  3. `await send(.accountsCreated)` → 進 done celebration

> ⚠️ 這偏離既有 `Account.defaultCashName = "Cash"`（comment 說「persisted to the database and must not vary by locale」）。新方案讓帳戶名用建立當下的 localized 值寫入 DB —— 之後切換系統語言不會魔幻變動 name（可接受：使用者隨時可在 AccountManagement 改名）。若希望保留 locale-independent 名稱，列在開放議題。

---

## AccountType.displayLabel 中文化

**檔案：** `Features/Sources/Domain/Enums/AccountType.swift`

```swift
public var displayLabel: String {
    switch self {
    case .cash:       String(localized: "account_type_cash")
    case .bank:       String(localized: "account_type_bank")
    case .creditCard: String(localized: "account_type_credit_card")
    case .eWallet:    String(localized: "account_type_e_wallet")
    }
}
```

**影響面（呼叫端，不需修改邏輯，但驗證顯示正常）：**
- `Features/Sources/Features/Onboarding/OnboardingView.swift`（本次重寫）
- `Features/Sources/Features/AccountManagement/AccountManagementView.swift` ×2
- `Features/Sources/Features/AccountManagement/AddEditAccountView.swift`
- `Features/Sources/Features/Dashboard/DashboardScreen.swift`

---

## 共用元件（Common 層新增）

### `WarmGradientBackground`

`Features/Sources/Common/Components/WarmGradientBackground.swift`

```swift
public struct WarmGradientBackground: View {
    public enum Variant { case top, bottomRight, center }
    let variant: Variant
    public var body: some View {
        ZStack {
            // RadialGradient: light = peach（#FFE4B8 → #FFF6E8 → #FAFAF7）
            //                 dark  = warm-brown（#4A2A0E → #1a0f08 → #050505）
            // center 隨 variant 變動
            // 兩顆 blur orbs（accent + income）疊在上面
        }
        .ignoresSafeArea()
    }
}
```

> Light/Dark 變體使用 `Color.Design.brandPrimary` 等已有 token；hex 值集中在 design/tokens/Tokens.swift（如尚未匯入則順手匯入需要的色）。

### `OnboardingPageDots`

`Features/Sources/Common/Components/OnboardingPageDots.swift`

3 個 dots，active dot 寬度 22×6（圓角 3）、其餘 6×6；顏色 = `Color.primary` (active) / `Color.primary.opacity(0.15)` (inactive)。動畫 250ms ease-out。

### `RevealOnAppear` modifier（內部）

實作放在 `OnboardingView.swift` 同檔案 file-private（單一使用點，避免汙染 Common）：

```swift
struct RevealOnAppear: ViewModifier {
    let delay: Double
    @State private var visible = false
    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 24)
            .animation(.easeOut(duration: 0.55).delay(delay), value: visible)
            .task { visible = true }
    }
}
```

---

## Localization Keys（Localizable.xcstrings）

### 新增

| Key | 中文值 | 英文值 |
|-----|--------|--------|
| `account_type_cash` | 現金 | Cash |
| `account_type_bank` | 銀行帳戶 | Bank |
| `account_type_credit_card` | 信用卡 | Credit Card |
| `account_type_e_wallet` | 電子錢包 | E-Wallet |
| `onboarding_welcome_card_eyebrow` | 總資產 · 開始追蹤 | Total balance · Starting fresh |
| `onboarding_welcome_chip_starting` | 即將開始 | Starting now |
| `onboarding_welcome_chip_on_device` | On-device | On-device |
| `onboarding_step_indicator_2` | Step 02 of 03 | Step 02 of 03 |
| `onboarding_step_indicator_3` | Step 03 of 03 | Step 03 of 03 |
| `onboarding_selection_title` | 選擇你的帳戶 | Pick your accounts |
| `onboarding_selection_subtitle` | 點擊新增。隨時可以調整。 | Tap to add. Adjust anytime. |
| `onboarding_selection_continue_format` | 繼續 · %lld 個 | Continue · %lld selected |
| `onboarding_selection_add_custom` | 新增其他帳戶 | Add custom account |
| `onboarding_custom_sheet_title` | 新增帳戶 | Add account |
| `onboarding_custom_sheet_subtitle` | 為它取個名字，選類型與顏色 | Name it, pick type and color |
| `onboarding_custom_name_label` | 帳戶名稱 | Account name |
| `onboarding_custom_name_placeholder` | 例如：玉山銀行 | e.g. Chase Checking |
| `onboarding_custom_type_label` | 類型 | Type |
| `onboarding_custom_color_label` | 顏色 | Color |
| `onboarding_custom_submit` | 新增 | Add |
| `onboarding_ready_total_label` | 總餘額 | Total balance |
| `onboarding_ready_account_count_format` | 已建立 %lld 個帳戶 | %lld account(s) created |
| `onboarding_done_title` | 歡迎加入 | Welcome aboard |
| `onboarding_done_subtitle` | 準備就緒，正在打開儀表板… | Ready to go · opening dashboard… |

### 修改

| Key | 新中文值 |
|-----|---------|
| `onboarding_welcome_subtitle` | On-device 智慧記帳，私密、優雅、零延遲。 |
| `onboarding_welcome_button` | 開始 |
| `onboarding_ready_title` | 你準備好了 |
| `onboarding_ready_subtitle` | 接著就交給 NeuLedger 為你看顧每一筆。 |
| `onboarding_ready_button` | 完成 |

### 拆分（取代原 `onboarding_welcome_title`）

| Key | 中文值 | 英文值 |
|-----|--------|--------|
| `onboarding_welcome_title_lead` | 每一塊錢， | Every NT$, |
| `onboarding_welcome_title_emphasis` | 都看得見 | seen |

> View 用兩段 `Text` 串接：第一段一般、第二段 `.italic()` + `.foregroundStyle(Color.Design.brandPrimary)`。原 `onboarding_welcome_title` key 刪除。

### 刪除（不再使用）

`onboarding_setup_title`、`onboarding_setup_subtitle`、`onboarding_setup_name_label`、`onboarding_setup_name_placeholder`、`onboarding_setup_type_label`、`onboarding_setup_button`、`onboarding_ready_balance_label`。

---

## 影響範圍

| 檔案 | 變動類型 |
|------|---------|
| `Features/Sources/Features/Onboarding/OnboardingFeature.swift` | 重寫（State / Action / body） |
| `Features/Sources/Features/Onboarding/OnboardingView.swift` | 重寫（4 個 step view + sheet 整合） |
| `Features/Sources/Features/Onboarding/CustomAccountFormFeature.swift` | **新增** sub-reducer |
| `Features/Sources/Features/Onboarding/CustomAccountFormView.swift` | **新增** sheet content view |
| `Features/Sources/Common/Components/WarmGradientBackground.swift` | **新增** |
| `Features/Sources/Common/Components/OnboardingPageDots.swift` | **新增** |
| `Features/Sources/Domain/Enums/AccountType.swift` | `displayLabel` 改 localized |
| `NeuLedger/Resources/Localizable.xcstrings` | 新增/修改/刪除多個 key（見上節） |
| `Features/Tests/FeaturesTests/OnboardingFeatureTests.swift` | 新增/重寫 TCA TestStore 測試 |

---

## 測試策略

### Unit / TCA TestStore（`FeaturesTests/OnboardingFeatureTests.swift`）

1. `welcome_to_accountSelection_via_startButton`
2. `accountSelection_toggleType_addsAndRemovesFromSelectedTypes`
3. `accountSelection_addCustomAccount_appendsToList`
4. `accountSelection_deleteCustomAccount_removesFromList`
5. `accountSelection_continueButton_navigatesToReady`
6. `ready_finishButton_writesAllAccounts_andTransitionsToDone`
   - 驗證 `accountClient.add` 被呼叫 N 次（N = selectedTypes + customAccounts）
   - 驗證 `userSettingsClient.setBool(true, .hasCompletedOnboarding)`
7. `done_dispatchesDelegateAfter1_6s`（用 `TestClock`）
8. `skip_fromWelcome_writesDefaultCashAccount_andCompletesOnboarding`
9. `skip_fromAccountSelection_writesDefaultCashAccount_andCompletesOnboarding`

### Domain test（`DomainTests/Enums/AccountTypeTests.swift`）

10. `displayLabel_returnsLocalizedStringForEachCase`（驗證非空 + 不為英文 raw value，避免回退到 fallback）

### Manual smoke

- iPhone 17 Pro simulator：跑 onboarding 全流程（welcome → 選 cash + bank → 自訂一個「悠遊卡」E-Wallet 紫色 → continue → 完成 → 進 dashboard 確認 3 個帳戶都出現）
- Skip from Welcome：確認 dashboard 出現 1 個「現金」帳戶
- Dark mode 切換：warm gradient / glass cards / chips 在 dark 下對比正確

---

## 不在範圍內

- **AI try-it 互動**（Step 3 設計稿原案）— 待 Foundation Models / `aiServiceClient` 實作完成後再做。
- **Confetti 動畫** — YAGNI，普通 fade 已足夠。
- **Starting balance 欄位** — 不改 Domain。需要時透過 transactions 補。
- **A/Cool/Neutral tone variants** — 直接採 warm，不做主題切換。
- **AccountType 圖示／色票的全 App 重新整理** — 本次只改 onboarding 卡片色票對齊設計稿（透過 `AccountType.defaultColor` extension），AccountManagement / Dashboard 等其他畫面顯示同樣會跟著更新；若哪裡看起來突兀，列在後續 follow-up。
- **預覽卡顯示真實餘額** — Welcome card 永遠顯示 `NT$ 0`，是裝飾不是資料。

---

## 實作順序建議

1. `AccountType.displayLabel` 改 localized + 新增 4 個 `account_type_*` key（小且安全，先合）
2. `WarmGradientBackground` + `OnboardingPageDots` 共用元件（無依賴，獨立可測）
3. `CustomAccountFormFeature` + `CustomAccountFormView` sheet（獨立小單元）
4. `OnboardingFeature` 重寫（state machine + effects）
5. `OnboardingView` 重寫（4 個 step + sheet 整合 + reveal 動畫）
6. Localization keys 補齊
7. 測試補齊 + 手動 smoke

---

## 開放議題

- **AccountType.defaultColor 是否要在本次同步改成 iOS 系統色？** Spec 預設「是」（`#8E8E93 / #0A84FF / #FF2D55 / #5E5CE6`），這會也改變 AccountManagement 既有帳戶卡片顏色顯示。若希望保留現有顏色不動，請在 review 時告知，會把這項從 spec 拆出。
- **Skip 路徑的預設帳戶名是否要保留 locale-independent？** Spec 預設改用 localized `displayLabel`（中文系統建立「現金」、英文系統建立「Cash」），原 `Account.defaultCashName = "Cash"` 與 `defaultCashColorHex` 兩個 private extension 屬性會被刪除。若希望保留為固定英文，請告知。

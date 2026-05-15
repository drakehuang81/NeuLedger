# NeuLedger Design — Session Handover

**Last updated**: May 15, 2026 (BudgetForm 完成 · 移除 Flow Demo)
**Project**: drakehuang81/NeuLedger (iOS, SwiftUI + TCA)
**Design direction**: B1 Warm Glass (暖色玻璃)

---

## How to use this file

If starting a new chat session, paste this file at the beginning. I (Claude) will read it and continue from where the last session left off — no need to re-explain context.

---

## Design system (locked in)

- **Direction**: B1 Warm Glass — orange accent on warm cream radial-gradient background, frosted glass cards, iOS native feel
- **Typography**: Bricolage Grotesque (display) · DM Sans (body) · DM Mono (numbers / eyebrow labels)
- **Accent**: `#E8835A` (warm orange) / `#FF6A00` (dark) — `ACC_COLORS.warm`
- **Income green**: `#34C759`  ·  **Expense red**: `#FF453A`  ·  **AI purple**: `#A66BF0`
- **Frame**: 402 × 874 (iPhone 17 Pro), Dynamic Island, status bar, home indicator
- **All HTMLs sit on**: `#ECE9E2` canvas background

### Shared primitives (in `accounts.jsx`, reused everywhere)
- `AccPhone({ children, dark })` — iPhone frame shell with status bar, dynamic island, home indicator
- `AccGlass({ children, radius, dark, style })` — frosted glass card
- `AccGlyph({ name, size, color, stroke })` — SVG icon set (plus, chevron-right, chevron-left, chevron-down, close, dots, edit, archive, star, card, cash, bank, phone, invest, crypto, check, trash, sparkle, arrow-up-right, arrow-down-left)
- `ACC_FONTS` — font family constants
- `ACC_COLORS` — `{ warm, warmDark, income, expense, ai }`
- `accBg(dark)` — radial gradient background
- All exported to `window` at bottom of `accounts.jsx`

### Conventions
- **Every HTML inlines its dependent `.jsx`** (sandbox blocks external script fetches with 401). Pattern:
  ```html
  <script type="text/babel" data-presets="react" data-from="foo.jsx">
  ${foo_jsx_content}
  </script>
  ```
- **Each feature file** = one `.jsx` defining screens + a `*Canvas` component that renders `<AccPhone>{screen}</AccPhone>` artboards in a 2-column grid
- **All HTMLs end with**: `ReactDOM.createRoot(document.getElementById('root')).render(<XxxCanvas/>);`
- **Always inline jsx into HTML before opening** (use `run_script` with `readFile` + `saveFile`)
- **Pre-check against actual code** in `drakehuang81/NeuLedger` GitHub before designing — don't invent features that don't exist in the Swift Reducer

---

## 📐 Code → Design Mapping (Feature × Design)

> Swift code path is rooted at `Features/Sources/Features/` in `drakehuang81/NeuLedger`. Design path is project root.

| # | Swift Feature directory | Reducer / View | Design `.jsx` | Design `.html` | Artboards | Status |
|---|---|---|---|---|---|---|
| 1 | `Onboarding/` | `OnboardingFeature` / `OnboardingView` | `onboarding-b-prototype.jsx`, `onboarding-variations.jsx` | `NeuLedger Onboarding B.html` | 4-step prototype | ✅ |
| 2 | `Dashboard/` | `DashboardFeature` / `DashboardView` | `dashboard-b1.jsx` | `NeuLedger Dashboard.html` | D1 + D2 + Add overlay | ✅ |
| 3 | `Transactions/AddTransaction*` | `AddTransactionFeature` / `AddTransactionView` | `add-transaction.jsx` | `NeuLedger Dashboard.html` (overlay) | 3-tab + AI extract + sheets | ✅ |
| 4 | `Transactions/TransactionDetail*` | `TransactionDetailFeature` / `TransactionDetailView` | `transaction-detail.jsx` | `NeuLedger Transaction Detail.html` | Read-only + edit/delete | ✅ |
| 5 | `Transactions/TransactionList*` (search) | `TransactionListFeature` (filter sheet) | `missing-screens.jsx` (filter form) | `NeuLedger Missing Screens.html` | Filter form | ✅ |
| 6 | `Analysis/` (top-level) | `AnalysisFeature` / `AnalysisView` | `analytics.jsx` (+ v1/v2/v3 explorations) | `NeuLedger Analytics.html` | Donut + bars + AI insight | ✅ |
| 7 | `Analysis/AIAssistant/` | `AIAssistantCardFeature` / `AIAssistantCardView` | (embedded in `analytics.jsx`) | — | (in Analytics) | 🟡 Embedded only — no standalone spec yet |
| 8 | `Transactions/` (search) | (per-list search) | `search.jsx` (+ v1/v2/v3) | `NeuLedger Search.html` | V1 Conversational | ✅ |
| 9 | `AccountManagement/` (list+detail) | `AccountManagementFeature` / `AccountManagementView` | `accounts.jsx` (AccountList, AccountDetail) | `NeuLedger Accounts and Settings.html` | List + Detail | ✅ |
| 10 | `AccountManagement/AddEditAccount*` | `AddEditAccountFeature` / `AddEditAccountView` | `add-edit-account.jsx` | `NeuLedger Add Edit Account.html` | Add default · Add filled · Edit w. nameError | ✅ |
| 11 | `Settings/` (root) | `SettingsFeature` / `SettingsView` | `settings.jsx` | `NeuLedger Accounts and Settings.html` | Main + AI + Appearance | ✅ |
| 12 | `Settings/SyncSettings/` | `SyncSettingsFeature` / `SyncSettingsView` | `sync-settings.jsx` | `NeuLedger Sync Settings.html` | Off · Migrating · Unavailable · Enabled | ✅ |
| 13 | `NotificationSettings/` | `NotificationSettingsFeature` / `NotificationSettingsView` | `notification-settings.jsx` | `NeuLedger Notification Settings.html` | All On · Permission Denied | ✅ |
| 14 | `BudgetManagement/` (root) | `BudgetManagementFeature` / `BudgetManagementView` | `budget.jsx` | `NeuLedger Budget and Notifications.html` | Main + Detail + quick-add sheet | ✅ |
| 15 | `BudgetManagement/BudgetForm*` | `BudgetFormFeature` / `BudgetFormView` | `budget-form.jsx` | `NeuLedger Budget Form.html` | Add default · Add filled · Edit w. amountError | ✅ |
| 16 | `BudgetManagement/` (inbox/recap) | (notifications inbox + monthly recap) | `notifications.jsx` | `NeuLedger Budget and Notifications.html` | Inbox + Recap | ✅ |
| 17 | `CategoryManagement/` | `CategoryManagementFeature` / `CategoryManagementView` (+ AddEditCategory) | `category-management.jsx` | `NeuLedger Category Management.html` | List (segmented) + Add/Edit | ✅ |
| 18 | `TagManagement/` | `TagManagementFeature` / `TagManagementView` (+ AddEditTag) | `tag-management.jsx` | `NeuLedger Tag Management.html` | Chip overview + usage list + Add/Edit | ✅ |
| 19 | `RecurringTransactions/` (mgmt) | `RecurringTransactionManagementFeature` / `View` | `recurring-management.jsx` | `NeuLedger Recurring Management.html` | Populated + Empty | ✅ |
| 20 | `RecurringTransactions/Form*` | `RecurringTransactionFormFeature` / `View` | `missing-screens.jsx` (recurring form) | `NeuLedger Missing Screens.html` | Form | ✅ |
| 21 | `CarrierManagement/` | `CarrierManagementFeature` (+ AddEditCarrier) | `missing-screens.jsx` (carrier list/form) | `NeuLedger Missing Screens.html` | List + Form | ✅ |
| 22 | `MainTab/` | `MainTabFeature` | (tab bar embedded in Dashboard) | — | — | ✅ (in Dashboard) |
| 23 | `AppFeature.swift` / `AppView.swift` | root composition | (覆蓋於 Onboarding + Main) | — | — | n/a |
| 24 | `Shared/` | shared components/extensions | (各設計檔內重建) | — | — | n/a |

**Statistics**
- Feature directories audited: **16**
- Design HTML files: **16** (含 Tokens + Missing Screens v1)
- Standalone reducers covered: **21/21** screen-level features
- Remaining: **AI Assistant Card** (standalone spec, optional)

---

## ✅ Done (HTML files in project root)

| Screen | File | Notes |
|---|---|---|
| Onboarding | `NeuLedger Onboarding B.html` | 4-step prototype |
| Dashboard | `NeuLedger Dashboard.html` | D1 + D2 layouts |
| Add Transaction | `NeuLedger Dashboard.html` (overlay) | 3-tab flow, AI extract, sheets |
| Transaction Detail | `NeuLedger Transaction Detail.html` | Read-only + edit/delete actions |
| Analytics | `NeuLedger Analytics.html` | Data-rich (donut, bars, AI insight) |
| Search | `NeuLedger Search.html` | V1 Conversational (Perplexity-style) |
| Accounts + Settings | `NeuLedger Accounts and Settings.html` | List + detail + add; settings main + AI + Appearance |
| Budget + Notifications | `NeuLedger Budget and Notifications.html` | Budget main/detail/sheet + Inbox/Recap/Recurring |
| Missing Screens v1 | `NeuLedger Missing Screens.html` | Carrier List/Form, Recurring Form, Filter Form |
| Category Management | `NeuLedger Category Management.html` | List (expense/income segmented) + Add/Edit form |
| Tag Management | `NeuLedger Tag Management.html` | Chip overview + usage list + Add/Edit form |
| Recurring Management | `NeuLedger Recurring Management.html` | List (populated · monthly summary + Active/Paused sections) + Empty state with quick-add suggestions |
| iCloud Sync Settings | `NeuLedger Sync Settings.html` | 4 artboards: Off / Migrating(progress) / Unavailable / Enabled |
| Notification Settings | `NeuLedger Notification Settings.html` | 2 artboards: All On / Permission Denied banner |
| Add / Edit Account Form | `NeuLedger Add Edit Account.html` | 3 artboards: Add default / Add filled / Edit w. nameError |
| Budget Form | `NeuLedger Budget Form.html` | 3 artboards: Add default / Add filled (per-day breakdown) / Edit w. amountError |
| Design Tokens | `NeuLedger Design Tokens.html` | Reference doc |

---

## 🚧 TODO — Remaining screens

### Low priority
1. **AI Assistant Card** (standalone component)
   - Code: `Features/Sources/Features/Analysis/AIAssistant/AIAssistantCardView.swift`
   - It's already embedded inside Analytics design but might warrant a dedicated component spec / state matrix (idle / loading / success / error / empty)

---

## Process to design each remaining screen

1. **Read the Swift code first** using `github_read_file` — don't invent features
   - Look at `*Feature.swift` for state/actions
   - Look at `*View.swift` for current implementation details
2. **Design 1 mockup per screen** (no variants — codebase is locked); cover all UI-visible states from `State` × conditional rendering
3. **Create `<feature>.jsx`** with screens + a `*Canvas` wrapper
4. **Create `NeuLedger <Feature>.html`** that inlines `accounts.jsx` (for primitives) + the feature jsx
5. **Use `run_script` to inline jsx into html** before calling `done`
6. **Update this HANDOVER.md** when a TODO is finished — both the **Code → Design Mapping** table AND the **Done** table

---

## File structure reminder

```
/
├── accounts.jsx                              ← Shared primitives + Account list/detail
├── add-edit-account.jsx                      ← ✅ Add/Edit Account Form
├── budget.jsx                                ← Budget screens (list / detail / quick-add sheet)
├── budget-form.jsx                           ← ✅ Budget Form (new — full Add/Edit)
├── notifications.jsx                         ← Notifications + Recap
├── notification-settings.jsx                 ← ✅ Notification Settings (new)
├── settings.jsx                              ← Settings main + sub-pages
├── sync-settings.jsx                         ← ✅ iCloud Sync Settings (new)
├── category-management.jsx                   ← ✅ Done
├── tag-management.jsx                        ← ✅ Done
├── recurring-management.jsx                  ← ✅ Done
├── missing-screens.jsx                       ← Carrier + Recurring Form + Filter
├── search.jsx                                ← Search V1
├── analytics.jsx                             ← Analytics
├── transaction-detail.jsx                    ← Transaction detail
├── add-transaction.jsx                       ← Add transaction flow
├── dashboard-b1.jsx                          ← Dashboard D1 + D2
├── onboarding-*.jsx                          ← Onboarding
└── NeuLedger *.html                          ← One per feature, jsx inlined
```

---

## Snippets you'll need in a new session

**To design the only remaining TODO** (AI Assistant Card standalone spec), tell the new Claude:
> Read HANDOVER.md, then design the **AI Assistant Card** standalone component spec.
> Read `Features/Sources/Features/Analysis/AIAssistant/AIAssistantCardView.swift` and `AIAssistantCardFeature.swift`.
> Then create `ai-assistant-card.jsx` + `NeuLedger AI Assistant Card.html`, covering all states (idle / loading / success / error / empty).

That's enough — the new session will read this file and pick up from there.

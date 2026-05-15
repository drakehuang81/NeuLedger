# NeuLedger Design — Session Handover

**Last updated**: May 15, 2026 (B1 Warm Glass code rollout — 13/14 features migrated)
**Project**: drakehuang81/NeuLedger (iOS, SwiftUI + TCA)
**Design direction**: B1 Warm Glass (暖色玻璃)

---

## 🛠 B1 Warm Glass — Swift Code Rollout Status

Tracks whether each design has actually been ported to the Swift codebase
(separate from the design-side `Done` table further down). All reducer
logic is intentionally untouched — only `*View.swift` files were rewritten.

| # | Design jsx | Swift View(s) | Code status |
|---|---|---|---|
| 1 | `onboarding-b-prototype.jsx` | `Onboarding/OnboardingView.swift` | ✅ |
| 2 | `dashboard-b1.jsx` | `Dashboard/DashboardScreen.swift` + `Sections/*` | ✅ |
| 3 | `add-transaction.jsx` | `Dashboard/AddTransactionView.swift` | ✅ |
| 4 | `transaction-detail.jsx` | `Transactions/TransactionDetailView.swift` | ✅ |
| 5 | `search.jsx` | `Transactions/TransactionsView.swift` | ✅ |
| 6 | `analytics.jsx` (V3 Data-rich) | `Analysis/AnalysisView.swift` + `Sections/*` | ✅ |
| 7 | `accounts.jsx` (list) | `AccountManagement/AccountManagementView.swift` | ✅ |
| 8 | `add-edit-account.jsx` | `AccountManagement/AddEditAccountView.swift` | ✅ |
| 9 | `settings.jsx` | `Settings/SettingsView.swift` | ✅ |
| 10 | `sync-settings.jsx` | `Settings/SyncSettings/SyncSettingsView.swift` | ✅ |
| 11 | `notification-settings.jsx` | `NotificationSettings/NotificationSettingsView.swift` | ✅ |
| 12 | `budget.jsx` (list) | `BudgetManagement/BudgetManagementView.swift` | ✅ |
| 13 | `budget-form.jsx` | `BudgetManagement/BudgetFormView.swift` | ✅ |
| 14 | `notifications.jsx` (Inbox + Recap + Subs overview) | — | ❌ feature does not exist in code yet — see "Deferred" below |
| 15 | `category-management.jsx` | `CategoryManagement/*View.swift` (list + form) | ✅ |
| 16 | `tag-management.jsx` | `TagManagement/*View.swift` (list + form) | ✅ |
| 17 | `recurring-management.jsx` | `RecurringTransactions/RecurringTransactionManagementView.swift` | ✅ |
| 18 | `missing-screens.jsx` (Filter / Carrier list+form / Recurring Form) | `Transactions/FilterView.swift`, `CarrierManagement/*View.swift`, `RecurringTransactions/RecurringTransactionFormView.swift` | ✅ |

**Statistics**: 17 of 18 design groups ported · `notifications.jsx` deferred.

### Deferred — `notifications.jsx` (#14)

Unlike every other entry, this is **not a "redesign" of an existing
Swift screen** — the codebase has no in-app notification inbox, monthly
recap, or subscription-overview feature today. Building it requires
new work: a `Notification` domain entity (with kinds: budget-warn /
recurring / ai-insight / recap-ready / bill / detected / goal), a
`notificationClient`, a TCA reducer, the two views from the artboards,
and a discoverable entry point (likely a bell affordance on Dashboard
or a Settings row). Treat the design as a forward-looking spec until
that scope lands; until then, no Swift action is owed against it.

### Trade-offs left as inline TODOs

Several features were redesigned with cosmetic fidelity but skipped
state-dependent flourishes that the reducer doesn't yet expose. Each
is committed as a `// TODO:` so `git grep TODO` surfaces them:

- Analysis KPIStrip — prior-period delta caption
- Analysis CategoryDonutCard — `CategoryProportion` lacks color/icon
- Analysis MonthlyTrendCard — 6-month windowed transactions missing
- AccountManagement list — `.onMove` reorder dropped; Net Worth delta missing; AccountType has no .invest/.crypto
- AddEditAccount — Opening Balance / Set as Primary / AI suggestion footer all need reducer + entity changes
- CategoryManagement list — `.onMove` reorder dropped
- TagManagement list — usage count placeholder (needs `tagClient` extension)
- RecurringTransactionManagement list — frequency colour hex literals; account name + smart suggestions deferred
- BudgetManagement list — per-budget `used` spending + Category icon/color missing from state
- NotificationSettings recurring row — per-item icon/color + nextDue subtitle
- SyncSettings — last-sync time, 3-cell quick stats, migration X/Y items + ETA

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

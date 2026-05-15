# NeuLedger Design — Session Handover

**Last updated**: May 15, 2026 (Recurring List added)
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
| First-run Flow Demo | `NeuLedger Flow Demo.html` | 22-sec auto-playing demo |
| Design Tokens | `NeuLedger Design Tokens.html` | Reference doc |

---

## 🚧 TODO — Remaining screens (from GitHub code audit)

These exist in the codebase but **don't have design mockups yet**. Priority order:

### High priority
1. **iCloud Sync Settings sub-page**
   - Code: `Features/Sources/Features/Settings/SyncSettings/SyncSettingsView.swift` (9836 bytes — substantial)
   - Sub-page under Settings
   - Probably has: sync toggle, last sync time, conflict resolution, storage usage, sign-in to iCloud

### Medium priority
2. **Notification Settings (in-app preferences)**
   - Code: `Features/Sources/Features/NotificationSettings/NotificationSettingsView.swift` (10727 bytes)
   - We designed the **Inbox** (the notifications themselves) but not the **settings page** that controls them
   - Probably has: master toggle, per-type toggles (budget alerts, recurring reminders, monthly recap), notification time, sound

3. **AddEditAccount Form (current Account design only has list + detail)**
   - Code: `Features/Sources/Features/AccountManagement/AddEditAccountView.swift`
   - We have an "Add Account" sheet in the existing design, but should double-check it matches the real fields

4. **BudgetForm**
   - Code: `Features/Sources/Features/BudgetManagement/BudgetFormView.swift` (5180 bytes)
   - Current Budget design has a "quick add" sheet — need to verify it matches full BudgetForm spec

### Low priority
5. **AI Assistant Card** (standalone component)
   - Code: `Features/Sources/Features/Analysis/AIAssistant/AIAssistantCardView.swift`
   - It's already embedded inside Analytics design but might warrant a dedicated component spec

---

## Process to design each remaining screen

1. **Read the Swift code first** using `github_read_file` — don't invent features
   - Look at `*Feature.swift` for state/actions
   - Look at `*View.swift` for current implementation details
2. **Design 1 mockup per screen** (no variants — codebase is locked)
3. **Create `<feature>-mgmt.jsx`** with screens + a `*Canvas` wrapper
4. **Create `NeuLedger <Feature>.html`** that inlines `accounts.jsx` (for primitives) + the feature jsx
5. **Use `run_script` to inline jsx into html** before calling `done`
6. **Update this HANDOVER.md** when a TODO is finished

---

## File structure reminder

```
/
├── accounts.jsx                              ← Shared primitives + Account screens
├── budget.jsx                                ← Budget screens
├── notifications.jsx                         ← Notifications + Recap
├── settings.jsx                              ← Settings main + sub-pages
├── category-management.jsx                   ← ✅ Done
├── tag-management.jsx                        ← ✅ Done
├── recurring-management.jsx                  ← ✅ Done
├── missing-screens.jsx                       ← Carrier + Recurring Form + Filter
├── search.jsx                                ← Search V1
├── analytics.jsx                             ← Analytics
├── transaction-detail.jsx                    ← Transaction detail
├── add-transaction.jsx                       ← Add transaction flow
├── dashboard-b1.jsx                          ← Dashboard D1 + D2
├── onboarding-*.jsx, flow-*.jsx              ← Onboarding + Flow Demo
└── NeuLedger *.html                          ← One per feature, jsx inlined
```

---

## Snippets you'll need in a new session

**To start the next screen** (e.g. iCloud Sync Settings), tell the new Claude:
> Read HANDOVER.md, then design the **iCloud Sync Settings** sub-page.
> First read the Swift code at `Features/Sources/Features/Settings/SyncSettings/SyncSettingsView.swift` and `SyncSettingsFeature.swift` from `drakehuang81/NeuLedger` repo.
> Then create `sync-settings.jsx` + `NeuLedger Sync Settings.html`, following the same pattern as `recurring-management.jsx`.

That's enough — the new session will read this file and pick up from there.

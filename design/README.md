# NeuLedger — Design Handoff Package

> **Last updated**: May 15, 2026
> **Direction (locked)**: B1 Warm Glass — warm orange accent (`#E8835A`) on cream radial-gradient, frosted glass cards, iOS-native feel
> **Target codebase**: [drakehuang81/NeuLedger](https://github.com/drakehuang81/NeuLedger) (iOS, SwiftUI + The Composable Architecture)

---

## How to use this package

1. **Open `index.html` in a browser** — landing page that links to every screen mockup.
2. **Drop tokens into your Xcode target** — `tokens/Tokens.swift` is ready to paste in. Register the three Google Fonts (`BricolageGrotesque`, `DMSans`, `DMMono`) in `Info.plist` under `UIAppFonts` and bundle the `.ttf`/`.otf` files.
3. **For each screen you implement**, open the matching HTML in `screens/` for visual reference and the matching `.jsx` in `source/` for exact pixel values, spacing, and copy. The JSX files are the source of truth — every number in them is intentional.
4. **Read `HANDOVER.md`** to see what's done, what's still in the TODO queue, and the process used to design each screen against the Swift Reducer/View.

> The HTML files are **prototypes for visual reference** — do not transplant the React code. Rebuild each screen with native SwiftUI components.

---

## Package layout

```
handoff/
├── README.md            ← you are here
├── HANDOVER.md          ← live dev tracker: done list, TODO queue, process notes
├── index.html           ← launchpad — links to every screen
│
├── tokens/
│   ├── Tokens.swift     ← SwiftUI: Color / Font / Spacing / Radius / Shadow / Motion + .glassCard() modifier
│   ├── tokens.css       ← CSS custom properties (for any web surface)
│   └── tokens.json      ← Style Dictionary input
│
├── screens/             ← Self-contained HTML mockups (open in any browser)
│   ├── 01-Onboarding.html
│   ├── 02-Dashboard.html                  (+ Add Transaction overlay)
│   ├── 03-Transaction-Detail.html
│   ├── 04-Analytics.html
│   ├── 05-Search.html                     (Perplexity-style conversational)
│   ├── 06-Accounts-Settings.html
│   ├── 07-Budget-Notifications.html       (Budget main/detail + Inbox/Recap)
│   ├── 08-Missing-Screens.html            (Carrier · Recurring Form · Filter)
│   ├── 09-Category-Management.html
│   ├── 10-Tag-Management.html
│   ├── 11-Recurring-Management.html       (List · populated + empty state)
│   ├── 12-Flow-Demo.html                  (22 s auto-playing first-run demo)
│   └── 99-Design-Tokens.html              (visual reference of every token)
│
└── source/              ← Original JSX — exact spec for each component
    ├── accounts.jsx                       ★ Shared primitives: AccPhone, AccGlass, AccGlyph, ACC_COLORS, accBg
    ├── dashboard-b1.jsx
    ├── add-transaction.jsx
    ├── transaction-detail.jsx
    ├── analytics.jsx
    ├── search.jsx
    ├── settings.jsx
    ├── budget.jsx
    ├── notifications.jsx
    ├── category-management.jsx
    ├── tag-management.jsx
    ├── recurring-management.jsx
    ├── missing-screens.jsx
    ├── onboarding-b-prototype.jsx
    ├── flow-screens.jsx · flow-controller.jsx
    └── ios-frame.jsx
```

---

## Visual system at a glance

### Color

| Token | Light | Dark | Use |
|---|---|---|---|
| **Accent** | `#E8835A` warm orange | `#FF6A00` | All CTAs, primary actions, brand identity |
| **Income** | `#34C759` | — | Positive amounts, success states |
| **Expense** | `#FF453A` | — | Negative amounts, destructive |
| **AI purple** | `#A66BF0` | — | AI features (NL extraction, insights) |
| **Canvas** | `#ECE9E2` | — | The cream around the phone frame |
| **Warm radial bg** (inside phone) | `#FFE4D2 → #FBF1E5 → #F6ECDF` | `#4A2A0E → #1a0f08 → #050505` | The page background inside every screen |
| **Glass fill** | `rgba(255,255,255,0.70)` | `rgba(255,255,255,0.06)` | All cards. Pair with `backdrop-filter: blur(20px) saturate(180%)` |

### Type pairing

Three fonts, never more:

- **Bricolage Grotesque** — display, headings, large amounts (semibold, negative tracking)
- **DM Sans** — body, UI text, buttons
- **DM Mono** — *every number*, ALL-CAPS eyebrow labels, tag/badge text

> ⚠️ **The Mono / Display contrast carries the brand.** Hero amounts use Bricolage; list amounts use DM Mono. Don't mix them up.

### Frame

All mockups are drawn at **402 × 874** (iPhone 17 Pro logical size), with the Dynamic Island, status bar, and home indicator drawn in. Treat that as the design canvas, not a hard constraint — your SwiftUI build is fluid.

### Glass card recipe (SwiftUI)

```swift
RoundedRectangle(cornerRadius: 18, style: .continuous)
    .fill(Color.white.opacity(0.70))
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Color.white.opacity(0.85), lineWidth: 0.5)
    )
    .shadow(color: Color(hex: 0x785028).opacity(0.06), radius: 12, y: 4)
```

(See `tokens/Tokens.swift` — there's a `.glassCard()` View modifier that wraps this.)

---

## Screen index (status)

| # | Screen | Source JSX | Maps to Swift Feature |
|---|---|---|---|
| 01 | Onboarding (4-step prototype) | `onboarding-b-prototype.jsx` | Onboarding |
| 02 | Dashboard + Add Transaction sheet | `dashboard-b1.jsx`, `add-transaction.jsx` | Dashboard / AddTransaction |
| 03 | Transaction Detail | `transaction-detail.jsx` | TransactionDetail |
| 04 | Analytics (donut + bars + AI) | `analytics.jsx` | Analysis / AIAssistant |
| 05 | Search (conversational) | `search.jsx` | Search |
| 06 | Accounts + Settings | `accounts.jsx`, `settings.jsx` | AccountManagement / Settings |
| 07 | Budget + Notifications Inbox | `budget.jsx`, `notifications.jsx` | BudgetManagement / NotificationInbox |
| 08 | Carrier · Recurring Form · Filter | `missing-screens.jsx` | EinvoiceCarrier / RecurringForm / TransactionFilter |
| 09 | Category Management | `category-management.jsx` | CategoryManagement |
| 10 | Tag Management | `tag-management.jsx` | TagManagement |
| 11 | Recurring Management List | `recurring-management.jsx` | RecurringTransactionManagement |
| 12 | First-run flow demo (22s auto-play) | `flow-screens.jsx` | — (storyboard) |
| 99 | Design Tokens reference | — | — |

### Not yet designed (see `HANDOVER.md`)

- iCloud Sync Settings sub-page
- Notification Settings (in-app preferences page, not the inbox)
- AddEditAccount form (verify against current Add Account sheet)
- BudgetForm (verify against current quick-add sheet)
- AI Assistant Card (standalone component spec)

---

## Recommended build order

1. **Tokens first** — paste `Tokens.swift`, register fonts, get the warm radial gradient + glass card recipe rendering correctly. If the cream/warmth or blur isn't right, **stop and fix it before building anything else**. The whole identity is in this layer.
2. **Dashboard** — biggest visual real estate, exercises every primitive (glass card, mono numbers, account-tinted icons, AI sparkle). Once Dashboard looks right, every other screen falls out.
3. **Add Transaction NL sheet** — core differentiator. AI extraction can be mocked at first.
4. **List screens** (Accounts, Categories, Tags, Recurring) — all share the same row pattern; build one row component and reuse.
5. **Detail / Form screens** in any order.

---

## Conventions used inside the JSX

- Every primitive lives in `accounts.jsx` (shared) and is exported to `window` at the bottom. Feature files reuse them via globals.
- Each feature file ends with a `*Canvas` component that renders 2–4 `<AccPhone>` artboards in a grid — that's just the presentation layer for review. The actual screens are the inner `function ScreenName({ dark })` components above the Canvas.
- HTML files self-contain their dependencies (each one inlines its JSX) so they work offline without a build step.

---

## Questions

If anything in the spec is ambiguous, **the JSX is the source of truth**. Every padding, gap, font size, and color is a literal value in there.

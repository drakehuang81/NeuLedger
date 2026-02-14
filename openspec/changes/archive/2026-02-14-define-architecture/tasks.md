## 1. Spec Review & Finalization

- [x] 1.1 Cross-check all 5 specs for internal consistency (entity names, field names, enum values align across specs)
- [x] 1.2 Verify UI spec screen designs reference correct entity fields from domain model spec
- [x] 1.3 Verify AI spec `@Generable` field names align with domain model entity fields
- [x] 1.4 Confirm app-features spec validation rules align with domain model required/optional fields

## 2. Pencil Design — Design System Foundation

- [x] 2.1 Create `.pen` file with color system variables (system semantic colors + 4 brand colors from Asset Catalog)
- [x] 2.2 Define typography styles using system text styles (largeTitle, title2, headline, body, caption, monospaced amount)
- [x] 2.3 Build reusable components: TransactionRow, AccountCard, CategoryChip, TagPill
- [x] 2.4 Build reusable components: BalanceDisplay, InsightCard, BudgetGauge
- [x] 2.5 Create Liquid Glass surface variants for cards, action buttons, and containers

## 3. Pencil Design — Onboarding Flow

- [x] 3.1 Design Onboarding Step 1: Welcome page (app icon, title, value proposition)
- [x] 3.2 Design Onboarding Step 2: Account setup (Form with name, type picker)
- [x] 3.3 Design Onboarding Step 3: Ready page (glassProminent CTA button)
- [x] 3.4 Design & Refine App Icon (Liquid Glass style, Brand Colors)

## 4. Pencil Design — Dashboard Screen

- [x] 4.1 Design Dashboard layout: Balance Card (glass surface, monospaced amount)
- [x] 4.2 Design Dashboard: Quick Actions bar (GlassEffectContainer with 3 interactive capsules)
- [x] 4.3 Design Dashboard: Account Cards (horizontal scroll, glass surfaces)
- [x] 4.4 Design Dashboard: Recent Transactions section (List with TransactionRow components)
- [x] 4.5 Design Dashboard: AI Insight Card (glass surface, sparkles icon, dismissable)

## 5. Pencil Design — Add Transaction Sheet

- [x] 5.1 Design Add Transaction: Amount input area (large monospaced digits, currency prefix)
- [x] 5.2 Design Add Transaction: Note field with AI sparkle indicator
- [x] 5.3 Design Add Transaction: Category picker grid (LazyVGrid, glass chip states)
- [x] 5.4 Design Add Transaction: Account selector, Date picker, Tag pills
- [x] 5.5 Design Add Transaction: Toolbar with Cancel/Save glass buttons

## 6. Pencil Design — Transaction List & Detail

- [x] 6.1 Design Transaction List: NavigationStack with searchable bar and filter chips
- [x] 6.2 Design Transaction List: Grouped sections by date with TransactionRow cells
- [x] 6.3 Design Transaction List: Swipe actions (edit/delete)
- [x] 6.4 Design Transaction Detail: Form layout with full transaction info
- [x] 6.5 Design Transaction Detail: Edit/Delete toolbar actions, AI badge

## 7. Pencil Design — Analysis Screen

- [x] 7.1 Design Analysis: Period selector (segmented Picker)
- [x] 7.2 Design Analysis: Summary card (income/expense/net, glass surface)
- [x] 7.3 Design Analysis: Pie chart (category spending breakdown)
- [x] 7.4 Design Analysis: Bar chart (daily/weekly trend)
- [x] 7.5 Design Analysis: Budget progress section (BudgetGauge components)
- [x] 7.6 Design Analysis: AI Insight section (glass card)

## 8. Pencil Design — Settings Screen

- [x] 8.1 Design Settings: Form with grouped sections (accounts, categories, budgets, tags)
- [x] 8.2 Design Settings: Preferences section (default account, language, AI toggles)
- [x] 8.3 Design Settings: Data section (export buttons) and About section


## 9. Pencil Design — System States & Navigation

- [x] 9.1 Design Global TabBar: Floating glass capsule with integrated Actions/Search context
- [x] 9.2 Design Custom Alerts: Glass-morphic popup for confirmation, success, and error states
- [x] 9.3 Design Empty & Error States: Placeholder illustrations for empty lists and offline status

## 10. Design Validation

- [x] 10.1 Review all screens for Dark Mode appearance
- [x] 10.2 Review all screens for Dynamic Type scaling (ensure no hardcoded sizes)
- [x] 10.3 Verify consistent Liquid Glass usage across all screens
- [x] 10.4 Verify 44pt minimum touch targets on all interactive elements
- [x] 10.5 Take screenshots of all completed screens for documentation

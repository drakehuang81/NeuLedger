
# Delta Spec: design-system (Empty States)

## ADDED Requirements

### Requirement: Empty State Component
The design system SHALL provide a reusable `EmptyStateView` for consistent messaging when data is absent.

#### Scenario: Displaying Empty State
- **WHEN** a view has no data to display
- **THEN** show a centered layout containing:
  - An illustration (SF Symbol + Shape)
  - A title text (Headline style)
  - An optional description text (Subheadline style, secondary color)
  - An optional action button (Glass Button style)

#### Scenario: Dashboard Empty State Variant
- **WHEN** used in Dashboard
- **THEN** use the "Welcome" illustration
- **AND** title: "尚無交易"
- **AND** description: "開始記下您的第一筆花費吧！"
- **AND** action button: "記一筆" (Primary style)

#### Scenario: Analysis Empty State Variant
- **WHEN** used in Analysis
- **THEN** use the "Chart" illustration (e.g., `chart.pie` symbol)
- **AND** title: "此期間無資料"
- **AND** description: "嘗試選擇不同的日期範圍"
- **AND** no action button

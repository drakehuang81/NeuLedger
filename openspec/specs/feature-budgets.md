# Spec: Feature - Budgets
**Purpose**: Define the budget management logic, including creation, progress calculation, and the BudgetClient interface.

## Requirements

### Requirement: 預算管理（Budget Management）

#### Scenario: 建立預算
- **WHEN** 使用者在設定 → 預算 → 新增
- **THEN** 設定：
    - 名稱（必填）
    - 金額上限（必填）
    - 週期：每週 / 每月 / 每年
    - 分類（可選）：不指定 = 總支出預算；指定 = 該分類預算
- **AND** 預算在指定週期結束後自動重置（重新開始計算）

#### Scenario: 預算進度顯示
- **WHEN** 使用者在 Analysis 頁查看預算
- **THEN** 顯示：已花費 / 預算金額、百分比進度條
- **AND** 進度條顏色規則：
    - < 80%：系統綠色
    - 80% ~ 100%：`warningAmber`
    - > 100%：`expenseRed`

#### Scenario: 預算停用
- **WHEN** 使用者停用一個預算
- **THEN** 預算不再出現在 Analysis 頁
- **AND** 可以在設定中重新啟用

### Requirement: 驗證規則（Validation Rules）

#### Scenario: 預算驗證
- **WHEN** 使用者新增預算
- **THEN** 金額必須 > 0
- **AND** 名稱不得為空

### Requirement: BudgetClient Interface
The system SHALL provide a `BudgetClient` dependency for managing budgets.

#### Scenario: BudgetClient Definition
- **WHEN** defining the budget service interface in `Features/Domain/Clients/BudgetClient.swift`
- **THEN** it SHALL provide the following methods:

```swift
@DependencyClient
public struct BudgetClient: Sendable {
    public var fetchAll: @Sendable () async throws -> [Budget]
    public var fetchActive: @Sendable () async throws -> [Budget]
    public var add: @Sendable (Budget) async throws -> Void
    public var update: @Sendable (Budget) async throws -> Void
    public var delete: @Sendable (Budget.ID) async throws -> Void
}
```

- **AND** it SHALL be registered via `TestDependencyKey` and `DependencyValues` at key path `\.budgetClient`.

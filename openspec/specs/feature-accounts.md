# Spec: Feature - Accounts
**Purpose**: Define the account management logic, including default account creation, archiving, validations, and the AccountClient interface.

## Requirements

### Requirement: 帳戶管理（Account Management）

#### Scenario: 預設帳戶
- **WHEN** 使用者首次使用 App（Onboarding）
- **THEN** 建立一個預設帳戶：
    - 名稱：「現金」
    - 類型：`.cash`
    - 圖示：`banknote`
- **AND** 此帳戶設為預設帳戶

#### Scenario: 新增帳戶
- **WHEN** 使用者在設定 → 帳戶 → 新增
- **THEN** 必填：名稱、類型
- **AND** 可選：圖示（從 SF Symbol 清單選擇）、顏色
- **AND** 帳戶名稱不得重複

#### Scenario: 封存帳戶
- **WHEN** 使用者封存一個帳戶
- **THEN** 該帳戶從新增交易的帳戶選擇器中隱藏
- **AND** 歷史交易仍可查看
- **AND** 帳戶餘額仍在 Dashboard 中可見（標記為已封存）

#### Scenario: 不可刪除帳戶
- **GIVEN** 帳戶有關聯的交易記錄
- **WHEN** 使用者嘗試刪除
- **THEN** 只能封存，不能永久刪除（保護資料完整性）

### Requirement: 驗證規則（Validation Rules）

#### Scenario: 帳戶驗證
- **WHEN** 使用者新增帳戶
- **THEN** 名稱不得為空、不得與現有帳戶重複

### Requirement: AccountClient Balance Computation
The `AccountClient` SHALL provide a method to compute account balance on-the-fly.

#### Scenario: AccountClient with Balance
- **WHEN** the Dashboard needs to display an account's balance
- **THEN** `AccountClient` SHALL provide:

```swift
@DependencyClient
public struct AccountClient: Sendable {
    public var fetchAll: @Sendable () async throws -> [Account]
    public var fetchActive: @Sendable () async throws -> [Account]
    public var add: @Sendable (Account) async throws -> Void
    public var update: @Sendable (Account) async throws -> Void
    public var archive: @Sendable (Account.ID) async throws -> Void
    public var delete: @Sendable (Account.ID) async throws -> Void
    public var computeBalance: @Sendable (Account.ID) async throws -> Decimal
}
```

- **AND** `computeBalance` SHALL sum all related transactions to compute the balance on-the-fly.

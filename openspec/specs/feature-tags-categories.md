# Spec: Feature - Tags & Categories
**Purpose**: Define the category and tag management logic, including default categories, automatic tag creation, and the TagClient.

## Requirements

### Requirement: 分類管理（Category Management）

#### Scenario: 預設分類清單
- **WHEN** App 首次啟動
- **THEN** 自動建立以下預設分類：

**支出分類：**

| 名稱 | SF Symbol | 備註 |
|------|-----------|------|
| 飲食 | `fork.knife` | 餐飲、飲料、零食 |
| 交通 | `car.fill` | 捷運、公車、計程車、油錢 |
| 娛樂 | `gamecontroller.fill` | 電影、遊戲、訂閱 |
| 購物 | `bag.fill` | 服飾、3C、日用品 |
| 居住 | `house.fill` | 房租、房貸、管理費 |
| 生活繳費 | `bolt.fill` | 水電瓦斯、電信、網路 |
| 醫療 | `cross.case.fill` | 看診、藥品、保險 |
| 教育 | `book.fill` | 課程、書籍、學費 |
| 社交 | `person.2.fill` | 聚餐、送禮、紅包 |
| 其他支出 | `ellipsis.circle.fill` | 未分類支出 |

**收入分類：**

| 名稱 | SF Symbol | 備註 |
|------|-----------|------|
| 薪資 | `briefcase.fill` | 定期薪水 |
| 獎金 | `star.fill` | 年終、績效獎金 |
| 副業 | `laptopcomputer` | 接案、兼差 |
| 投資 | `chart.line.uptrend.xyaxis` | 股票、基金收益 |
| 收禮 | `gift.fill` | 紅包、禮金 |
| 其他收入 | `ellipsis.circle.fill` | 未分類收入 |

- **AND** 預設分類的 `isDefault = true`，不可刪除但可編輯名稱/圖示/顏色
- **AND** 使用者可新增自訂分類

#### Scenario: 分類排序
- **WHEN** 使用者在分類管理中拖動分類
- **THEN** 更新 `sortOrder`，影響分類選擇器的顯示順序

### Requirement: 標籤管理（Tag Management）

#### Scenario: 建立與使用標籤
- **WHEN** 使用者在新增交易時輸入標籤
- **THEN** 自動完成現有標籤
- **AND** 若輸入的標籤不存在，自動建立新標籤
- **AND** 每筆交易可有 0 個或多個標籤

#### Scenario: 管理標籤
- **WHEN** 使用者在設定 → 標籤
- **THEN** 可以查看所有標籤、編輯名稱/顏色、刪除標籤
- **AND** 刪除標籤時，從所有交易中移除該標籤（不影響交易本身）

### Requirement: TagClient Interface
The system SHALL provide a `TagClient` dependency for managing user-defined tags.

#### Scenario: TagClient Definition
- **WHEN** defining the tag service interface in `Features/Domain/Clients/TagClient.swift`
- **THEN** it SHALL provide the following methods:

```swift
@DependencyClient
public struct TagClient: Sendable {
    public var fetchAll: @Sendable () async throws -> [Tag]
    public var add: @Sendable (Tag) async throws -> Void
    public var update: @Sendable (Tag) async throws -> Void
    public var delete: @Sendable (Tag.ID) async throws -> Void
}
```

- **AND** it SHALL be registered via `TestDependencyKey` and `DependencyValues` at key path `\.tagClient`.

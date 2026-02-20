
# Delta Spec: app-features (Empty States)

## ADDED Requirements

### Requirement: Dashboard Empty State User Stories

#### Scenario: 快速新增支出 (from Dashboard Empty State)
- **GIVEN** 使用者在 Dashboard 且無任何交易
- **WHEN** 點擊 Empty State 的「記一筆」按鈕
- **THEN** 開啟新增交易 Sheet（類型預設為 `.expense`）
- **AND** 金額欄位為必填，預設為空

### Requirement: Analysis Empty State User Stories

#### Scenario: 無資料狀態
- **GIVEN** 使用者在 Analysis tab
- **WHEN** 選定的日期範圍內無任何交易資料
- **THEN** 隱藏所有圖表和摘要卡片
- **AND** 顯示 Analysis Empty State View
- **AND** 提示用戶「此期間無資料」

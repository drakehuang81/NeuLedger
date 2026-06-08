# PR B1 — AddEdit 四套測試套件 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development。

**Goal:** 為審查確認零/低覆蓋的 4 個 AddEdit feature 建立完整測試套件（AddEditAccount 3/10 → 補滿；AddEditCategory 0/9、AddEditTag 2/7（A 波後）、AddEditCarrier 5/9 → 各建/補套件）。

**Architecture:** 「補測試」型 —— 寫測試 → 跑 → **預期綠**；若紅 = 發現真 bug → **回報而非改 production**（production 改動不在本 PR 範圍）。測試用 Swift Testing + TestStore，遵循血淚規則①（路徑碰到的 closure 全 stub）。

**分支：** `fix/tests-addedit-suites`（自 `integration/presentation-audit` 5747d49 切出）。PR base = 整合分支。

**測試慣例（四套通用）：**
- spy 模式：`LockIsolated<T?>` 捕捉 client 寫入參數，斷言欄位逐一精確
- save 成功鏈：`saveTapped` → receive `\.savedSuccessfully` → receive `\.delegate.saved`（+ `$0.dismiss = DismissEffect {}`）
- cancel 鏈：`cancelTapped` → receive `\.delegate.dismissed`
- 驗證失敗：inline error 斷言（專案規範禁 Alert）+ **負斷言 client 未被呼叫**（spy 為 nil）
- setter：逐一 send 斷言 state
- 既有測試檔已存在者（AddEditAccountFeatureTests）在檔內擴充，其餘新建檔落 `NeuLedgerTests/Tests/FeaturesTests/`（同步資料夾自動收錄）

### Task 1: AddEditAccount + AddEditCategory（行為清單）

**AddEditAccountFeatureTests（擴充既有檔）：** save .add 成功（createAccount spy 斷言 name/type/icon/color + delegate 鏈）；save .edit 成功（updateAccount spy 斷言 id 不變 + 欄位更新）；名稱驗證失敗（讀 reducer 實際驗證邏輯 — 空名與 existingNames 重複名，斷言 nameError + createAccount 未呼叫）；驗證錯誤在修正後清除（若 reducer 有此行為）；cancelTapped delegate 鏈；typeChanged/iconChanged/colorHexChanged setters。

**AddEditCategoryFeatureTests（新建）：** 同構全套 —— init .add(initialType) 預設值；init .edit 帶入；save .add 成功（createCategory spy 含 type）；save .edit 成功；名稱驗證失敗；cancelTapped；四個 setters。

### Task 2: AddEditTag + AddEditCarrier（行為清單）

**AddEditTagFeatureTests（新建）：** init .add 預設色 == `DesignConstants.defaultTagColorHex`；init .edit 帶入（含 color nil fallback）；save .add 成功 + **colorHex 端到端**（colorHexChanged 後 spy 斷言 `Tag.color` == 新色碼）；save .edit 成功；名稱驗證失敗（若有）；cancelTapped；savedSuccessfully → delegate.saved。

**AddEditCarrierFeatureTests（新建或擴充，以實際為準）：** save 成功鏈；**saveFailed 錯誤路徑**（stub carrierClient throw → receive `\.saveFailed` 斷言 saveError 寫入與 isSaving 類旗標清除 — 以 State 實際欄位為準）；cancelTapped 發端 delegate.dismissed；barcodeChanged/typeChanged setters；驗證失敗（若有 inline 驗證）。

### Task 3: 驗證 + 交叉 review + PR + merge

- 四 suite 綠 + 完整 scheme 綠 + ast-grep 閘門
- 交叉 review 重點：測試是否真驗行為（spy 斷言完整 vs 套套邏輯）、覆蓋是否對齊審查 untestedCriticalPaths、有無漏 stub 導致的假綠
- PR base = 整合分支 → merge

**若任何測試跑紅：** 視為發現真 bug，記錄細節回報（不修 production），該測試標 `withKnownIssue` 或暫不提交，由 PR body 列出待裁定。

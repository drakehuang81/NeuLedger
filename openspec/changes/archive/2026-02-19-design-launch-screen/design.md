## Context

目前 NeuLedger 缺乏一個明確且具吸引力的啟動畫面 (Launch Screen) 設計，且現有的設計流程可能存在不連貫之處。為了提升使用者體驗並確保設計完整性，我們需要透過 Pencil 工具補足這些缺漏，並同步更新相關的規格文件。

## Goals / Non-Goals

**Goals:**
1.  **設計啟動畫面**: 在 Pencil 檔案中繪製並定義 Launch Screen 的視覺元素與佈局。
2.  **流程審查**: 針對現有的 App Flow 進行審查，辨識並補足遺漏的畫面或狀態。
3.  **規格同步**: 確保 `design-system.md` 等規格文件反映新增的設計決策。

**Non-Goals:**
1.  **程式碼實作**: 本次變更不包含任何 iOS 專案內的 Swift 程式碼修改或 Storyboard 編輯。
2.  **功能重構**: 僅針對現有設計進行補強，不涉及核心功能的邏輯重構。

## Decisions

1.  **Pencil 為單一設計來源**: 所有新的畫面與流程修改皆直接於 Pencil 檔案中進行，以此作為設計的唯一真相來源 (Single Source of Truth)。
2.  **規格驅動設計**: 在繪製畫面後，必須將相關的 tokens 與元件定義回寫至 `openspec/specs` 文件中，確保文件與設計的一致性。
3.  **最小化變動**: 在審查流程時，優先採用「補丁」方式修復缺失，而非大規模重新繪製現有流程，以降低設計債。

## Risks / Trade-offs

1.  **設計與實作脫鉤風險**: 由於本次不包含實作，若設計過於複雜可能導致後續開發困難。需在設計時考慮 iOS 的技術限制 (如 Launch Screen 僅能使用靜態圖片或簡單 Storyboard)。
2.  **規格同步負擔**: 手動同步 Pencil 設計與 Markdown 規格可能會有遺漏。需仔細核對 `design-system` 的變更。

## Why

為了提升使用者進入 App 的第一印象，我們需要設計一個專屬的啟動畫面（Launch Screen）。同時，為了確保設計的完整性，我們需要全面檢視目前的設計流程，補足任何缺失的畫面，並同步更新相關的規格文件。

## What Changes

這個變更將包含以下工作：
1.  **新增啟動畫面設計**：在 Pencil 設計檔中繪製 Launch Screen (本變更僅限設計，不包含程式碼實作)。
2.  **設計流程檢視**：檢查現有的設計流程，確認是否有遺漏的狀態或畫面，並進行補強。
3.  **規格同步更新**：檢查 `openspec/specs` 中的文件（如 `design-system.md` 和 `app-features.md`），根據新增的設計進行相應的調整。

## Capabilities

### New Capabilities
<!-- Capabilities being introduced. -->
- `launch-experience`: 定義啟動畫面的視覺設計、動畫行為與進入應用程式的轉場邏輯。
- `design-audit`: 針對現有設計流程的完整性審查與補強計畫。

### Modified Capabilities
<!-- Existing capabilities whose REQUIREMENTS are changing. -->
- `design-system`: 更新設計系統以包含啟動畫面所需的特殊視覺元素或 tokens。
- `app-features`: 若啟動流程影響到功能面的入口邏輯（例如生物辨識、資料載入），需同步更新。

## Impact

- **Pencil 檔案**: 新增 Launch Screen Artboard，並可能修改現有的 Flow 連線。
- **規格文件**: `design-system.md` 與 `app-features.md` 將會被更新。
- **注意**: 本次變更僅專注於設計檔案與規格的更新，不涉及 iOS 專案內的程式碼修改或 Storyboard 實作。

## 1. Pencil Design: Launch Screen

- [x] 1.1 **Create Artboard**: 在 Pencil 檔案中新增名為 `Launch Screen` 的 Artboard，尺寸需符合主流 iOS 裝置 (如 iPhone 14/15 Pro)。
- [x] 1.2 **Visual Design**: 根據 Design System 繪製 NeuLedger Logo 與品牌名稱，設定適當的間距與背景色 (需考量 Light/Dark mode)。
- [x] 1.3 **Transition Flow**: 在 Flow 圖表中定義從 Launch Screen 進入主畫面 (Dashboard) 或登入頁面的轉場連結。

## 2. Design Audit & Flow Check

- [x] 2.1 **Core Flow Audit**: 檢查「新增交易」、「查看報表」等核心流程，確認所有關鍵互動狀態 (Focused, Active) 皆有視覺定義。
- [x] 2.2 **Missing States**: 針對發現遺漏的畫面 (如空資料 Empty State、錯誤提示 Error State) 進行補強繪製。
- [x] 2.3 **Flow Consistency**: 確保所有 Artboard 之間的 Flow 連線邏輯正確且無斷點。

## 3. Spec Synchronization

- [x] 3.1 **Sync Design System**: 若在設計 Launch Screen 過程中新增了顏色或圖示，需將其定義更新至 `openspec/specs/design-system.md`。
- [x] 3.2 **Update App Features**: 若流程檢視發現功能行為變更，需更新 `openspec/specs/app-features.md` 以反映最新的設計邏輯。

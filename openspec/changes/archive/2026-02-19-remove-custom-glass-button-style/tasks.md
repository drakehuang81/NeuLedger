
## 1. 移除自定義 GlassButtonStyle

- [x] 1.1 找到並刪除 `Features/Sources/Features/Components/GlassButtonStyle.swift` 檔案。
- [x] 1.2 確認刪除後，專案中沒有殘留的 `GlassButtonStyle` 結構體定義。

## 2. 更新 GlassButton 實作

- [x] 2.1 修改 `Features/Sources/Features/Components/GlassButton.swift`。
- [x] 2.2 將 `.buttonStyle(.glass(tint: ...))` 用法替換為原生的 `.buttonStyle(.glass)` 配合 `.tint(...)`（如果需要）。
- [x] 2.3 檢查 `GlassButton` 的初始化方法，確保傳入的 tint 參數能正確應用到按鈕上。

## 3. 全域搜尋與替換

- [x] 3.1 搜尋專案中所有使用 `GlassButtonStyle` 的地方。
- [x] 3.2 將所有引用替換為使用原生 API。
- [x] 3.3 如果有直接引用 `GlassButtonStyle` 型別的地方（例如作為屬性型別），改為 `PrimitiveButtonStyle` 或移除依賴。

## 4. 驗證

- [x] 4.1 建置 `Features` 套件，確保編譯通過。
- [x] 4.2 執行預覽或運行 App，檢查 Glass Button 的外觀是否與之前一致（或符合原生樣式預期）。
- [x] 4.3 確認點擊效果與互動行為正常。

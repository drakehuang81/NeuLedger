
## Why

專案目前包含了一個自定義的 `GlassButtonStyle` 實作，這與 iOS 26 提供的官方原生 `GlassButtonStyle` API 重複。使用平台原生的實作可以減少維護負擔，確保與系統標準的一致性，並消除不必要的程式碼重複。

## What Changes

- 從程式碼庫中移除自定義的 `GlassButtonStyle.swift` 檔案。
- 重構 `GlassButton`（以及任何其他引用處）以使用官方原生的 `GlassButtonStyle`。
- 更新 `design-system` 規範，強制要求使用官方 API 而非自定義實作。

## Capabilities

### New Capabilities
- None

### Modified Capabilities
- `design-system`: 更新需求以強制使用官方 `GlassButtonStyle` 代替自定義實作。

## Impact

- **Codebase**: `Features/Sources/Features/Components/GlassButtonStyle.swift` 將被刪除。
- **Components**: `GlassButton.swift` 將更新為使用官方 API。
- **Maintenance**: 減少需維護的程式碼。
- **Consistency**: 符合平台標準。


## Context

目前的專案包含自定義的 `GlassButtonStyle.swift`，其實作重複了 iOS 26 原生提供的功能。為了保持程式碼簡潔並遵循平台標準，我們決定移除自定義實作，改用原生的 `GlassButtonStyle` API。

## Goals / Non-Goals

**Goals:**
- 移除 `Features/Sources/Features/Components/GlassButtonStyle.swift`。
- 修改 `GlassButton.swift` 以使用 SwiftUI 原生的 `.buttonStyle(.glass())`。
- 確保所有使用到 `GlassButtonStyle` 的地方都能正確編譯並維持原有的視覺效果。

**Non-Goals:**
- 不涉及 `GlassCard` 或 `GlassHeader` 的修改，除非它們依賴於 `GlassButtonStyle` 的自定義實作（目前看來是獨立的）。
- 不改變按鈕的視覺外觀（原生 API 應提供相同的效果）。

## Decisions

### Decision 1: 移除自定義檔案
我們將直接刪除 `GlassButtonStyle.swift` 檔案，而不是將其標記為 deprecated。這是因為專案仍處於早期開發階段，直接清理技術債是更好的選擇。

### Decision 2: 採用原生 API
在 `GlassButton.swift` 中，將 `GlassButtonStyle` 的引用替換為原生的 `ButtonStyle` 配置。
原生用法：
```swift
Button("Label") { ... }
    .buttonStyle(.glass)
    .tint(.blue) // 若需自定義顏色
```

## Risks / Trade-offs

- **Risk**: 原生 API 可能不支援部分我們自定義的參數（如特定 tint 邏輯）。
- **Mitigation**: 使用標準 `.tint()` modifier 來處理顏色，若有不支援的行為則考慮回退到 `.glassEffect()` 手動實作。

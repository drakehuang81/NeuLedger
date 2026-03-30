# Analysis AI Assistant — Design Spec

**Date:** 2026-03-30
**Status:** Approved

## Overview

Add a multi-turn AI Q&A card to the Analysis screen's ScrollView. The card is collapsed by default, showing a "Ask AI Assistant…" prompt. Tapping expands it to reveal a chat-style conversation history and a text input field. The backend (`answerFinancialQuestion` with Foundation Models Tool Calling) is already implemented; this spec covers only the Feature and View layer.

---

## Scope

**In scope:**
- `AIAssistantFeature` TCA Reducer (new file)
- `AIAssistantCardView` SwiftUI View (new file)
- `AnalysisFeature` — compose `AIAssistantFeature` as an always-on child scope
- `AnalysisView` — render `AIAssistantCardView` at the bottom of the ScrollView (guarded by `aiServiceClient.isAvailable()`)

**Out of scope:**
- Voice input (text-only for now)
- Persistent conversation history across sessions
- Use of AI assistant outside the Analysis screen

---

## File Structure

```
Features/Sources/Features/Analysis/
├── AIAssistant/
│   ├── AIAssistantFeature.swift
│   └── AIAssistantCardView.swift
├── AnalysisFeature.swift   ← add Scope composition
└── AnalysisView.swift      ← add AIAssistantCardView
```

---

## AIAssistantFeature

### State

```swift
@ObservableState
public struct State: Equatable, Sendable {
    public enum Role: Equatable, Sendable { case user, assistant }

    public struct Message: Equatable, Identifiable, Sendable {
        public let id: UUID
        public let role: Role
        public let text: String
    }

    public var messages: [Message] = []
    public var inputText: String = ""
    public var isExpanded: Bool = false
    public var isLoading: Bool = false
    public var errorMessage: String? = nil
    public var isAvailable: Bool = false
}
```

### Actions

```swift
public enum Action: Sendable, Equatable {
    case task
    case expandTapped
    case inputChanged(String)
    case submitTapped
    case answerReceived(String)
    case answerFailed(String)
    case dismissError
}
```

### CancelID

```swift
private enum CancelID { case ask }
```

### Dependencies

```swift
@Dependency(\.aiServiceClient) var aiServiceClient
```

### Reducer Logic

**task:**
```
state.isAvailable = aiServiceClient.isAvailable()
```

**expandTapped:**
```
state.isExpanded.toggle()
```

**inputChanged(text):**
```
state.inputText = text
```

**submitTapped:**
```
guard !state.inputText.isEmpty, !state.isLoading else { return .none }
let question = state.inputText
state.messages.append(Message(id: UUID(), role: .user, text: question))
state.inputText = ""
state.isLoading = true
state.errorMessage = nil
return .run { send in
    do {
        let answer = try await aiServiceClient.answerFinancialQuestion(question)
        await send(.answerReceived(answer))
    } catch {
        await send(.answerFailed(String(localized: "ai_assistant_error")))
    }
}.cancellable(id: CancelID.ask, cancelInFlight: true)
```

**answerReceived(text):**
```
state.isLoading = false
state.messages.append(Message(id: UUID(), role: .assistant, text: text))
```

**answerFailed(error):**
```
state.isLoading = false
state.errorMessage = error
```

**dismissError:**
```
state.errorMessage = nil
```

---

## AnalysisFeature Changes

### State addition

```swift
public var aiAssistant: AIAssistantFeature.State = .init()
```

### Action addition

```swift
case aiAssistant(AIAssistantFeature.Action)
```

### Reducer body addition

```swift
Scope(state: \.aiAssistant, action: \.aiAssistant) {
    AIAssistantFeature()
}
```

---

## AIAssistantCardView UI

### Collapsed state (`isExpanded = false`)

```
┌────────────────────────────────────┐
│  ✦  問 AI 助理…                    │   ← GlassContainer, tappable
└────────────────────────────────────┘
```

- Uses `GlassContainer` consistent with other Analysis cards
- Tapping triggers `expandTapped`
- Icon: `sparkles` SF Symbol with `.hierarchical` rendering

### Expanded state (`isExpanded = true`)

```
┌────────────────────────────────────┐
│  ✦ AI 助理               [收合 ✕]  │
├────────────────────────────────────┤
│  [user]  上個月哪個分類花最多？       │
│  [ai]    餐飲，共花了 NT$4,200。    │
│  [user]  跟前月比呢？               │
│  [ai]    比上月多約 12%。           │
│  [loading spinner]                 │
├────────────────────────────────────┤
│  [TextField placeholder]  [送出]   │
└────────────────────────────────────┘
```

- Conversation area: `ScrollViewReader` with `.scrollTo(messages.last?.id)` on `messages` change
- User messages: trailing-aligned, accent tint background bubble
- Assistant messages: leading-aligned, surface tint background bubble
- `isLoading = true`: show `ProgressView` at the end of the message list; send button disabled
- `errorMessage != nil`: inline red text below conversation with a dismiss `×` button
- Collapse button (top-right): sends `expandTapped`

### Visibility guard

The card is only rendered when `store.aiAssistant.isAvailable` is true (set during `.task`):

```swift
if store.aiAssistant.isAvailable {
    AIAssistantCardView(store: store.scope(state: \.aiAssistant, action: \.aiAssistant))
}
```

`AIAssistantCardView` calls `.task { await store.send(.task).finish() }` on appear.

---

## Localisation Keys

| Key | Value |
|-----|-------|
| `ai_assistant_prompt` | 問 AI 助理… |
| `ai_assistant_title` | AI 助理 |
| `ai_assistant_placeholder` | 輸入問題… |
| `ai_assistant_error` | 無法取得回答，請稍後再試。 |
| `ai_assistant_collapse` | 收合 |

---

## Testing (Swift Testing)

```swift
@Suite("AIAssistantFeature")
struct AIAssistantFeatureTests {
    @Test func expandTapped_togglesIsExpanded() async { ... }
    @Test func submitTapped_appendsUserMessage_setsLoading() async { ... }
    @Test func answerReceived_appendsAssistantMessage_clearsLoading() async { ... }
    @Test func answerFailed_setsErrorMessage_clearsLoading() async { ... }
    @Test func submitTapped_guardedWhenEmpty() async { ... }
    @Test func submitTapped_guardedWhenLoading() async { ... }
    @Test func dismissError_clearsErrorMessage() async { ... }
}
```

Each test uses `TestStore` with a mock `aiServiceClient`.

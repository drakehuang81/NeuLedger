# Analysis AI Assistant Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a collapsible multi-turn AI Q&A card at the bottom of the Analysis screen's ScrollView, backed by the existing `answerFinancialQuestion` client.

**Architecture:** A new `AIAssistantFeature` TCA Reducer owns all Q&A state and is composed into `AnalysisFeature` as an always-on child scope via `Scope`. `AIAssistantCardView` renders collapsed/expanded states and is only shown when `store.aiAssistant.isAvailable` is true.

**Tech Stack:** TCA v1.23.1, SwiftUI, Swift Testing, `aiServiceClient.answerFinancialQuestion`

---

## File Map

| Action | Path |
|--------|------|
| Create | `Features/Sources/Features/Analysis/AIAssistant/AIAssistantFeature.swift` |
| Create | `Features/Sources/Features/Analysis/AIAssistant/AIAssistantCardView.swift` |
| Create | `Features/Tests/FeaturesTests/AIAssistantFeatureTests.swift` |
| Modify | `Features/Sources/Features/Analysis/AnalysisFeature.swift` |
| Modify | `Features/Sources/Features/Analysis/AnalysisView.swift` |
| Modify | `NeuLedger/Resources/Localizable.xcstrings` |

---

## Task 1: Add Localisation Keys

**Files:**
- Modify: `NeuLedger/Resources/Localizable.xcstrings`

- [ ] **Step 1: Add the 5 new keys** to `Localizable.xcstrings` inside the top-level `"strings"` object (alphabetical order — add after any existing `"ai_"` keys):

```json
"ai_assistant_collapse": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Collapse" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "收合" } }
  }
},
"ai_assistant_error": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Unable to get an answer. Please try again." } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "無法取得回答，請稍後再試。" } }
  }
},
"ai_assistant_placeholder": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Ask a question…" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "輸入問題…" } }
  }
},
"ai_assistant_prompt": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Ask AI Assistant…" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "問 AI 助理…" } }
  }
},
"ai_assistant_title": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "AI Assistant" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "AI 助理" } }
  }
},
```

- [ ] **Step 2: Commit**

```bash
git add NeuLedger/Resources/Localizable.xcstrings
git commit -m "feat(l10n): add ai_assistant_* localisation keys"
```

---

## Task 2: AIAssistantFeature — Write Failing Tests

**Files:**
- Create: `Features/Tests/FeaturesTests/AIAssistantFeatureTests.swift`

- [ ] **Step 1: Create the test file**

```swift
import Testing
import ComposableArchitecture
@testable import Features

@Suite("AIAssistantFeature Tests")
struct AIAssistantFeatureTests {

    // MARK: - expandTapped

    @Test("expandTapped toggles isExpanded from false to true")
    func testExpandTapped_expandsCard() async {
        let store = await TestStore(initialState: AIAssistantFeature.State()) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
        }
        await store.send(.expandTapped) { $0.isExpanded = true }
    }

    @Test("expandTapped toggles isExpanded from true to false")
    func testExpandTapped_collapsesCard() async {
        var initial = AIAssistantFeature.State()
        initial.isExpanded = true
        let store = await TestStore(initialState: initial) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
        }
        await store.send(.expandTapped) { $0.isExpanded = false }
    }

    // MARK: - task

    @Test("task sets isAvailable true when AI is available")
    func testTask_setsIsAvailableTrue() async {
        let store = await TestStore(initialState: AIAssistantFeature.State()) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
        }
        await store.send(.task) { $0.isAvailable = true }
    }

    @Test("task sets isAvailable false when AI is unavailable")
    func testTask_setsIsAvailableFalse() async {
        let store = await TestStore(initialState: AIAssistantFeature.State()) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
        }
        await store.send(.task) { $0.isAvailable = false }
    }

    // MARK: - inputChanged

    @Test("inputChanged updates inputText")
    func testInputChanged() async {
        let store = await TestStore(initialState: AIAssistantFeature.State()) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
        }
        await store.send(.inputChanged("上個月花了多少？")) { $0.inputText = "上個月花了多少？" }
    }

    // MARK: - submitTapped (guard: empty input)

    @Test("submitTapped does nothing when inputText is empty")
    func testSubmitTapped_guardEmpty() async {
        let store = await TestStore(initialState: AIAssistantFeature.State()) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
            $0.aiServiceClient.answerFinancialQuestion = { _ in
                Issue.record("should not be called"); return ""
            }
        }
        await store.send(.submitTapped)
        // No state change, no effects
    }

    // MARK: - submitTapped (guard: already loading)

    @Test("submitTapped does nothing when already loading")
    func testSubmitTapped_guardLoading() async {
        var initial = AIAssistantFeature.State()
        initial.inputText = "test"
        initial.isLoading = true
        let store = await TestStore(initialState: initial) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
            $0.aiServiceClient.answerFinancialQuestion = { _ in
                Issue.record("should not be called"); return ""
            }
        }
        await store.send(.submitTapped)
    }

    // MARK: - submitTapped → answerReceived

    @Test("submitTapped appends user message, clears input, sets isLoading")
    func testSubmitTapped_appendsUserMessage() async {
        var initial = AIAssistantFeature.State()
        initial.inputText = "上個月花了多少？"
        let store = await TestStore(initialState: initial) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
            $0.aiServiceClient.answerFinancialQuestion = { _ in "NT$12,300" }
        }

        await store.send(.submitTapped) {
            $0.inputText = ""
            $0.isLoading = true
            $0.errorMessage = nil
            // messages has 1 user message
            #expect($0.messages.count == 1)
            #expect($0.messages[0].role == .user)
            #expect($0.messages[0].text == "上個月花了多少？")
        }
        await store.receive(\.answerReceived) {
            $0.isLoading = false
            #expect($0.messages.count == 2)
            #expect($0.messages[1].role == .assistant)
            #expect($0.messages[1].text == "NT$12,300")
        }
    }

    // MARK: - answerFailed

    @Test("answerFailed sets errorMessage and clears isLoading")
    func testAnswerFailed_setsError() async {
        var initial = AIAssistantFeature.State()
        initial.inputText = "test"
        let store = await TestStore(initialState: initial) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
            $0.aiServiceClient.answerFinancialQuestion = { _ in
                struct Err: Error {}
                throw Err()
            }
        }

        await store.send(.submitTapped) {
            $0.inputText = ""
            $0.isLoading = true
            #expect($0.messages.count == 1)
        }
        await store.receive(\.answerFailed) {
            $0.isLoading = false
            #expect($0.errorMessage != nil)
        }
    }

    // MARK: - dismissError

    @Test("dismissError clears errorMessage")
    func testDismissError() async {
        var initial = AIAssistantFeature.State()
        initial.errorMessage = "some error"
        let store = await TestStore(initialState: initial) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
        }
        await store.send(.dismissError) { $0.errorMessage = nil }
    }
}
```

- [ ] **Step 2: Run tests to confirm they fail** (file doesn't compile yet — that's expected):

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/AIAssistantFeatureTests 2>&1 | tail -20
```

Expected: compile error — `AIAssistantFeature` not found.

---

## Task 3: AIAssistantFeature — Implement

**Files:**
- Create: `Features/Sources/Features/Analysis/AIAssistant/AIAssistantFeature.swift`

- [ ] **Step 1: Create the feature file**

```swift
import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct AIAssistantFeature: Sendable {
    public init() {}

    public enum Role: Equatable, Sendable {
        case user, assistant
    }

    public struct Message: Equatable, Identifiable, Sendable {
        public let id: UUID
        public let role: Role
        public let text: String

        public init(id: UUID = UUID(), role: Role, text: String) {
            self.id = id
            self.role = role
            self.text = text
        }
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public var messages: [Message] = []
        public var inputText: String = ""
        public var isExpanded: Bool = false
        public var isLoading: Bool = false
        public var errorMessage: String? = nil
        public var isAvailable: Bool = false

        public init() {}
    }

    public enum Action: Sendable, Equatable {
        case task
        case expandTapped
        case inputChanged(String)
        case submitTapped
        case answerReceived(String)
        case answerFailed(String)
        case dismissError
    }

    @Dependency(\.aiServiceClient) var aiServiceClient

    private enum CancelID { case ask }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isAvailable = aiServiceClient.isAvailable()
                return .none

            case .expandTapped:
                state.isExpanded.toggle()
                return .none

            case let .inputChanged(text):
                state.inputText = text
                return .none

            case .submitTapped:
                guard !state.inputText.isEmpty, !state.isLoading else { return .none }
                let question = state.inputText
                state.messages.append(Message(role: .user, text: question))
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
                }
                .cancellable(id: CancelID.ask, cancelInFlight: true)

            case let .answerReceived(text):
                state.isLoading = false
                state.messages.append(Message(role: .assistant, text: text))
                return .none

            case let .answerFailed(error):
                state.isLoading = false
                state.errorMessage = error
                return .none

            case .dismissError:
                state.errorMessage = nil
                return .none
            }
        }
    }
}
```

- [ ] **Step 2: Run tests — expect them to pass**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/AIAssistantFeatureTests 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Features/Analysis/AIAssistant/AIAssistantFeature.swift \
        Features/Tests/FeaturesTests/AIAssistantFeatureTests.swift
git commit -m "feat(analysis): add AIAssistantFeature with TDD"
```

---

## Task 4: Compose AIAssistantFeature into AnalysisFeature

**Files:**
- Modify: `Features/Sources/Features/Analysis/AnalysisFeature.swift`

- [ ] **Step 1: Add `aiAssistant` to `AnalysisFeature.State`**

In `AnalysisFeature.State`, add after the last existing property (`var categoryDrilldown`):

```swift
public var aiAssistant: AIAssistantFeature.State = .init()
```

- [ ] **Step 2: Add `aiAssistant` case to `AnalysisFeature.Action`**

In `AnalysisFeature.Action`, add:

```swift
case aiAssistant(AIAssistantFeature.Action)
```

- [ ] **Step 3: Add `Scope` to the reducer body**

At the end of `AnalysisFeature.body` (after the closing `}` of `Reduce`), add:

```swift
Scope(state: \.aiAssistant, action: \.aiAssistant) {
    AIAssistantFeature()
}
```

- [ ] **Step 4: Build to confirm no compile errors**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Run existing AnalysisFeature tests to confirm nothing broke**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/AnalysisFeatureTests 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Features/Analysis/AnalysisFeature.swift
git commit -m "feat(analysis): compose AIAssistantFeature into AnalysisFeature"
```

---

## Task 5: AIAssistantCardView

**Files:**
- Create: `Features/Sources/Features/Analysis/AIAssistant/AIAssistantCardView.swift`

- [ ] **Step 1: Create the view file**

```swift
import Common
import ComposableArchitecture
import SwiftUI

struct AIAssistantCardView: View {
    let store: StoreOf<AIAssistantFeature>

    var body: some View {
        Group {
            if store.isExpanded {
                expandedCard
            } else {
                collapsedCard
            }
        }
        .task {
            await store.send(.task).finish()
        }
    }

    // MARK: - Collapsed

    private var collapsedCard: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                store.send(.expandTapped)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
                Text(String(localized: "ai_assistant_prompt"))
                    .font(Font.Design.body)
                    .foregroundStyle(Color.Design.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .glassEffect(Glass.clear.tint(Color.Design.surface), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Expanded

    private var expandedCard: some View {
        GlassContainer(padding: 0) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
                    Text(String(localized: "ai_assistant_title"))
                        .font(Font.Design.headline)
                        .foregroundStyle(Color.Design.textPrimary)
                    Spacer()
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            store.send(.expandTapped)
                        }
                    } label: {
                        Label(String(localized: "ai_assistant_collapse"), systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.Design.textTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()

                // Conversation
                conversationArea

                Divider()

                // Input row
                inputRow
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Conversation

    @ViewBuilder
    private var conversationArea: some View {
        if store.messages.isEmpty {
            Text(String(localized: "ai_assistant_prompt"))
                .font(Font.Design.caption)
                .foregroundStyle(Color.Design.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        if store.isLoading {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.leading, 12)
                                Spacer()
                            }
                            .id("loading")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 220)
                .onChange(of: store.messages.count) { _, _ in
                    withAnimation {
                        if let last = store.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: store.isLoading) { _, loading in
                    if loading {
                        withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
                    }
                }
            }
        }

        if let error = store.errorMessage {
            HStack(alignment: .top, spacing: 4) {
                Text(error)
                    .font(Font.Design.caption)
                    .foregroundStyle(Color.Design.expenseRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    store.send(.dismissError)
                } label: {
                    Image(systemName: "xmark")
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.expenseRed)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }

    // MARK: - Input Row

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(
                String(localized: "ai_assistant_placeholder"),
                text: Binding(
                    get: { store.inputText },
                    set: { store.send(.inputChanged($0)) }
                ),
                axis: .vertical
            )
            .lineLimit(1...3)
            .textFieldStyle(.plain)
            .font(Font.Design.body)
            .submitLabel(.send)
            .onSubmit { store.send(.submitTapped) }

            if store.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
            } else {
                Button {
                    store.send(.submitTapped)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .disabled(store.inputText.isEmpty)
            }
        }
    }
}

// MARK: - MessageBubble

private struct MessageBubble: View {
    let message: AIAssistantFeature.Message

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .font(Font.Design.body)
                .foregroundStyle(message.role == .user ? Color.white : Color.Design.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    message.role == .user
                        ? Color.accentColor
                        : Color.Design.surface,
                    in: RoundedRectangle(cornerRadius: 12)
                )
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

#Preview("Collapsed") {
    AIAssistantCardView(
        store: Store(initialState: AIAssistantFeature.State()) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
        }
    )
    .padding()
}

#Preview("Expanded with messages") {
    var state = AIAssistantFeature.State()
    state.isExpanded = true
    state.messages = [
        .init(role: .user, text: "上個月哪個分類花最多？"),
        .init(role: .assistant, text: "餐飲類，共花了 NT$4,200，佔總支出 34%。"),
    ]
    return AIAssistantCardView(
        store: Store(initialState: state) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
        }
    )
    .padding()
}
```

- [ ] **Step 2: Build to confirm no compile errors**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Features/Analysis/AIAssistant/AIAssistantCardView.swift
git commit -m "feat(analysis): add AIAssistantCardView (collapsed/expanded UI)"
```

---

## Task 6: Wire AIAssistantCardView into AnalysisView

**Files:**
- Modify: `Features/Sources/Features/Analysis/AnalysisView.swift`

- [ ] **Step 1: Add `AIAssistantCardView` at the bottom of the data content VStack**

In `AnalysisView.scrollView`, inside the `else { VStack(spacing: 16) { ... } }` block, add after the `InsightCard` block:

```swift
if store.aiAssistant.isAvailable {
    AIAssistantCardView(
        store: store.scope(state: \.aiAssistant, action: \.aiAssistant)
    )
}
```

The full data-content VStack should end up as:

```swift
VStack(spacing: 16) {
    if let summary = store.summary {
        SummaryCardView(summary: summary)
    }
    if !store.categoryProportions.isEmpty {
        CategoryPieChartView(proportions: store.categoryProportions) { proportion in
            store.send(.categoryTapped(proportion))
        }
    }
    TrendBarChartView(
        trends: store.dailyTrends,
        dateRange: AnalysisFeature.dateRange(for: store.selectedPeriod)
    )
    if !store.budgetMetrics.isEmpty {
        GlassContainer(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("analysis_budget_progress")
                    .font(Font.Design.headline)
                    .foregroundStyle(Color.Design.textPrimary)
                ForEach(store.budgetMetrics) { metric in
                    BudgetGauge(
                        total: metric.totalBudget,
                        used: metric.spentAmount,
                        label: metric.categoryName
                    )
                }
            }
        }
    }
    if let insight = store.insight {
        InsightCard(
            title: insight.title,
            body: insight.description,
            onClose: { store.send(.dismissInsight) }
        )
    }
    // AI Assistant card — only shown when Foundation Models is available
    if store.aiAssistant.isAvailable {
        AIAssistantCardView(
            store: store.scope(state: \.aiAssistant, action: \.aiAssistant)
        )
    }
}
.padding(.all, 16)
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Run all Features tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Features/Analysis/AnalysisView.swift
git commit -m "feat(analysis): wire AIAssistantCardView into AnalysisView"
```

---

## Done

All tasks complete. The Analysis screen now shows a collapsible AI Assistant card at the bottom when Foundation Models is available. The card supports multi-turn text Q&A backed by `answerFinancialQuestion` with Tool Calling.

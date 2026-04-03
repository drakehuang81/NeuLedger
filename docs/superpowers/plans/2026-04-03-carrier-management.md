# Carrier Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓使用者在 Settings 頁管理台灣政府電子發票載具（手機條碼載具、自然人憑證條碼），可新增/編輯/刪除，查閱時可複製條碼字串並展開顯示 QR Code 圖片。

**Architecture:** 標準 Clean Architecture + TCA 分層：Domain 新增 `Carrier` entity 與 `CarrierClient` interface；Core 新增 `SDCarrier` SwiftData model、mapping、live client；Features 新增 `CarrierManagementFeature`、`AddEditCarrierFeature` 及對應 View；Settings 頁新增入口列。

**Tech Stack:** Swift Testing (`@Suite`, `@Test`)、TCA v1.23.1 `TestStore`、SwiftData（`SDCarrier`）、CoreImage QR code generation（無外部套件）。

---

## File Map

**新增：**
- `Features/Sources/Domain/Entities/Carrier.swift`
- `Features/Sources/Domain/Clients/CarrierClient.swift`
- `Features/Sources/Core/Persistence/Models/SDCarrier.swift`
- `Features/Sources/Core/Mappers/SDCarrier+Mapping.swift`
- `Features/Sources/Core/Clients/CarrierClient+Live.swift`
- `Features/Sources/Features/CarrierManagement/AddEditCarrierFeature.swift`
- `Features/Sources/Features/CarrierManagement/CarrierManagementFeature.swift`
- `Features/Sources/Features/CarrierManagement/AddEditCarrierView.swift`
- `Features/Sources/Features/CarrierManagement/CarrierManagementView.swift`
- `Features/Tests/DomainTests/Entities/CarrierTests.swift`
- `Features/Tests/DomainTests/Clients/CarrierClientTests.swift`
- `Features/Tests/FeaturesTests/CarrierManagementFeatureTests.swift`

**修改：**
- `Features/Sources/Core/Persistence/DatabaseClient.swift` — 加入 `SDCarrier` 至 Schema
- `Features/Sources/Features/Settings/SettingsFeature.swift` — 新增 `.carrierManagement` destination 與 action
- `Features/Sources/Features/Settings/SettingsView.swift` — 新增載具管理列
- `NeuLedger/Resources/Localizable.xcstrings` — 新增所有 carrier_* 字串

---

## Task 1: Domain — Carrier entity + CarrierType enum + CarrierClient

**Files:**
- Create: `Features/Sources/Domain/Entities/Carrier.swift`
- Create: `Features/Sources/Domain/Clients/CarrierClient.swift`
- Create: `Features/Tests/DomainTests/Entities/CarrierTests.swift`
- Create: `Features/Tests/DomainTests/Clients/CarrierClientTests.swift`

- [ ] **Step 1: Write failing Domain entity tests**

```swift
// Features/Tests/DomainTests/Entities/CarrierTests.swift
import Foundation
import Testing
@testable import Domain

@Suite("Carrier Tests")
struct CarrierTests {

    @Test("Carrier Initialization and Equatable")
    func testInitializationAndEquatable() {
        let id = UUID()
        let c1 = Carrier(id: id, name: "我的手機載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234")
        let c2 = Carrier(id: id, name: "我的手機載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234")
        let c3 = Carrier(name: "證書", type: .citizenDigitalCertificate, barcode: "/PA1B2C3D4E5F6G7H8")
        #expect(c1 == c2)
        #expect(c1 != c3)
    }

    @Test("Carrier Hashable")
    func testHashable() {
        let id = UUID()
        let c1 = Carrier(id: id, name: "A", type: .phoneBarcodeCarrier, barcode: "/ABC1234")
        let c2 = Carrier(id: id, name: "A", type: .phoneBarcodeCarrier, barcode: "/ABC1234")
        #expect(c1.hashValue == c2.hashValue)
    }

    @Test("Carrier Codable round-trip")
    func testCodable() throws {
        let carrier = Carrier(name: "手機載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234")
        let data = try JSONEncoder().encode(carrier)
        let decoded = try JSONDecoder().decode(Carrier.self, from: data)
        #expect(decoded == carrier)
    }

    @Test("CarrierType allCases completeness")
    func testCarrierTypeAllCases() {
        #expect(CarrierType.allCases.count == 2)
        #expect(CarrierType.allCases.contains(.phoneBarcodeCarrier))
        #expect(CarrierType.allCases.contains(.citizenDigitalCertificate))
    }

    @Test("CarrierType raw values")
    func testCarrierTypeRawValues() {
        #expect(CarrierType.phoneBarcodeCarrier.rawValue == "phoneBarcodeCarrier")
        #expect(CarrierType.citizenDigitalCertificate.rawValue == "citizenDigitalCertificate")
    }
}
```

```swift
// Features/Tests/DomainTests/Clients/CarrierClientTests.swift
import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite("CarrierClient Tests")
struct CarrierClientTests {

    @Test("CarrierClient dependency key injection")
    func testDependencyKey() {
        @Dependency(\.carrierClient) var client
        #expect(true, "CarrierClient injected successfully")
    }

    @Test("CarrierClient fetchAll mock override")
    func testFetchAllMock() async throws {
        let expected = [Carrier(name: "手機載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234")]
        try await withDependencies {
            $0.carrierClient.fetchAll = { expected }
        } operation: {
            @Dependency(\.carrierClient) var client
            let result = try await client.fetchAll()
            #expect(result == expected)
        }
    }

    @Test("CarrierClient add mock override")
    func testAddMock() async throws {
        try await withDependencies {
            $0.carrierClient.add = { _ in }
        } operation: {
            @Dependency(\.carrierClient) var client
            let carrier = Carrier(name: "手機載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234")
            try await client.add(carrier)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/CarrierTests \
  -only-testing:FeaturesTests/CarrierClientTests 2>&1 | tail -20
```

Expected: compile error — `Carrier` not found.

- [ ] **Step 3: Create Carrier.swift**

```swift
// Features/Sources/Domain/Entities/Carrier.swift
import Foundation

/// A Taiwan government e-invoice carrier stored by the user for quick reference.
public struct Carrier: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var type: CarrierType
    public var barcode: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        type: CarrierType,
        barcode: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.barcode = barcode
        self.createdAt = createdAt
    }
}

public enum CarrierType: String, Codable, CaseIterable, Sendable {
    case phoneBarcodeCarrier
    case citizenDigitalCertificate
}
```

- [ ] **Step 4: Create CarrierClient.swift**

```swift
// Features/Sources/Domain/Clients/CarrierClient.swift
import Foundation
import Dependencies
import DependenciesMacros

@DependencyClient
public struct CarrierClient: Sendable {
    public var fetchAll: @Sendable () async throws -> [Carrier]
    public var add: @Sendable (Carrier) async throws -> Void
    public var update: @Sendable (Carrier) async throws -> Void
    public var delete: @Sendable (Carrier.ID) async throws -> Void
}

extension CarrierClient: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var carrierClient: CarrierClient {
        get { self[CarrierClient.self] }
        set { self[CarrierClient.self] = newValue }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DomainTests/CarrierTests \
  -only-testing:DomainTests/CarrierClientTests 2>&1 | tail -20
```

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Domain/Entities/Carrier.swift \
        Features/Sources/Domain/Clients/CarrierClient.swift \
        Features/Tests/DomainTests/Entities/CarrierTests.swift \
        Features/Tests/DomainTests/Clients/CarrierClientTests.swift
git commit -m "feat(domain): add Carrier entity, CarrierType enum, and CarrierClient interface"
```

---

## Task 2: Core — SDCarrier + Mapping + Live Client + Schema

**Files:**
- Create: `Features/Sources/Core/Persistence/Models/SDCarrier.swift`
- Create: `Features/Sources/Core/Mappers/SDCarrier+Mapping.swift`
- Create: `Features/Sources/Core/Clients/CarrierClient+Live.swift`
- Modify: `Features/Sources/Core/Persistence/DatabaseClient.swift`

- [ ] **Step 1: Create SDCarrier.swift**

```swift
// Features/Sources/Core/Persistence/Models/SDCarrier.swift
import Foundation
import SwiftData

/// SwiftData persistence model for a user's government e-invoice carrier.
@Model
final class SDCarrier {
    var id: UUID = UUID()
    var name: String = ""
    var typeRaw: String = ""
    var barcode: String = ""
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        typeRaw: String,
        barcode: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.typeRaw = typeRaw
        self.barcode = barcode
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 2: Create SDCarrier+Mapping.swift**

```swift
// Features/Sources/Core/Mappers/SDCarrier+Mapping.swift
import Foundation
import SwiftData
import Domain

extension SDCarrier: DomainConvertible {
    func toDomain() -> Carrier {
        Carrier(
            id: id,
            name: name,
            type: CarrierType(rawValue: typeRaw) ?? .phoneBarcodeCarrier,
            barcode: barcode,
            createdAt: createdAt
        )
    }

    @discardableResult
    static func from(_ domain: Carrier, context: ModelContext) -> SDCarrier {
        let model = SDCarrier(
            id: domain.id,
            name: domain.name,
            typeRaw: domain.type.rawValue,
            barcode: domain.barcode,
            createdAt: domain.createdAt
        )
        context.insert(model)
        return model
    }
}
```

- [ ] **Step 3: Create CarrierClient+Live.swift**

```swift
// Features/Sources/Core/Clients/CarrierClient+Live.swift
import Foundation
import SwiftData
import Domain
import Dependencies

extension CarrierClient: DependencyKey {
    public static var liveValue: CarrierClient {
        @Dependency(\.databaseClient) var databaseClient

        return CarrierClient(
            fetchAll: {
                try databaseClient.fetch(
                    FetchDescriptor<SDCarrier>(sortBy: [SortDescriptor(\.createdAt)])
                )
            },
            add: { carrier in
                try databaseClient.add(carrier, as: SDCarrier.self)
            },
            update: { carrier in
                let carrierId = carrier.id
                try databaseClient.update(
                    matching: FetchDescriptor<SDCarrier>(
                        predicate: #Predicate { $0.id == carrierId }
                    )
                ) { existing, _ in
                    existing.name = carrier.name
                    existing.typeRaw = carrier.type.rawValue
                    existing.barcode = carrier.barcode
                }
            },
            delete: { id in
                try databaseClient.deleteFirst(
                    matching: FetchDescriptor<SDCarrier>(
                        predicate: #Predicate { $0.id == id }
                    )
                )
            }
        )
    }
}
```

- [ ] **Step 4: Add SDCarrier to DatabaseClient Schema**

在 `Features/Sources/Core/Persistence/DatabaseClient.swift` 中，找到 `liveValue` 的 `Schema([...])` 陣列，加入 `SDCarrier.self`；同樣在 `testValue` 的 `Schema([...])` 陣列加入 `SDCarrier.self`。

`liveValue` 修改前：
```swift
let schema = Schema([
    SDTransaction.self,
    SDAccount.self,
    SDCategory.self,
    SDBudget.self,
    SDTag.self,
    SDRecurringTransaction.self,
])
```

修改後：
```swift
let schema = Schema([
    SDTransaction.self,
    SDAccount.self,
    SDCategory.self,
    SDBudget.self,
    SDTag.self,
    SDRecurringTransaction.self,
    SDCarrier.self,
])
```

`testValue` 也做同樣修改：
```swift
let schema = Schema([
    SDTransaction.self,
    SDAccount.self,
    SDCategory.self,
    SDBudget.self,
    SDTag.self,
    SDRecurringTransaction.self,
    SDCarrier.self,
])
```

- [ ] **Step 5: Build to verify compile**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Core/Persistence/Models/SDCarrier.swift \
        Features/Sources/Core/Mappers/SDCarrier+Mapping.swift \
        Features/Sources/Core/Clients/CarrierClient+Live.swift \
        Features/Sources/Core/Persistence/DatabaseClient.swift
git commit -m "feat(core): add SDCarrier model, mapping, and CarrierClient live implementation"
```

---

## Task 3: AddEditCarrierFeature (TDD)

**Files:**
- Create: `Features/Tests/FeaturesTests/CarrierManagementFeatureTests.swift`
- Create: `Features/Sources/Features/CarrierManagement/AddEditCarrierFeature.swift`

- [ ] **Step 1: Write failing AddEditCarrierFeature tests**

```swift
// Features/Tests/FeaturesTests/CarrierManagementFeatureTests.swift
import Testing
import Foundation
import ComposableArchitecture
import Domain
@testable import Features

@Suite("AddEditCarrierFeature Tests")
struct AddEditCarrierFeatureTests {

    private static let sampleCarrier = Carrier(
        id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
        name: "我的手機載具",
        type: .phoneBarcodeCarrier,
        barcode: "/ABC1234",
        createdAt: Date(timeIntervalSince1970: 0)
    )

    // MARK: - Validation

    @Test("barcodeChanged with valid phone carrier sets barcodeError to nil")
    func testValidPhoneBarcode() async {
        let store = await TestStore(
            initialState: AddEditCarrierFeature.State(mode: .add)
        ) { AddEditCarrierFeature() }

        await store.send(.barcodeChanged("/ABC1234")) {
            $0.barcode = "/ABC1234"
            $0.barcodeError = nil
        }
    }

    @Test("barcodeChanged with invalid phone carrier sets barcodeError")
    func testInvalidPhoneBarcode() async {
        let store = await TestStore(
            initialState: AddEditCarrierFeature.State(mode: .add)
        ) { AddEditCarrierFeature() }

        await store.send(.barcodeChanged("ABC1234")) {
            $0.barcode = "ABC1234"
            $0.barcodeError = String(localized: "carrier_barcode_error_phone")
        }
    }

    @Test("barcodeChanged with valid citizen cert sets barcodeError to nil")
    func testValidCitizenCertBarcode() async {
        var initial = AddEditCarrierFeature.State(mode: .add)
        initial.type = .citizenDigitalCertificate
        let store = await TestStore(initialState: initial) { AddEditCarrierFeature() }

        await store.send(.barcodeChanged("/PA1B2C3D4E5F6G7H8")) {
            $0.barcode = "/PA1B2C3D4E5F6G7H8"
            $0.barcodeError = nil
        }
    }

    @Test("barcodeChanged with invalid citizen cert sets barcodeError")
    func testInvalidCitizenCertBarcode() async {
        var initial = AddEditCarrierFeature.State(mode: .add)
        initial.type = .citizenDigitalCertificate
        let store = await TestStore(initialState: initial) { AddEditCarrierFeature() }

        await store.send(.barcodeChanged("/ABC")) {
            $0.barcode = "/ABC"
            $0.barcodeError = String(localized: "carrier_barcode_error_cert")
        }
    }

    @Test("typeChanged re-validates existing barcode")
    func testTypeChangedRevalidates() async {
        var initial = AddEditCarrierFeature.State(mode: .add)
        initial.barcode = "/ABC1234"
        let store = await TestStore(initialState: initial) { AddEditCarrierFeature() }

        // Switch to citizen cert — "/ABC1234" is invalid for that type
        await store.send(.typeChanged(.citizenDigitalCertificate)) {
            $0.type = .citizenDigitalCertificate
            $0.barcodeError = String(localized: "carrier_barcode_error_cert")
        }
    }

    @Test("saveTapped with empty barcode does not save")
    func testSaveTappedEmptyBarcode() async {
        let store = await TestStore(
            initialState: AddEditCarrierFeature.State(mode: .add)
        ) { AddEditCarrierFeature() }

        await store.send(.saveTapped)
        // No state change expected — canSave is false, action is no-op
    }

    @Test("saveTapped with valid barcode calls carrierClient.add")
    func testSaveTappedAdd() async {
        var initial = AddEditCarrierFeature.State(mode: .add)
        initial.name = "手機載具"
        initial.type = .phoneBarcodeCarrier
        initial.barcode = "/ABC1234"
        let addedCarrier: LockIsolated<Carrier?> = LockIsolated(nil)

        let store = await TestStore(initialState: initial) {
            AddEditCarrierFeature()
        } withDependencies: {
            $0.carrierClient.add = { carrier in addedCarrier.setValue(carrier) }
        }

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(\.savedSuccessfully) { $0.isSaving = false }
        await store.receive(\.delegate.saved)

        #expect(addedCarrier.value?.barcode == "/ABC1234")
        #expect(addedCarrier.value?.name == "手機載具")
    }

    @Test("saveTapped with empty name uses type default name")
    func testSaveTappedEmptyNameUsesDefault() async {
        var initial = AddEditCarrierFeature.State(mode: .add)
        initial.name = ""
        initial.barcode = "/ABC1234"
        let addedCarrier: LockIsolated<Carrier?> = LockIsolated(nil)

        let store = await TestStore(initialState: initial) {
            AddEditCarrierFeature()
        } withDependencies: {
            $0.carrierClient.add = { carrier in addedCarrier.setValue(carrier) }
        }

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(\.savedSuccessfully) { $0.isSaving = false }
        await store.receive(\.delegate.saved)

        #expect(addedCarrier.value?.name == String(localized: "carrier_type_phone_barcode"))
    }

    @Test("edit mode initialises with carrier data")
    func testEditModeInitialisesWithData() async {
        let store = await TestStore(
            initialState: AddEditCarrierFeature.State(mode: .edit(Self.sampleCarrier))
        ) { AddEditCarrierFeature() }

        #expect(store.state.name == "我的手機載具")
        #expect(store.state.type == .phoneBarcodeCarrier)
        #expect(store.state.barcode == "/ABC1234")
    }

    @Test("saveTapped in edit mode calls carrierClient.update")
    func testSaveTappedUpdate() async {
        var initial = AddEditCarrierFeature.State(mode: .edit(Self.sampleCarrier))
        initial.name = "更新後名稱"
        let updatedCarrier: LockIsolated<Carrier?> = LockIsolated(nil)

        let store = await TestStore(initialState: initial) {
            AddEditCarrierFeature()
        } withDependencies: {
            $0.carrierClient.update = { carrier in updatedCarrier.setValue(carrier) }
        }

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(\.savedSuccessfully) { $0.isSaving = false }
        await store.receive(\.delegate.saved)

        #expect(updatedCarrier.value?.name == "更新後名稱")
        #expect(updatedCarrier.value?.id == Self.sampleCarrier.id)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/AddEditCarrierFeatureTests 2>&1 | tail -20
```

Expected: compile error — `AddEditCarrierFeature` not found.

- [ ] **Step 3: Create AddEditCarrierFeature.swift**

```swift
// Features/Sources/Features/CarrierManagement/AddEditCarrierFeature.swift
import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct AddEditCarrierFeature: Sendable {
    public init() {}

    public enum Mode: Equatable, Sendable {
        case add
        case edit(Carrier)
    }

    @ObservableState
    public struct State: Equatable {
        public var mode: Mode
        public var name: String
        public var type: CarrierType
        public var barcode: String
        public var barcodeError: String?
        public var isSaving: Bool = false

        public init(mode: Mode = .add) {
            self.mode = mode
            switch mode {
            case .add:
                self.name = ""
                self.type = .phoneBarcodeCarrier
                self.barcode = ""
                self.barcodeError = nil
            case let .edit(carrier):
                self.name = carrier.name
                self.type = carrier.type
                self.barcode = carrier.barcode
                self.barcodeError = nil
            }
        }

        var canSave: Bool { barcodeError == nil && !barcode.isEmpty }
    }

    public enum Action: Sendable, Equatable {
        case nameChanged(String)
        case typeChanged(CarrierType)
        case barcodeChanged(String)
        case saveTapped
        case cancelTapped
        case savedSuccessfully
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case saved
            case dismissed
        }
    }

    @Dependency(\.carrierClient) var carrierClient
    @Dependency(\.dismiss) var dismiss

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .nameChanged(name):
                state.name = name
                return .none

            case let .typeChanged(type):
                state.type = type
                state.barcodeError = Self.validate(barcode: state.barcode, type: type)
                return .none

            case let .barcodeChanged(barcode):
                state.barcode = barcode
                state.barcodeError = Self.validate(barcode: barcode, type: state.type)
                return .none

            case .saveTapped:
                guard state.canSave else { return .none }
                let trimmedName = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let effectiveName = trimmedName.isEmpty
                    ? state.type.defaultName
                    : trimmedName
                let barcode = state.barcode
                let type = state.type
                let mode = state.mode
                state.isSaving = true

                return .run { send in
                    switch mode {
                    case .add:
                        let carrier = Carrier(name: effectiveName, type: type, barcode: barcode)
                        try await carrierClient.add(carrier)
                    case let .edit(existing):
                        let updated = Carrier(
                            id: existing.id,
                            name: effectiveName,
                            type: type,
                            barcode: barcode,
                            createdAt: existing.createdAt
                        )
                        try await carrierClient.update(updated)
                    }
                    await send(.savedSuccessfully)
                }

            case .savedSuccessfully:
                state.isSaving = false
                return .run { send in
                    await send(.delegate(.saved))
                    await dismiss()
                }

            case .cancelTapped:
                return .run { send in
                    await send(.delegate(.dismissed))
                    await dismiss()
                }

            case .delegate:
                return .none
            }
        }
    }

    private static func validate(barcode: String, type: CarrierType) -> String? {
        guard !barcode.isEmpty else { return nil }
        let pattern: String
        let errorKey: String
        switch type {
        case .phoneBarcodeCarrier:
            pattern = #"^/[A-Z0-9+\-.]{7}$"#
            errorKey = "carrier_barcode_error_phone"
        case .citizenDigitalCertificate:
            pattern = #"^/P[A-Z0-9]{16}$"#
            errorKey = "carrier_barcode_error_cert"
        }
        let matches = barcode.range(of: pattern, options: .regularExpression) != nil
        return matches ? nil : String(localized: String.LocalizationValue(errorKey))
    }
}

extension CarrierType {
    var defaultName: String {
        switch self {
        case .phoneBarcodeCarrier: return String(localized: "carrier_type_phone_barcode")
        case .citizenDigitalCertificate: return String(localized: "carrier_type_citizen_cert")
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/AddEditCarrierFeatureTests 2>&1 | tail -20
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Features/CarrierManagement/AddEditCarrierFeature.swift \
        Features/Tests/FeaturesTests/CarrierManagementFeatureTests.swift
git commit -m "feat(features): add AddEditCarrierFeature with TDD — barcode validation and save/edit flow"
```

---

## Task 4: CarrierManagementFeature (TDD)

**Files:**
- Modify: `Features/Tests/FeaturesTests/CarrierManagementFeatureTests.swift`
- Create: `Features/Sources/Features/CarrierManagement/CarrierManagementFeature.swift`

- [ ] **Step 1: Append CarrierManagementFeature tests to existing test file**

在 `Features/Tests/FeaturesTests/CarrierManagementFeatureTests.swift` 末尾加入：

```swift
@Suite("CarrierManagementFeature Tests")
struct CarrierManagementFeatureTests {

    private static let carrierA = Carrier(
        id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
        name: "手機載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234",
        createdAt: Date(timeIntervalSince1970: 0)
    )
    private static let carrierB = Carrier(
        id: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!,
        name: "憑證", type: .citizenDigitalCertificate, barcode: "/PA1B2C3D4E5F6G7H8",
        createdAt: Date(timeIntervalSince1970: 1)
    )

    @Test("task loads all carriers")
    func testTaskLoadsCarriers() async {
        let carriers = [Self.carrierA, Self.carrierB]
        let store = await TestStore(
            initialState: CarrierManagementFeature.State()
        ) {
            CarrierManagementFeature()
        } withDependencies: {
            $0.carrierClient.fetchAll = { carriers }
        }

        await store.send(.task) { $0.isLoading = true }
        await store.receive(\.carriersLoaded) {
            $0.isLoading = false
            $0.carriers = carriers
        }
    }

    @Test("carrierRowTapped expands the tapped row")
    func testCarrierRowTappedExpands() async {
        var initial = CarrierManagementFeature.State()
        initial.carriers = [Self.carrierA, Self.carrierB]
        let store = await TestStore(initialState: initial) {
            CarrierManagementFeature()
        }

        await store.send(.carrierRowTapped(Self.carrierA.id)) {
            $0.expandedCarrierId = Self.carrierA.id
        }
    }

    @Test("carrierRowTapped same row collapses it")
    func testCarrierRowTappedCollapses() async {
        var initial = CarrierManagementFeature.State()
        initial.carriers = [Self.carrierA]
        initial.expandedCarrierId = Self.carrierA.id
        let store = await TestStore(initialState: initial) {
            CarrierManagementFeature()
        }

        await store.send(.carrierRowTapped(Self.carrierA.id)) {
            $0.expandedCarrierId = nil
        }
    }

    @Test("carrierRowTapped different row switches expansion")
    func testCarrierRowTappedSwitches() async {
        var initial = CarrierManagementFeature.State()
        initial.carriers = [Self.carrierA, Self.carrierB]
        initial.expandedCarrierId = Self.carrierA.id
        let store = await TestStore(initialState: initial) {
            CarrierManagementFeature()
        }

        await store.send(.carrierRowTapped(Self.carrierB.id)) {
            $0.expandedCarrierId = Self.carrierB.id
        }
    }

    @Test("addTapped presents add form")
    func testAddTapped() async {
        let store = await TestStore(
            initialState: CarrierManagementFeature.State()
        ) { CarrierManagementFeature() }

        await store.send(.addTapped) {
            $0.addEdit = AddEditCarrierFeature.State(mode: .add)
        }
    }

    @Test("deleteTapped removes carrier and reloads")
    func testDeleteTapped() async {
        let deletedId: LockIsolated<Carrier.ID?> = LockIsolated(nil)
        var initial = CarrierManagementFeature.State()
        initial.carriers = [Self.carrierA, Self.carrierB]

        let store = await TestStore(initialState: initial) {
            CarrierManagementFeature()
        } withDependencies: {
            $0.carrierClient.delete = { id in deletedId.setValue(id) }
            $0.carrierClient.fetchAll = { [Self.carrierB] }
        }

        await store.send(.deleteTapped(Self.carrierA.id))
        await store.receive(\.carriersLoaded) {
            $0.carriers = [Self.carrierB]
        }

        #expect(deletedId.value == Self.carrierA.id)
    }

    @Test("saved delegate reloads carriers")
    func testSavedDelegateReloads() async {
        let store = await TestStore(
            initialState: CarrierManagementFeature.State()
        ) {
            CarrierManagementFeature()
        } withDependencies: {
            $0.carrierClient.fetchAll = { [Self.carrierA] }
        }

        await store.send(.addEdit(.presented(.delegate(.saved)))) {
            $0.addEdit = nil
        }
        await store.receive(\.carriersLoaded) {
            $0.carriers = [Self.carrierA]
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/CarrierManagementFeatureTests 2>&1 | tail -20
```

Expected: compile error — `CarrierManagementFeature` not found.

- [ ] **Step 3: Create CarrierManagementFeature.swift**

```swift
// Features/Sources/Features/CarrierManagement/CarrierManagementFeature.swift
import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct CarrierManagementFeature: Sendable {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var carriers: [Carrier] = []
        public var isLoading: Bool = false
        public var expandedCarrierId: Carrier.ID? = nil
        @Presents public var addEdit: AddEditCarrierFeature.State?

        public init() {}
    }

    public enum Action: Sendable, Equatable {
        case task
        case carriersLoaded([Carrier])
        case carrierRowTapped(Carrier.ID)
        case addTapped
        case deleteTapped(Carrier.ID)
        case addEdit(PresentationAction<AddEditCarrierFeature.Action>)
    }

    @Dependency(\.carrierClient) var carrierClient

    private enum CancelID { case task }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isLoading = true
                return .run { send in
                    let carriers = try await carrierClient.fetchAll()
                    await send(.carriersLoaded(carriers))
                }
                .cancellable(id: CancelID.task)

            case let .carriersLoaded(carriers):
                state.isLoading = false
                state.carriers = carriers
                return .none

            case let .carrierRowTapped(id):
                if state.expandedCarrierId == id {
                    state.expandedCarrierId = nil
                } else {
                    state.expandedCarrierId = id
                }
                return .none

            case .addTapped:
                state.addEdit = AddEditCarrierFeature.State(mode: .add)
                return .none

            case let .deleteTapped(id):
                state.expandedCarrierId = nil
                return .run { send in
                    try await carrierClient.delete(id)
                    let carriers = try await carrierClient.fetchAll()
                    await send(.carriersLoaded(carriers))
                }

            case .addEdit(.presented(.delegate(.saved))):
                state.addEdit = nil
                return .run { send in
                    let carriers = try await carrierClient.fetchAll()
                    await send(.carriersLoaded(carriers))
                }

            case .addEdit(.presented(.delegate(.dismissed))):
                state.addEdit = nil
                return .none

            case .addEdit:
                return .none
            }
        }
        .ifLet(\.$addEdit, action: \.addEdit) {
            AddEditCarrierFeature()
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/CarrierManagementFeatureTests 2>&1 | tail -20
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Features/CarrierManagement/CarrierManagementFeature.swift \
        Features/Tests/FeaturesTests/CarrierManagementFeatureTests.swift
git commit -m "feat(features): add CarrierManagementFeature with TDD — list, expand/collapse, delete"
```

---

## Task 5: Views — AddEditCarrierView + CarrierManagementView

**Files:**
- Create: `Features/Sources/Features/CarrierManagement/AddEditCarrierView.swift`
- Create: `Features/Sources/Features/CarrierManagement/CarrierManagementView.swift`

- [ ] **Step 1: Create AddEditCarrierView.swift**

```swift
// Features/Sources/Features/CarrierManagement/AddEditCarrierView.swift
import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct AddEditCarrierView: View {
    @Bindable var store: StoreOf<AddEditCarrierFeature>

    public init(store: StoreOf<AddEditCarrierFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: Name
                Section {
                    TextField(
                        String(localized: "carrier_name_placeholder"),
                        text: Binding(
                            get: { store.name },
                            set: { store.send(.nameChanged($0)) }
                        )
                    )
                } header: {
                    Text(String(localized: "carrier_name_label"))
                }

                // MARK: Type
                Section {
                    Picker(
                        String(localized: "carrier_type_label"),
                        selection: Binding(
                            get: { store.type },
                            set: { store.send(.typeChanged($0)) }
                        )
                    ) {
                        ForEach(CarrierType.allCases, id: \.self) { type in
                            Text(type.defaultName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                // MARK: Barcode
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField(
                            store.type == .phoneBarcodeCarrier ? "/XXXXXXX" : "/PXXXXXXXXXXXXXXXX",
                            text: Binding(
                                get: { store.barcode },
                                set: { store.send(.barcodeChanged($0.uppercased())) }
                            )
                        )
                        .font(Font.Design.mono)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)

                        if let error = store.barcodeError {
                            Text(error)
                                .font(Font.Design.caption)
                                .foregroundStyle(Color.Design.expenseRed)
                        }
                    }
                } header: {
                    Text(String(localized: "carrier_barcode_label"))
                }
            }
            .navigationTitle(
                store.mode == .add
                    ? String(localized: "carrier_form_add_title")
                    : String(localized: "carrier_form_edit_title")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common_cancel")) {
                        store.send(.cancelTapped)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common_save")) {
                        store.send(.saveTapped)
                    }
                    .fontWeight(.semibold)
                    .disabled(!store.canSave)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Create CarrierManagementView.swift**

```swift
// Features/Sources/Features/CarrierManagement/CarrierManagementView.swift
import Common
import ComposableArchitecture
import CoreImage
import CoreImage.CIFilterBuiltins
import Domain
import SwiftUI
import UIKit

public struct CarrierManagementView: View {
    @Bindable var store: StoreOf<CarrierManagementFeature>

    public init(store: StoreOf<CarrierManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            if store.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.carriers.isEmpty {
                emptyState
            } else {
                carrierList
            }
        }
        .navigationTitle(String(localized: "carrier_management_title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.addTapped)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await store.send(.task).finish()
        }
        .sheet(item: $store.scope(state: \.addEdit, action: \.addEdit)) { addEditStore in
            AddEditCarrierView(store: addEditStore)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "creditcard.and.123",
            title: String(localized: "carrier_empty_state"),
            description: String(localized: "carrier_empty_state_desc"),
            actionTitle: String(localized: "carrier_add_button")
        ) {
            store.send(.addTapped)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Carrier List

    private var carrierList: some View {
        List {
            ForEach(store.carriers) { carrier in
                carrierSection(carrier)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            store.send(.deleteTapped(carrier.id))
                        } label: {
                            Label(String(localized: "common_delete"), systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
        .padding(.bottom, 100)
    }

    @ViewBuilder
    private func carrierSection(_ carrier: Carrier) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Row header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.send(.carrierRowTapped(carrier.id))
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(carrier.name)
                            .font(Font.Design.body)
                            .foregroundStyle(Color.Design.textPrimary)
                        Text(carrier.type.defaultName)
                            .font(Font.Design.caption)
                            .foregroundStyle(Color.Design.textSecondary)
                    }
                    Spacer()
                    Image(systemName: store.expandedCarrierId == carrier.id
                          ? "chevron.up" : "chevron.down")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.Design.textTertiary)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)

            // Expanded barcode detail
            if store.expandedCarrierId == carrier.id {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()

                    // Barcode text + copy button
                    HStack {
                        Text(carrier.barcode)
                            .font(Font.Design.mono)
                            .foregroundStyle(Color.Design.textPrimary)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = carrier.barcode
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.Design.brandPrimary)
                        }
                        .buttonStyle(.plain)
                    }

                    // QR Code
                    if let qrImage = generateQRCode(from: carrier.barcode) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 160, height: 160)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 4)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - QR Code Generation

    private func generateQRCode(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
```

- [ ] **Step 3: Build to verify compile**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Features/CarrierManagement/AddEditCarrierView.swift \
        Features/Sources/Features/CarrierManagement/CarrierManagementView.swift
git commit -m "feat(features): add CarrierManagementView and AddEditCarrierView with QR code display"
```

---

## Task 6: Settings Integration + Localizations

**Files:**
- Modify: `Features/Sources/Features/Settings/SettingsFeature.swift`
- Modify: `Features/Sources/Features/Settings/SettingsView.swift`
- Modify: `NeuLedger/Resources/Localizable.xcstrings`

- [ ] **Step 1: Add localisation keys to Localizable.xcstrings**

在 `NeuLedger/Resources/Localizable.xcstrings` 的 `"strings"` 物件中，加入以下 10 個 key（按字母排序插入適當位置）：

```json
"carrier_add_button": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "新增載具" } },
    "en": { "stringUnit": { "state": "translated", "value": "Add Carrier" } }
  }
},
"carrier_barcode_error_cert": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "格式應為 /P 加 16 位英數字" } },
    "en": { "stringUnit": { "state": "translated", "value": "Format must be /P followed by 16 alphanumeric characters" } }
  }
},
"carrier_barcode_error_phone": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "格式應為 /XXXXXXX（斜線加 7 位英數字）" } },
    "en": { "stringUnit": { "state": "translated", "value": "Format must be /XXXXXXX (slash + 7 alphanumeric characters)" } }
  }
},
"carrier_barcode_label": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "條碼" } },
    "en": { "stringUnit": { "state": "translated", "value": "Barcode" } }
  }
},
"carrier_empty_state": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "尚未新增載具" } },
    "en": { "stringUnit": { "state": "translated", "value": "No Carriers Added" } }
  }
},
"carrier_empty_state_desc": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "點選右上角 + 新增您的電子發票載具" } },
    "en": { "stringUnit": { "state": "translated", "value": "Tap + to add your e-invoice carrier" } }
  }
},
"carrier_form_add_title": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "新增載具" } },
    "en": { "stringUnit": { "state": "translated", "value": "New Carrier" } }
  }
},
"carrier_form_edit_title": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "編輯載具" } },
    "en": { "stringUnit": { "state": "translated", "value": "Edit Carrier" } }
  }
},
"carrier_management_title": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "我的載具" } },
    "en": { "stringUnit": { "state": "translated", "value": "My Carriers" } }
  }
},
"carrier_name_label": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "名稱（選填）" } },
    "en": { "stringUnit": { "state": "translated", "value": "Name (optional)" } }
  }
},
"carrier_name_placeholder": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "例：我的手機載具" } },
    "en": { "stringUnit": { "state": "translated", "value": "e.g. My Phone Carrier" } }
  }
},
"carrier_type_citizen_cert": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "自然人憑證條碼" } },
    "en": { "stringUnit": { "state": "translated", "value": "Citizen Digital Certificate" } }
  }
},
"carrier_type_label": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "類型" } },
    "en": { "stringUnit": { "state": "translated", "value": "Type" } }
  }
},
"carrier_type_phone_barcode": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "手機條碼載具" } },
    "en": { "stringUnit": { "state": "translated", "value": "Phone Barcode Carrier" } }
  }
},
"settings_carrier_management": {
  "extractionState": "manual",
  "localizations": {
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "載具管理" } },
    "en": { "stringUnit": { "state": "translated", "value": "Carrier Management" } }
  }
},
```

- [ ] **Step 2: Add carrierManagement destination to SettingsFeature.swift**

在 `Features/Sources/Features/Settings/SettingsFeature.swift` 的 `Destination` enum 中加入：

```swift
// Before:
@Reducer(state: .equatable, action: .equatable)
public enum Destination {
    case accountManagement(AccountManagementFeature)
    case categoryManagement(CategoryManagementFeature)
    case budgetManagement(BudgetManagementFeature)
    case tagManagement(TagManagementFeature)
    case notificationSettings(NotificationSettingsFeature)
    case syncSettings(SyncSettingsFeature)
}

// After:
@Reducer(state: .equatable, action: .equatable)
public enum Destination {
    case accountManagement(AccountManagementFeature)
    case categoryManagement(CategoryManagementFeature)
    case budgetManagement(BudgetManagementFeature)
    case tagManagement(TagManagementFeature)
    case notificationSettings(NotificationSettingsFeature)
    case syncSettings(SyncSettingsFeature)
    case carrierManagement(CarrierManagementFeature)
}
```

在 `Action` enum 中加入（在 `syncSettingsTapped` 之後）：

```swift
case carrierManagementTapped
```

在 `body` 的 `Reduce` switch 中，在 `.syncSettingsTapped` case 之後加入：

```swift
case .carrierManagementTapped:
    state.path.append(.carrierManagement(CarrierManagementFeature.State()))
    return .none
```

- [ ] **Step 3: Add carrier row to SettingsView.swift**

在 `Features/Sources/Features/Settings/SettingsView.swift` 的 `sectionManage` 中，在 `syncSettings` 按鈕之後加入：

```swift
Button { store.send(.carrierManagementTapped) } label: {
    settingsRow(
        icon: "creditcard.and.123",
        iconColor: Color.Design.brandAccent,
        label: String(localized: "settings_carrier_management"),
        trailing: chevron
    )
}
.buttonStyle(.plain)
```

在 `SettingsView` 的 `destination` switch 中加入：

```swift
case .carrierManagement(let s):
    CarrierManagementView(store: s)
```

- [ ] **Step 4: Build and run all tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -30
```

Expected: All tests PASS, BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Features/Settings/SettingsFeature.swift \
        Features/Sources/Features/Settings/SettingsView.swift \
        NeuLedger/Resources/Localizable.xcstrings
git commit -m "feat(features): integrate CarrierManagement into Settings — new row and navigation destination"
```

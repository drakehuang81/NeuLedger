import Foundation
import SwiftData
import Dependencies

/// 持有目前使用中的 `ModelContainer`。
///
/// 為什麼要這一層間接：swift-dependencies 以 key 型別為單位快取解析結果，所以
/// 即使 `liveValue` 是 computed property，第一次解析之後就固定住那個
/// `ModelContainer` 實例。切換 iCloud 同步或抹除資料只換掉
/// `PersistenceBootstrap.container`，已快取的依賴不會更新——這一輪 App 生命週期
/// 內新增的資料就不會被 CloudKit 上傳（spec A3）。改成快取這個 **box**，換的是
/// box 的內容而不是 box 本身，取用端就一定拿得到當下的容器。
///
/// **載重的是這兩件事的組合，不是單獨哪一件**：box 是可變的參照型別（換的是
/// `.container` 這個屬性，不是整顆物件），而下面 `modelContainer` /
/// `modelContainerBox` 這兩個 facade 的 getter，每次被存取都重新讀 box 當下的
/// `.container`。日後若有人把任一個 getter「簡化」成快取一次
/// `ModelContainer` 再回傳（例如改成 `let` 或在 init 時就讀出來存住），這個
/// task 修的 bug 會原地復活，而且 `SwiftDataStoreTests` 裡除了
/// `testStoreFollowsTheBox` 以外的既有測試全部依然是綠的——它們驗證的是「換過
/// 的內容讀得到」，不是「換的當下馬上讀得到」，抓不到這種回歸。
public final class ModelContainerBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _container: ModelContainer

    public init(_ container: ModelContainer) { self._container = container }

    public var container: ModelContainer {
        get { lock.lock(); defer { lock.unlock() }; return _container }
        set { lock.lock(); defer { lock.unlock() }; _container = newValue }
    }
}

public extension DependencyValues {
    /// The shared SwiftData `ModelContainer`.
    ///
    /// **Access scope:** only `SwiftDataStore` may depend on this — via
    /// `modelContainerBox` below, **not this property**. See
    /// `docs/architecture.md` §4 / §9 (Anti-Patterns): grepping for
    /// `\.modelContainer)` alone does not audit this boundary, because
    /// `modelContainerBox` is the real door.
    ///
    /// 這個 getter/setter 是 **facade**：只是為了讓既有的
    /// `$0.modelContainer = container` 覆寫寫法繼續有效，不是給新程式碼用的入口。
    ///
    /// **Scope 陷阱**：在 `withDependencies { $0.modelContainer = X }` 範圍內，
    /// 這個 setter 會建立一顆**新的、只在這個 scope 內有效的私有 box**，跟
    /// `PersistenceBootstrap.containerBox`（production 的
    /// `switchToCloudContainer()` / `wipeAllSyncData()` 寫入的那顆共用 box）
    /// **不是同一顆**。所以在這個 scope 內呼叫那兩個 production 入口，scope 內
    /// 的 store 看不到那次切換——也就是說「開啟同步後立刻記帳」這條情境，**用
    /// 既有的覆寫寫法寫不出真的會紅的測試**：寫出來會因為 store 讀的是私有
    /// box、根本沒受到 production 切換影響，而綠得毫無意義。要驗證那條路徑，
    /// 得直接操作 `PersistenceBootstrap.containerBox` 本身，或讓
    /// `switchToCloudContainer()` / `wipeAllSyncData()` 改吃
    /// `@Dependency(\.modelContainerBox)`（follow-up，這次沒有做——見
    /// task-4-report.md）。
    var modelContainer: ModelContainer {
        get { self[ModelContainerBoxKey.self].container }
        set { self[ModelContainerBoxKey.self] = ModelContainerBox(newValue) }
    }

    /// `SwiftDataStore` 取用容器的唯一入口——**真正的門在這裡，不是上面的
    /// `modelContainer`**。任何 Client / Adapter 都不該
    /// `@Dependency(\.modelContainerBox)`；見 `docs/architecture.md` §9。
    var modelContainerBox: ModelContainerBox {
        get { self[ModelContainerBoxKey.self] }
        set { self[ModelContainerBoxKey.self] = newValue }
    }
}

private enum ModelContainerBoxKey: DependencyKey {
    static var liveValue: ModelContainerBox { PersistenceBootstrap.containerBox }
    static var testValue: ModelContainerBox { ModelContainerBox(PersistenceBootstrap.testContainer) }
}

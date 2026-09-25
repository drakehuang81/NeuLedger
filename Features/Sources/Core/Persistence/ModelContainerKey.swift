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
public final class ModelContainerBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _container: ModelContainer

    public init(_ container: ModelContainer) { self._container = container }

    public var container: ModelContainer {
        get { lock.lock(); defer { lock.unlock() }; return _container }
        set { lock.lock(); _container = newValue; lock.unlock() }
    }
}

public extension DependencyValues {
    /// The shared SwiftData `ModelContainer`.
    ///
    /// **Access scope:** only `SwiftDataStore` may depend on this. See
    /// `docs/architecture.md` §4. 讀取端請改用 `modelContainerBox`——
    /// 這個 facade 只是為了讓既有的 `$0.modelContainer = container` 覆寫寫法繼續有效。
    var modelContainer: ModelContainer {
        get { self[ModelContainerBoxKey.self].container }
        set { self[ModelContainerBoxKey.self] = ModelContainerBox(newValue) }
    }

    /// `SwiftDataStore` 取用容器的唯一入口。
    var modelContainerBox: ModelContainerBox {
        get { self[ModelContainerBoxKey.self] }
        set { self[ModelContainerBoxKey.self] = newValue }
    }
}

private enum ModelContainerBoxKey: DependencyKey {
    static var liveValue: ModelContainerBox { PersistenceBootstrap.containerBox }
    static var testValue: ModelContainerBox { ModelContainerBox(PersistenceBootstrap.testContainer) }
}

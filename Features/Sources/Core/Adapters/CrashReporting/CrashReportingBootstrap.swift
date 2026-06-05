import FirebaseCore
import FirebaseCrashlytics

/// Composition-root entry point for Firebase crash reporting.
///
/// Must be called once at process launch (i.e. `App.init()`), before any
/// other launch work — `FirebaseApp.configure()` is also the moment
/// Crashlytics picks up the previous run's crash report, so the earlier
/// the better.
///
/// Collection is disabled by default via the app target's Info.plist key
/// `FirebaseCrashlyticsCollectionEnabled = NO`; Release builds re-enable
/// it here so DEBUG crashes never pollute the dashboard.
///
/// Idempotent: repeated calls are no-ops.
@MainActor
public enum CrashReportingBootstrap {

    private static var started = false

    public static func start() {
        guard !started else { return }
        started = true

        FirebaseApp.configure()
        #if !DEBUG
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
    }
}

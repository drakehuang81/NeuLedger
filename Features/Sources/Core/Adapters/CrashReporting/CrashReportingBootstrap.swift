import Foundation
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
/// `GoogleService-Info.plist` is git-ignored and injected at build time
/// (Xcode Cloud secret env var, see `ci_scripts/ci_post_clone.sh`). When
/// the bundle has no config — fresh clone, CI without the secret — we skip
/// configuration entirely and run with crash reporting disabled instead of
/// crashing inside `FirebaseApp.configure()`.
///
/// Idempotent: repeated calls are no-ops.
@MainActor
public enum CrashReportingBootstrap {

    private static var started = false

    public static func start() {
        guard !started else { return }
        started = true

        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            return
        }

        FirebaseApp.configure()
        #if !DEBUG
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
    }
}

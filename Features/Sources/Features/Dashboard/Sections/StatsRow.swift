import SwiftUI
import ComposableArchitecture
import Common

/// The Dashboard stats row — three pills for today's spending,
/// this week's spending, and savings percentage.
struct StatsRow: View {
    let store: StoreOf<DashboardFeature>

    var body: some View {
        switch store.statsPhase {
        case .idle, .loading:
            content.skeleton(when: true)
        case .loaded:
            content
        case let .failed(message):
            GlassContainer(cornerRadius: 16, padding: 12) {
                SectionFailureView(message: message) {
                    store.send(.retrySection(.stats))
                }
            }
        }
    }

    private var content: some View {
        ProportionalHStack(spacing: 10) {
            StatPill(
                label: "stat_today",
                value: store.todaySpending.twdFormatted
            )
            StatPill(
                label: "stat_week",
                value: store.weekSpending.twdFormatted,
                valueColor: Color.Design.expenseRed
            )
            StatPill(
                label: "stat_saved",
                value: Self.savingsText(store.savingsPercentage),
                valueColor: Self.savingsColor(store.savingsPercentage)
            )
        }
    }

    // 這兩個決定是純函式而不是 View 內的 computed property，因為它們是這一屏
    // 唯一會誤導使用者的地方（綠色的負儲蓄率 = 把壞消息講成好消息），必須測得到。
    // 這個 codebase 沒有 View 層的測試手段，所以把判斷抽出來，讓測試直接餵值。

    /// `nil`（這期沒有收入紀錄）顯示破折號而不是「0%」——後者會被讀成
    /// 「我一毛都沒存下來」，跟「沒有收入可以算」是兩回事。
    static func savingsText(_ rate: Double?) -> String {
        guard let rate else { return "—" }
        return String(format: "%.0f%%", rate * 100)
    }

    /// 綠色只保留給真的存下錢的情況。負儲蓄率印成綠色會把「入不敷出」
    /// 讀成好消息，那正是這一條要修掉的誤導。
    static func savingsColor(_ rate: Double?) -> Color {
        guard let rate else { return .secondary }
        return rate < 0 ? Color.Design.expenseRed : Color.Design.incomeGreen
    }
}

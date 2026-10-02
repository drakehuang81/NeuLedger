import Testing
import SwiftUI
import Common
@testable import Features

/// 釘住 Dashboard「儲蓄率」那顆 pill 的兩個顯示決定。
///
/// 這一屏是整個修正的終點：kernel 不再把負儲蓄率夾成 0、也不再把「沒有收入」
/// 說成 0，但如果這裡照樣把負值印成綠色、把 nil 印成「0%」，使用者看到的
/// 東西跟修正前一模一樣。
@Suite("StatsRow 儲蓄率顯示")
struct StatsRowSavingsTests {

    @Test("nil（沒有收入紀錄）顯示破折號，不是 0%")
    func nilShowsADashNotZeroPercent() {
        #expect(StatsRow.savingsText(nil) == "—")
        #expect(StatsRow.savingsColor(nil) == .secondary,
                "沒有數字就不該套用代表好壞的顏色")
    }

    @Test("負儲蓄率走紅色，不是綠色")
    func negativeIsRed() {
        #expect(StatsRow.savingsText(-0.15) == "-15%")
        #expect(StatsRow.savingsColor(-0.15) == Color.Design.expenseRed,
                "入不敷出印成綠色就是把壞消息講成好消息")
    }

    @Test("正儲蓄率與恰好 0 走綠色")
    func zeroAndPositiveAreGreen() {
        #expect(StatsRow.savingsText(0.28) == "28%")
        #expect(StatsRow.savingsColor(0.28) == Color.Design.incomeGreen)
        // 0 是「收支相抵」，不是壞消息——與 nil（算不出來）分開處理。
        #expect(StatsRow.savingsText(0) == "0%")
        #expect(StatsRow.savingsColor(0) == Color.Design.incomeGreen)
    }
}

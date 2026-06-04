import Foundation
import SwiftData
import Dependencies
import Domain

/// Export section of `LedgerClient.liveValue` (step-5a3 internalisation).
///
/// CSV assembly lifted verbatim from `ExportUseCase+Live`, now reading directly
/// from `SwiftDataStore` (Transaction/Category/Account) instead of delegating to
/// `\.transactionClient`/`\.categoryClient`/`\.accountClient`. The RFC 4180
/// `csvField` escaping and the `yyyy/MM/dd` date format are unchanged.
extension LedgerClient {
    static func makeExportCSV(
        _ transactionStore: SwiftDataStore<Transaction, SDTransaction>,
        _ categoryStore: SwiftDataStore<Domain.Category, SDCategory>,
        _ accountStore: SwiftDataStore<Account, SDAccount>
    ) -> @Sendable () async throws -> URL {
        {
            let transactions = try await transactionStore.fetchAll()
            let categories = try await categoryStore.fetchAll()
            let accounts = try await accountStore.fetchAll()

            let categoryMap = Dictionary(
                categories.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            let accountMap = Dictionary(
                accounts.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            let csvHeader = [
                String(localized: "settings_export_csv_header_date"),
                String(localized: "settings_export_csv_header_type"),
                String(localized: "settings_export_csv_header_category"),
                String(localized: "settings_export_csv_header_note"),
                String(localized: "settings_export_csv_header_amount"),
                String(localized: "settings_export_csv_header_account")
            ].joined(separator: ",")

            var lines = [csvHeader]
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd"

            for t in transactions {
                let date = formatter.string(from: t.date)
                let type = t.type.rawValue
                let category = csvField(
                    t.categoryId.flatMap { categoryMap[$0] }?.localizedName ?? ""
                )
                let note = csvField(t.note ?? "")
                let amount: String
                switch t.type {
                case .expense: amount = "-\(t.amount)"
                case .income, .transfer: amount = "\(t.amount)"
                }
                let account = csvField(accountMap[t.accountId]?.name ?? "")
                lines.append("\(date),\(type),\(category),\(note),\(amount),\(account)")
            }

            let csv = lines.joined(separator: "\n")
            // 唯一子目錄：避免與其他匯出（或平行測試）共寫同一固定路徑；
            // 使用者可見檔名（分享面板）維持 NeuLedger_export.csv 不變。
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("NeuLedger_export.csv")
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        }
    }
}

/// RFC 4180 CSV field escaping — wraps in quotes and doubles inner
/// quotes only when the field contains a separator, quote, or newline.
private func csvField(_ value: String) -> String {
    if value.contains(",") || value.contains("\"") || value.contains("\n") {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    return value
}

import Foundation
import Dependencies
import Domain

extension ExportUseCase: DependencyKey {
    public static var liveValue: ExportUseCase {
        @Dependency(\.transactionClient) var transactionClient
        @Dependency(\.categoryClient) var categoryClient
        @Dependency(\.accountClient) var accountClient

        return ExportUseCase(
            exportTransactionsCSV: {
                let transactions = try await transactionClient.fetchAll()
                let categories = try await categoryClient.fetchAll()
                let accounts = try await accountClient.fetchAll()

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
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("NeuLedger_export.csv")
                try csv.write(to: url, atomically: true, encoding: .utf8)
                return url
            }
        )
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

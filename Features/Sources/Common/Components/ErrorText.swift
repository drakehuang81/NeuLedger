import SwiftUI

/// Inline form error: red alert icon + 12.5pt expenseRed message.
///
/// Use directly under an input field's container.
public struct ErrorText: View {
    private let messageKey: LocalizedStringKey

    public init(_ messageKey: LocalizedStringKey) {
        self.messageKey = messageKey
    }

    /// String-payload initializer for messages produced at runtime
    /// (e.g. localized errors that are already `String`).
    public init(_ message: String) {
        self.messageKey = LocalizedStringKey(message)
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.circle")
                .font(Font.Design.size12Medium)
                .foregroundStyle(Color.Design.expenseRed)
            Text(messageKey)
                .font(.system(size: 12.5))
                .lineSpacing(1.4)
                .foregroundStyle(Color.Design.expenseRed)
        }
        .padding(.top, 6)
    }
}

import Common
import SwiftUI

/// Glass capsule shown at the bottom of the sheet while a delete is
/// pending. Tapping Undo cancels the pending delete.
struct UndoBanner: View {
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.Design.incomeGreen)
            Text("transaction_detail_undo_deleted")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.Design.textPrimary)
            Spacer(minLength: 0)
            Button(action: onUndo) {
                Text("transaction_detail_undo")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.Design.accentOrange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("transaction_detail_undo_button")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(Glass.clear.tint(Color.Design.surface), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityIdentifier("transaction_detail_undo_banner")
    }
}

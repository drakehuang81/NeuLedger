// Features/Sources/Common/Components/SectionFailureView.swift
import SwiftUI

public struct SectionFailureView: View {
    public let message: String
    public let retry: () -> Void

    public init(message: String, retry: @escaping () -> Void) {
        self.message = message
        self.retry = retry
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            Text(message)
                .font(Font.Design.size13)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: retry) {
                Text("common_retry")
                    .font(Font.Design.size13Semibold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.Design.brandPrimary.opacity(0.15)))
                    .foregroundStyle(Color.Design.brandPrimary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

#Preview {
    SectionFailureView(message: "無法載入資料") {}
        .padding()
}

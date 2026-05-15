import SwiftUI
import ComposableArchitecture
import Common

struct DashboardTopBar: View {
    let store: StoreOf<DashboardFeature>

    private var greeting: LocalizedStringKey {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "dashboard_greeting_morning"
        case 12..<18: return "dashboard_greeting_afternoon"
        default:      return "dashboard_greeting_evening"
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEEE · d MMM")
        return formatter.string(from: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarBadge(initials: "D")
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text(dateText)
                    .font(.system(size: 16, weight: .semibold))
            }
            Spacer()
            iconButton(systemName: "sparkles") { /* AI button — no-op for now */ }
            iconButton(systemName: "magnifyingglass") { /* Search button — no-op */ }
        }
    }

    @ViewBuilder
    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(.ultraThinMaterial))
        }
        .buttonStyle(.plain)
    }
}

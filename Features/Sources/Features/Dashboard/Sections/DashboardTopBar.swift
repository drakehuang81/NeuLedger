import SwiftUI
import Common

struct DashboardTopBar: View {
    private var greeting: LocalizedStringKey {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "dashboard_greeting_morning"
        case 12..<18: return "dashboard_greeting_afternoon"
        default:      return "dashboard_greeting_evening"
        }
    }

    private var dateText: String {
        // TODO: DateFormatterr -> add in extension 
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEEE · d MMM")
        return formatter.string(from: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            // Placeholder: shows the app icon until a user profile / avatar source exists.
            AppIconBadge(size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(Font.Design.size13)
                    .foregroundStyle(.secondary)
                Text(dateText)
                    .font(Font.Design.size16Semibold)
            }
            Spacer()
        }
    }
}

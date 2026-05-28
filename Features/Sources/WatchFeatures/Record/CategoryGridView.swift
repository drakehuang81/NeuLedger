import SwiftUI
import ComposableArchitecture
import Domain
import Common

/// Screen 1: a 3-column grid of expense categories. Tap → pick;
/// long-press → open the per-draft account picker.
struct CategoryGridView: View {

    let store: StoreOf<WatchRecordFeature>

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        ScrollView {
            if store.categories.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(store.categories, id: \.id) { category in
                        categoryButton(category)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle(String(localized: "watch_record_title"))
    }

    private func categoryButton(_ category: Domain.Category) -> some View {
        Button {
            store.send(.categoryTapped(category.id))
        } label: {
            ZStack {
                Circle()
                    .fill(Color.Design.fromHex(category.color).opacity(0.25))
                Image(systemName: category.icon)
                    .font(Font.Design.size22SemiboldRounded)
                    .foregroundStyle(Color.Design.fromHex(category.color))
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.4) {
            store.send(.categoryLongPressed(category.id))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.gen3.slash")
                .font(Font.Design.size22SemiboldRounded)
            Text(String(localized: "watch_category_empty_hint"))
                .font(Font.Design.caption)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

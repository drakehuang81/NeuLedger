import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct AddEditCategoryView: View {
    @Bindable var store: StoreOf<AddEditCategoryFeature>

    public init(store: StoreOf<AddEditCategoryFeature>) {
        self.store = store
    }

    private var isEditMode: Bool {
        if case .edit = store.mode { return true }
        return false
    }

    private let availableIcons: [String] = [
        "fork.knife", "car.fill", "gamecontroller.fill", "bag.fill", "house.fill",
        "bolt.fill", "cross.case.fill", "book.fill", "person.2.fill", "briefcase.fill",
        "star.fill", "laptopcomputer", "chart.line.uptrend.xyaxis", "gift.fill",
        "ellipsis.circle.fill", "tag.fill", "cart.fill", "airplane", "heart.fill", "music.note"
    ]

    private let availableColors: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE",
        "#32ADE6", "#007AFF", "#5856D6", "#AF52DE", "#FF2D55"
    ]

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: 名稱
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField(
                            "分類名稱",
                            text: Binding(
                                get: { store.name },
                                set: { store.send(.nameChanged($0)) }
                            )
                        )
                        if let error = store.nameError {
                            Text(error)
                                .font(Font.Design.caption)
                                .foregroundStyle(Color.Design.expenseRed)
                        }
                    }
                } header: {
                    Text("名稱")
                }

                // MARK: 類型
                Section {
                    Picker(
                        "類型",
                        selection: Binding(
                            get: { store.type },
                            set: { store.send(.typeChanged($0)) }
                        )
                    ) {
                        Text("支出").tag(TransactionType.expense)
                        Text("收入").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                    .disabled(store.isDefault)
                    .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    Text("類型")
                }

                // MARK: 圖示
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(availableIcons, id: \.self) { iconName in
                                iconButton(iconName: iconName)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(.init(top: 0, leading: 12, bottom: 0, trailing: 12))
                } header: {
                    Text("圖示")
                }

                // MARK: 顏色
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(availableColors, id: \.self) { hex in
                                colorButton(hex: hex)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(.init(top: 0, leading: 12, bottom: 0, trailing: 12))
                } header: {
                    Text("顏色")
                }

                // MARK: Preview
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: store.colorHex))
                                .frame(width: 44, height: 44)
                            Image(systemName: store.icon)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.white)
                                .font(.system(size: 20, weight: .medium))
                        }
                        Text(store.name.isEmpty ? "分類名稱" : store.name)
                            .font(Font.Design.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                store.name.isEmpty
                                    ? Color.Design.textTertiary
                                    : Color.Design.textPrimary
                            )
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("預覽")
                }
            }
            .navigationTitle(isEditMode ? "編輯分類" : "新增分類")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        store.send(.cancelTapped)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        store.send(.saveTapped)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Icon Button

    private func iconButton(iconName: String) -> some View {
        let isSelected = store.icon == iconName
        return Button {
            store.send(.iconChanged(iconName))
        } label: {
            ZStack {
                Circle()
                    .fill(isSelected ? Color(hex: store.colorHex) : Color.Design.surfaceSecondary)
                    .frame(width: 44, height: 44)
                    .overlay {
                        if isSelected {
                            Circle()
                                .strokeBorder(Color(hex: store.colorHex), lineWidth: 2)
                        }
                    }
                Image(systemName: iconName)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? .white : Color.Design.textSecondary)
                    .font(.system(size: 18, weight: .medium))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Color Button

    private func colorButton(hex: String) -> some View {
        let isSelected = store.colorHex == hex
        return Button {
            store.send(.colorHexChanged(hex))
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 36, height: 36)
                if isSelected {
                    Circle()
                        .strokeBorder(.white, lineWidth: 2.5)
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                        .font(.system(size: 12, weight: .bold))
                }
            }
        }
        .buttonStyle(.plain)
        .overlay {
            if isSelected {
                Circle()
                    .strokeBorder(Color(hex: hex), lineWidth: 2)
                    .frame(width: 42, height: 42)
            }
        }
    }
}

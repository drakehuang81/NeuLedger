import Foundation

/// Shared design-system constants: icon lists and color palettes.
/// Features consume these to avoid hardcoding values in individual form views.
public enum DesignConstants {

    // MARK: - Icon Options

    public static let accountIconOptions: [String] = [
        "creditcard", "banknote", "wallet.bifold", "building.columns",
        "dollarsign.circle", "star.circle", "cart.circle", "briefcase.circle"
    ]

    public static let categoryIconOptions: [String] = [
        "fork.knife", "car.fill", "gamecontroller.fill", "bag.fill", "house.fill",
        "bolt.fill", "cross.case.fill", "book.fill", "person.2.fill", "briefcase.fill",
        "star.fill", "laptopcomputer", "chart.line.uptrend.xyaxis", "gift.fill",
        "ellipsis.circle.fill", "tag.fill", "cart.fill", "airplane", "heart.fill", "music.note"
    ]

    // MARK: - Color Palettes (hex strings)

    /// Category and base tag colors.
    public static let categoryColorOptions: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE",
        "#32ADE6", "#007AFF", "#5856D6", "#AF52DE", "#FF2D55"
    ]

    /// Account colors — brand blue and warm yellow replace grey.
    public static let accountColorOptions: [String] = [
        "#3478F6", "#34C759", "#FF9500", "#FF3B30", "#5856D6",
        "#FF2D55", "#AF52DE", "#00C7BE", "#32ADE6", "#FF9F0A"
    ]

    /// Tag colors — superset of categoryColorOptions, adds brand blue and neutral grey.
    public static let tagColorOptions: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#00C7BE", "#32ADE6", "#007AFF", "#5856D6",
        "#AF52DE", "#FF2D55", "#3478F6", "#8E8E93"
    ]

    /// Default color hex for newly created tags (brand blue, also present in tagColorOptions).
    public static let defaultTagColorHex: String = "#3478F6"
}

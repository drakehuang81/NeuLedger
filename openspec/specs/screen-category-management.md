# Spec: Screen - Category Management
**Purpose**: Define the Category Management UI list, ordering functionality, and editing capabilities.

## Requirements

### Requirement: Category List Structure

#### Scenario: Split by Expense and Income
- **WHEN** the user navigates to the Category Management screen
- **THEN** present a segmented control (`Picker` with `.segmented` style) to switch between "支出" and "收入" categories
- **AND** display a list of categories corresponding to the selected type, fetched via `categoryClient.fetchByType`
- **AND** show the category's colored icon and name
- **AND** default to the "支出" segment on first load

### Requirement: Customization and Ordering

#### Scenario: Reordering Categories
- **WHEN** the user activates the "Edit" mode or uses the drag handler
- **THEN** allow dragging and dropping categories to reorder them
- **AND** after a reorder, reassign `sortOrder` as sequential integers (0, 1, 2, ...) based on the new order
- **AND** persist each category's updated `sortOrder` by calling `categoryClient.update` for each changed category

#### Scenario: Adding a New Category
- **WHEN** the user taps the "+" or "Add" button
- **THEN** present a sheet containing a form to input:
    - Name (Required, validated non-empty)
    - Icon (SF Symbol picker)
    - Color (Color picker)
    - Type (Expense / Income — defaults to the currently selected segment)
- **AND** the new category SHALL have `isDefault = false`
- **AND** validation errors SHALL be displayed inline

#### Scenario: Editing a Category
- **WHEN** the user taps a category
- **THEN** present the edit form (sheet)
- **AND** if the category is a predefined default (`isDefault == true`), the Name, Icon, and Color can be edited, but:
    - It CANNOT be deleted (hide/disable the delete option)
    - Its Type (expense/income) CANNOT be changed
- **AND** if the category is user-created (`isDefault == false`), it CAN be edited or deleted completely

#### Scenario: Deleting a User-Created Category
- **WHEN** the user deletes a custom category
- **THEN** prompt for confirmation: "刪除此分類後，已使用此分類的交易不會被刪除，但將失去分類標記。確定要刪除嗎？"
- **AND** upon confirmation, call `categoryClient.delete(category.id)`

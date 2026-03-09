# Spec: Screen - Tag Management
**Purpose**: Define the Tag Management UI list and editing mechanisms.

## Requirements

### Requirement: Tag Overview UI

#### Scenario: Viewing existing tags
- **WHEN** the user navigates to the Tag Management screen
- **THEN** present a list of all existing tags, fetched via `tagClient.fetchAll`
- **AND** display the tag's color indicator and text name

#### Scenario: Empty State
- **WHEN** there are no tags
- **THEN** display an empty state with a message like "尚未建立任何標籤" and a prompt to add one

### Requirement: Tag Actions

#### Scenario: Adding a New Tag
- **WHEN** the user taps the "+" or "Add" button
- **THEN** present a sheet/alert to input the tag's Name (required, non-empty) and Color
- **AND** upon confirmation, call `tagClient.add` to persist the new tag

#### Scenario: Editing a Tag
- **WHEN** the user taps a tag
- **THEN** present an edit sheet/alert to modify the tag's Name and Color
- **AND** save the changes via `tagClient.update` upon confirmation

#### Scenario: Deleting a Tag
- **WHEN** the user swipes left on a tag, or selects delete in edit mode
- **THEN** present a confirmation dialog: "刪除此標籤將會從所有關聯交易中移除。確定要刪除嗎？"
- **AND** upon confirmation, call `tagClient.delete(tag.id)` which automatically disassociates the tag from all linked transactions (handled at the Core layer)

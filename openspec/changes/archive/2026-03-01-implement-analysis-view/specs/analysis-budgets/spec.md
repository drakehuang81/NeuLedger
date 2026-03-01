## ADDED Requirements

### Requirement: Budget Status Display
The system SHALL display predefined budgets for categories alongside a progress bar indicating current consumption relative to the available budget threshold.

#### Scenario: Displaying category budgets
- **WHEN** there is a planned budget and tracked expenditures for that category
- **THEN** a progress gauge displays showing the name of the budget, progress bar visually depicting the spent/limit ratio, and the remaining amount alongside percentage used

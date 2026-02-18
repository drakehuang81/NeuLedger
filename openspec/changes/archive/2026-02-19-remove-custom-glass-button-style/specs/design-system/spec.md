
## MODIFIED Requirements

### Requirement: GlassButtonStyle Component
The system SHALL use the official `GlassButtonStyle` API provided by iOS 26, instead of a custom implementation.

#### Scenario: Using Glass Button Style
- **WHEN** a developer applies `.buttonStyle(.glass())` to a Button
- **THEN** it MUST use the native SwiftUI `GlassButtonStyle`
- **AND** it MUST render with the standard platform appearance
- **AND** no custom `GlassButtonStyle` struct should be defined in the project

#### Scenario: GlassButton Convenience View
- **WHEN** `GlassButton` is used
- **THEN** it acts as a convenience wrapper around the standard `Button` with `.glass()` style
- **AND** it forwards parameters to the underlying native components


# ADDED Requirements

### Requirement: Design System Implementation
The system SHALL provide a dedicated Design System module (`NeuLedger/DesignSystem`) that implements the visual language defined in `openspec/specs/design-system.md`. This module MUST be framework-agnostic where possible but primarily expose SwiftUI-friendly APIs.

#### Scenario: Using Design Colors
- **WHEN** a developer accesses `Color.Design.incomeGreen`
- **THEN** it returns the correct color from the Asset Catalog, adapting to Light/Dark mode automatically.

#### Scenario: Using Design Fonts
- **WHEN** a developer accesses `Font.Design.amount`
- **THEN** it returns a monospaced, rounded, bold Title font that scales with Dynamic Type.

#### Scenario: Applying Liquid Glass Effect
- **WHEN** a developer applies `.glassEffect(.regular)` to a View
- **THEN** the view renders with a blur background, a subtle white tint (opacity 0.1-0.2 depending on mode), and a thin white border, simulating a glass surface.

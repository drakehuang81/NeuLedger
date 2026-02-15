
# Design: Design System Implementation

## Context

The proposal defines the need to implement the NeuLedger Design System, focusing on Color, Typography, Liquid Glass effects, and core Components. This design document outlines the technical approach to implementing these requirements in SwiftUI.

## Goals / Non-Goals

**Goals:**
-   Deliver a type-safe, easy-to-use API for colors and fonts.
-   Provide a drop-in `LiquidGlass` modifier that encapsulates complex visual effects.
-   Ensure full support for Dark Mode and Dynamic Type.
-   Create a directory structure that scales as new components are added.

**Non-Goals:**
-   Replacing all existing UI in the app immediately (this will be done iteratively).
-   Implementing complex screen layouts (focused on primitives first).

## Decisions

### 1. Color System
We will use `Asset Catalog` for defining color sets to leverage system-level dark mode switching. We will extend `Color` to expose these as static properties.

**API Design:**
```swift
extension Color {
    struct Design {
        static let incomeGreen = Color("incomeGreen")
        // ... other tokens
    }
}
```
*Rationale*: Namespacing under `Color.Design` avoids pollution of the global `Color` namespace and makes it clear which colors belong to our system.

### 2. Typography
We will extend `Font` to provide semantic text styles. Since we are using system fonts, we don't need a custom font loader, but wrapping them ensures consistency.

**API Design:**
```swift
extension Font {
    static let amount = Font.system(.title, design: .rounded).weight(.bold).monospacedDigit()
    // ... other styles
}
```
*Rationale*: Centralizing font definitions allows us to tweak the typography globally without hunting through views.

### 3. Liquid Glass
We will implement `LiquidGlass` as a `ViewModifier` and an extension on `View` for easy access.

**API Design:**
```swift
enum GlassMaterial {
    case regular, prominent
}

extension View {
    func glassEffect(_ material: GlassMaterial = .regular, in shape: some Shape = .rect(cornerRadius: 20)) -> some View
}
```
*Rationale*: A modifier is the most idiomatic way to apply visual effects in SwiftUI. Parameterizing the `Shape` allows the glass effect to be applied to Cards, Buttons (Capsule), or other geometries flexibly.

### 4. Component Structure
We will create a `DesignSystem` group in the project:

```
NeuLedger/
  DesignSystem/
    Tokens/
      Color+Design.swift
      Font+Design.swift
    Effects/
      LiquidGlass.swift
    Components/
      GlassButton.swift
      GlassCard.swift
```
*Rationale*: Grouping by function (Tokens, Effects, Components) keeps the system organized.

## Risks / Trade-offs

-   **Risk**: Hardcoded colors in Asset Catalog might drift from the spec if not maintained.
    -   *Mitigation*: We will use the spec as the source of truth and double-check values during implementation.
-   **Trade-off**: Using strictly semantic names (e.g., `incomeGreen`) might limit flexibility if a design needs "Green" for a non-income context.
    -   *Decision*: We will stick to semantic names to enforce consistency. If a new use case arises, we add a new semantic token.

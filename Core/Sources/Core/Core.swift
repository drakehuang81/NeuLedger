// Core module — Persistence & live client implementations for NeuLedger.
//
// This module provides:
// - SwiftData `@Model` definitions (Persistence/Models/)
// - Domain ↔ SwiftData bidirectional mappers (Mappers/)
// - Live `DependencyKey` implementations for all Domain Clients (Clients/)
// - First-launch default data seeding (Seeding/)

import Foundation
import SwiftData
import Domain

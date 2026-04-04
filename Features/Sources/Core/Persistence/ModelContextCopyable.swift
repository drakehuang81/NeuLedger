import SwiftData

/// Marks an `@Model` class as capable of producing an unbound copy of its scalar data,
/// suitable for insertion into a different `ModelContext`.
///
/// ## Why this protocol exists
/// SwiftData binds every `PersistentModel` instance to the `ModelContext` that first
/// called `insert(_:)` on it. The binding is permanent: `modelContext` is a read-only
/// property synthesised by the `@Model` macro and backed by an `NSManagedObject`
/// whose `managedObjectContext` cannot be changed after registration.
///
/// When migrating data between two containers (e.g. local → CloudKit), you must
/// therefore create fresh, unbound instances — you cannot move existing objects across.
///
/// ## Relationship fields
/// `makeCopy()` copies **scalar data only**. `@Relationship` properties belong to a
/// specific context's object graph and must be resolved by the caller after insertion.
protocol ModelContextCopyable: PersistentModel {
    /// Returns a new, unbound instance carrying the same persistent identity and
    /// scalar data as the receiver. The returned object has `modelContext == nil`
    /// and can be passed to any `ModelContext.insert(_:)`.
    func makeCopy() -> Self
}

// MARK: - Conformances

extension SDTag: ModelContextCopyable {
    func makeCopy() -> SDTag {
        SDTag(id: id, name: name, color: color)
    }
}

extension SDCategory: ModelContextCopyable {
    func makeCopy() -> SDCategory {
        SDCategory(id: id, name: name, icon: icon, color: color, type: type, sortOrder: sortOrder, isDefault: isDefault)
    }
}

extension SDAccount: ModelContextCopyable {
    func makeCopy() -> SDAccount {
        SDAccount(id: id, name: name, type: type, icon: icon, color: color, sortOrder: sortOrder, isArchived: isArchived, createdAt: createdAt)
    }
}

extension SDBudget: ModelContextCopyable {
    func makeCopy() -> SDBudget {
        SDBudget(id: id, name: name, amount: amount, categoryId: categoryId, period: period, startDate: startDate, isActive: isActive)
    }
}

extension SDRecurringTransaction: ModelContextCopyable {
    func makeCopy() -> SDRecurringTransaction {
        SDRecurringTransaction(
            id: id, amount: amount, note: note, categoryId: categoryId,
            accountId: accountId, toAccountId: toAccountId, typeRaw: typeRaw,
            tagIds: tagIds, frequencyRaw: frequencyRaw, nextDueDate: nextDueDate,
            isActive: isActive, createdAt: createdAt
        )
    }
}

extension SDTransaction: ModelContextCopyable {
    /// Copies scalar fields only. The `tags` relationship must be resolved separately
    /// by the caller using a tag map built from the destination context.
    func makeCopy() -> SDTransaction {
        SDTransaction(
            id: id, amount: amount, date: date, note: note, categoryId: categoryId,
            accountId: accountId, toAccountId: toAccountId, type: type,
            aiSuggested: aiSuggested, createdAt: createdAt, updatedAt: updatedAt
        )
    }
}

extension SDCarrier: ModelContextCopyable {
    func makeCopy() -> SDCarrier {
        SDCarrier(id: id, name: name, typeRaw: typeRaw, barcode: barcode, createdAt: createdAt)
    }
}

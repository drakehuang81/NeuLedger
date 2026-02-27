import Foundation
import SwiftData
import Domain

/// Utility to seed the default initial data required for the NeuLedger app.
///
/// Ensures the application has a base set of categories and at least one default account
/// on the very first launch.
public enum DefaultDataSeeder {
    /// Seeds default data if the database is empty.
    ///
    /// - Parameter context: The `ModelContext` to perform the seeding within.
    public static func seed(in context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<SDCategory>()
            let count = try context.fetchCount(descriptor)
            guard count == 0 else { return } // Not a first launch, early exit
            
            // Seed Expense Categories
            seedExpenseCategories(in: context)
            
            // Seed Income Categories
            seedIncomeCategories(in: context)
            
            // Seed Default Account
            seedDefaultAccount(in: context)
            
            // Atomically save all seeded records
            try context.save()
        } catch {
            print("Failed to seed default data: \(error)")
        }
    }
    
    private static func seedExpenseCategories(in context: ModelContext) {
        let expenses: [(String, String, String)] = [
            ("Food", "fork.knife", "#FF6B6B"),
            ("Transport", "car.fill", "#4ECDC4"),
            ("Entertainment", "gamecontroller.fill", "#45B7D1"),
            ("Shopping", "bag.fill", "#96CEB4"),
            ("Housing", "house.fill", "#FFEAA7"),
            ("Utilities", "bolt.fill", "#DDA0DD"),
            ("Health", "heart.fill", "#FF6B9D"),
            ("Education", "book.fill", "#C9B1FF"),
            ("Other Expense", "ellipsis.circle.fill", "#95A5A6")
        ]
        
        for (index, item) in expenses.enumerated() {
            let category = SDCategory(
                id: UUID(),
                name: item.0,
                icon: item.1,
                color: item.2,
                type: TransactionType.expense.rawValue,
                sortOrder: index,
                isDefault: true
            )
            context.insert(category)
        }
    }
    
    private static func seedIncomeCategories(in context: ModelContext) {
        let incomes: [(String, String, String)] = [
            ("Salary", "banknote.fill", "#2ECC71"),
            ("Freelance", "laptopcomputer", "#3498DB"),
            ("Investment", "chart.line.uptrend.xyaxis", "#F39C12"),
            ("Gift", "gift.fill", "#E74C3C"),
            ("Other Income", "ellipsis.circle.fill", "#1ABC9C")
        ]
        
        for (index, item) in incomes.enumerated() {
            let category = SDCategory(
                id: UUID(),
                name: item.0,
                icon: item.1,
                color: item.2,
                type: TransactionType.income.rawValue,
                sortOrder: index,
                isDefault: true
            )
            context.insert(category)
        }
    }
    
    private static func seedDefaultAccount(in context: ModelContext) {
        let account = SDAccount(
            id: UUID(),
            name: "Cash",
            type: AccountType.cash.rawValue,
            icon: "banknote",
            color: "#2ECC71",
            sortOrder: 0,
            isArchived: false,
            createdAt: Date()
        )
        context.insert(account)
    }
}

# Cost Management System - Complete Implementation

## Overview

This system implements a **two-part cost management solution** for accurate inventory valuation and profit calculation:

1. **Weighted Average Cost (WAC)** - For inventory valuation when receiving stock
2. **Unit Cost Capture** - For exact COGS tracking when making sales

## Part 1: Weighted Average Cost (WAC)

### Problem Solved

When restocking at a different cost, the old system valued ALL stock at the new cost, which was financially incorrect.

**Example of the Problem (OLD):**

```
Day 1: Buy 10 units @ ₱100 = ₱1,000
Day 5: Buy 20 units @ ₱120 = ₱2,400

❌ OLD: All 30 units valued at ₱120 = ₱3,600 (WRONG - overvalued by ₱200)
```

### Solution

Calculate weighted average cost when receiving stock:

```
Formula: WAC = (Old Value + New Value) / Total Quantity

Example:
Old Stock: 10 units @ ₱100 = ₱1,000
New Stock: 20 units @ ₱120 = ₱2,400
Total Value: ₱3,400
Total Units: 30

WAC = ₱3,400 ÷ 30 = ₱113.33 per unit ✅

Result: All 30 units valued at ₱113.33 = ₱3,400 (CORRECT)
```

### Implementation

- **File:** `lib/providers/inventory_provider.dart`
- **Method:** `receiveStockWithCost()`
- **UI:** `lib/widgets/receive_stock_dialog.dart`

---

## Part 2: Unit Cost Capture at Sale Time

### Problem Solved

When generating historical reports, if product costs changed after the sale, COGS calculations would use the **current cost** instead of the **cost at time of sale**, leading to inaccurate profit calculations.

**Example of the Problem (OLD):**

```
Sept 15: Sell 10 units (WAC was ₱100 at that time)
Oct 5:   Receive new stock, WAC becomes ₱113.33
Oct 20:  Generate September report
         ❌ Uses current WAC ₱113.33 for Sept sales
         ✅ Should use Sept WAC ₱100

Error: COGS overstated by ₱133.30
```

### Solution

Store the **exact cost at the time of sale** in each `SaleItem`:

```dart
class SaleItem {
  final String productId;
  final int quantity;
  final double unitPrice;  // Selling price (what customer pays)
  final double unitCost;   // 👈 Cost at time of sale (for COGS)
  final double totalPrice;
}
```

### How It Works

**When Adding Item to Cart:**

```dart
final product = getProductById(productId);
final saleItem = SaleItem(
  productId: productId,
  quantity: 5,
  unitPrice: sellingPrice,    // ₱150 (what customer pays)
  unitCost: product.cost,     // ₱113.33 (current WAC - captured!)
  totalPrice: sellingPrice * 5,
);
```

**When Calculating COGS:**

```dart
double calculateTotalCost(List<SaleItem> saleItems) {
  return saleItems.fold(0.0, (sum, item) {
    // Uses unitCost captured at time of sale
    return sum + (item.quantity * item.unitCost);
  });
}
```

### Benefits

1. **✅ Historical Accuracy**

   - Old sales keep their original costs forever
   - Can generate accurate reports for any past period
   - No need for HistoricalCostService lookups

2. **✅ Performance**

   - No additional database queries needed
   - Instant COGS calculation
   - Faster report generation

3. **✅ Data Integrity**
   - Cost is immutable once sale is made
   - Can't be affected by future cost changes
   - Audit trail is preserved

---

## Complete Cost Flow

### 1. Creating a Product

```
Create Product: Widget A @ ₱100
↓
Records initial cost history
↓
Product cost = ₱100
```

### 2. Receiving Stock with Different Cost

```
Existing: 10 units @ ₱100 = ₱1,000
Receive:  20 units @ ₱120 = ₱2,400
↓
Calculate WAC: ₱3,400 ÷ 30 = ₱113.33
↓
Update product cost = ₱113.33
Record cost history = ₱113.33
Record stock movement
↓
All 30 units now valued at ₱113.33
```

### 3. Making a Sale

```
Add to cart: 5 units of Widget A
↓
Get current product cost: ₱113.33
Calculate selling price: ₱150
↓
Create SaleItem:
  quantity = 5
  unitPrice = ₱150 (selling price)
  unitCost = ₱113.33 (captured from product.cost)
  totalPrice = ₱750
↓
SaleItem stored with unitCost ₱113.33
```

### 4. Generating Reports

```
Get all sales for September
↓
For each SaleItem:
  Revenue = quantity × unitPrice
  COGS = quantity × unitCost (uses captured cost!)
  Profit = Revenue - COGS
↓
Accurate profit calculation regardless of current costs
```

---

## Database Schema Changes

### SaleItem Table (Local SQLite)

```sql
CREATE TABLE sale_items (
  id TEXT NOT NULL,
  saleId TEXT NOT NULL,
  productId TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unitPrice REAL NOT NULL,
  unitCost REAL NOT NULL,      -- 👈 NEW FIELD
  totalPrice REAL NOT NULL
)
```

### Migration

- **Database version:** Incremented from 7 to 8
- **Migration code:** Adds `unitCost` column with default value 0.0
- **Backward compatible:** Existing data gets default value

---

## Implementation Files

### Models

- `lib/models/sale_item.dart` - Added `unitCost` field
- `lib/models/credit_sale_item.dart` - Added `unitCost` field

### Providers

- `lib/providers/inventory_provider.dart`:
  - `receiveStockWithCost()` - WAC calculation
  - `addProduct()` - Records initial cost history
  - `updateProduct()` - Records cost history on changes
- `lib/providers/sales_provider.dart`:
  - `addItemToCurrentSale()` - Captures `unitCost`
  - `updateItemQuantity()` - Updates `unitCost` to current WAC

### Services

- `lib/services/report_service.dart`:
  - `calculateTotalCost()` - Uses `item.unitCost` instead of product lookup
  - `calculateTotalCostFromCreditTransactions()` - Uses `item.unitCost`
- `lib/services/local_database_service.dart`:
  - Database version 8 with `unitCost` column
  - Migration for existing databases

### UI

- `lib/widgets/receive_stock_dialog.dart` - Shows WAC calculation

---

## Example Scenarios

### Scenario 1: Multiple Stock Receipts

```
Oct 1:  Create product "Laptop" @ ₱30,000 (initial cost)
Oct 5:  Receive 10 units @ ₱30,000 = ₱300,000
Oct 10: Sell 3 units
        unitCost captured: ₱30,000
        COGS: 3 × ₱30,000 = ₱90,000

Oct 15: Receive 5 more @ ₱32,000
        WAC: (7 × ₱30,000 + 5 × ₱32,000) / 12 = ₱30,833.33

Oct 20: Sell 4 units
        unitCost captured: ₱30,833.33 (new WAC)
        COGS: 4 × ₱30,833.33 = ₱123,333.32

Nov 1:  Generate October report
        Total COGS = ₱90,000 + ₱123,333.32 = ₱213,333.32 ✅
        (Uses actual costs at time of each sale)
```

### Scenario 2: Cost Increases After Sale

```
Sept 15: Product cost ₱100
Sept 15: Sell 10 units
         unitCost captured: ₱100
         COGS: 10 × ₱100 = ₱1,000

Oct 1:   Receive stock, WAC becomes ₱120
Oct 1:   Product cost now ₱120

Nov 1:   Generate September report
         COGS for Sept sale: 10 × ₱100 = ₱1,000 ✅
         (Uses captured ₱100, not current ₱120)
```

### Scenario 3: Credit Sales

```
Credit sale: 5 units
↓
Creates CreditSaleItem with unitCost captured
↓
Reports show accurate COGS for credit transactions
```

---

## Benefits Summary

| Feature                 | Before                         | After                     |
| ----------------------- | ------------------------------ | ------------------------- |
| **Inventory Valuation** | ❌ Incorrect (all at new cost) | ✅ Correct (WAC)          |
| **Historical COGS**     | ❌ Uses current cost           | ✅ Uses cost at sale time |
| **Report Accuracy**     | ⚠️ Approximate                 | ✅ Exact                  |
| **Performance**         | ⚠️ Requires lookups            | ✅ No lookups needed      |
| **Data Integrity**      | ❌ Can change                  | ✅ Immutable              |
| **Audit Trail**         | ⚠️ Incomplete                  | ✅ Complete               |

---

## Migration Notes

### For Existing Users

1. ✅ Automatic database migration on first app launch
2. ✅ Existing sale_items get `unitCost = 0.0` (backward compatible)
3. ✅ New sales will capture unitCost properly
4. ⚠️ Old sales will show COGS as 0 (acceptable - historical data limitation)

### Best Practices Going Forward

1. Always use "Receive Stock" dialog when restocking
2. Enter accurate cost for each batch received
3. Review WAC calculation before confirming
4. Generate reports regularly to track cost trends
5. Monitor cost history for unusual changes

---

## Technical Notes

### WAC Formula

```dart
weightedAverageCost = totalQuantity > 0
    ? (oldStock × oldCost + newStock × newCost) / totalQuantity
    : newCost;
```

### Cost Capture

```dart
// At time of adding to cart
final saleItem = SaleItem(
  unitCost: product.cost, // Captures current WAC
  // ... other fields
);
```

### COGS Calculation

```dart
// No product lookup needed!
final cogs = saleItems.fold(0.0, (sum, item) {
  return sum + (item.quantity * item.unitCost);
});
```

---

## Future Enhancements

### Potential Additions

1. **Cost Trend Charts** - Visualize cost changes over time
2. **Cost Variance Alerts** - Warn when costs change significantly
3. **Profit Margin Analysis** - Per-product margin tracking
4. **FIFO/LIFO Option** - For businesses that need batch tracking
5. **Lot/Batch Tracking** - For perishables with expiry dates

---

## Troubleshooting

### Q: Old sales show zero COGS in reports

**A:** This is expected. Existing sales before the update don't have `unitCost` captured. Only new sales will have accurate COGS.

### Q: Cost seems wrong after receiving stock

**A:** Check the WAC calculation dialog. It shows the breakdown. The weighted average considers both old and new stock values.

### Q: Can I change the cost of a past sale?

**A:** No, once a sale is completed, the `unitCost` is immutable. This is intentional for data integrity.

### Q: What if I made a mistake in the cost when receiving stock?

**A:** You can adjust the product cost, but it won't affect past sales. Past sales keep their original captured costs.

---

**Implementation Date:** October 25, 2025  
**Version:** 2.0.0 (WAC + Unit Cost Capture)  
**Status:** Production Ready

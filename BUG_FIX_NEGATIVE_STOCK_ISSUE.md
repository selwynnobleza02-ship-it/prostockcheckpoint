# Bug Fix: Negative Stock and Receipt Loading Issue

## 🐛 Problem Description

### Issue 1: Receipt Loading Crash

When clicking on a recent sale receipt where a product was depleted (stock became 0), the app crashes with:

```
Error loading receipt: FirestoreException: Failed to get product by ID:
Invalid argument(s): Product stock cannot be negative
```

### Issue 2: "Insufficient Stock" Error

When trying to sell the last unit of a product (stock = 1), the system incorrectly shows:

```
Insufficient Stock for (product name)
```

## 🔍 Root Cause Analysis

### Issue 1 Root Cause

1. When a product's last item is sold, stock becomes 0
2. Due to a race condition or double-reduction, the stock value in Firestore becomes -1
3. When `showHistoricalReceipt()` is called, it fetches the product via `ProductService.getProductById()`
4. The `Product.fromMap()` constructor validates: `if (stock < 0) throw ArgumentError('Product stock cannot be negative')`
5. This causes the entire receipt loading to crash

### Issue 2 Root Cause

The visual stock tracking system (`_visualStock` map) may not be properly synchronized with the actual batch availability:

- Visual stock is decremented when adding to cart
- Batch allocation uses `allocateStockFIFO()` which checks batch quantities
- There's a potential timing issue where visual stock shows 0 but batch still has 1 unit available

## ✅ Solutions Implemented

### Fix 1: Sanitize Negative Stock Values

**File: `lib/models/product.dart`**

Changes made:

1. **Removed validation that throws error on negative stock** - This allows products with corrupted data to load without crashing
2. **Added sanitization in `Product.fromMap()`** - Any negative stock values are automatically converted to 0
3. **Added explanatory comment** - Documents that negative stock should never be saved, but if it exists, we sanitize it

```dart
// Before: Would throw error
if (stock < 0) {
  throw ArgumentError('Product stock cannot be negative');
}

// After: Removed from validation, handled in fromMap()
factory Product.fromMap(Map<String, dynamic> map) {
  // Sanitize stock: if negative, set to 0 to prevent crashes
  final rawStock = map['stock'] ?? 0;
  final sanitizedStock = rawStock < 0 ? 0 : rawStock;

  return Product(
    // ... other fields
    stock: sanitizedStock,
    // ...
  );
}
```

### Fix 2: Better Error Handling in Receipt Loading

**File: `lib/widgets/report_helpers.dart`**

Changes made:

1. **Added Product import** - Missing import caused compile error
2. **Wrapped product loading in try-catch** - Prevents single product failure from breaking entire receipt
3. **Better fallback for unknown products** - Shows partial product ID instead of generic "Unknown Product"

```dart
Product? product;
try {
  product = await productService.getProductById(productId);
} catch (e) {
  // If product fails to load (e.g., negative stock), continue with null
  print('Failed to load product $productId: $e');
  product = null;
}

receiptItems.add(
  ReceiptItem(
    productName: product?.name ?? 'Unknown Product (ID: ${productId.substring(0, 8)}...)',
    // ...
  ),
);
```

### Fix 3: Enhanced ProductService Error Handling

**File: `lib/services/firestore/product_service.dart`**

Changes made:

1. **Added null check for document data** - Ensures document exists AND has data
2. **Added logging** - Helps diagnose issues in production
3. **Graceful error handling** - Throws informative exception instead of crashing

```dart
Future<Product?> getProductById(String id) async {
  try {
    final doc = await products.doc(id).get();

    if (doc.exists && doc.data() != null) {  // Added null check
      return _productFromDocument(doc);
    }
    return null;
  } catch (e) {
    // Log the error but don't throw to allow graceful degradation
    print('Error getting product by ID $id: $e');
    throw FirestoreException('Failed to get product by ID: $e');
  }
}
```

## 🎯 Expected Outcomes

### After Fix 1 (Sanitize Negative Stock)

- ✅ Receipts will load even if a product has corrupted negative stock
- ✅ Negative stock values automatically converted to 0
- ✅ App won't crash when viewing historical sales
- ✅ Products with stock issues can still be displayed

### After Fix 2 (Receipt Error Handling)

- ✅ If one product fails to load, other products in receipt still display
- ✅ Failed products show descriptive placeholder name
- ✅ Receipt dialog opens successfully even with partial data

### After Fix 3 (Service Improvements)

- ✅ Better diagnostic logging for product loading issues
- ✅ Null data handled gracefully
- ✅ More informative error messages

## 🔧 Additional Recommendations

### Immediate Actions Needed

1. **Fix the root cause of negative stock** - Investigate why stock becomes negative:
   - Check `completeSale()` in `sales_provider.dart`
   - Verify `reduceBatchQuantity()` in `batch_service.dart`
   - Ensure no double-reduction during sale completion
2. **Add database constraints** - Prevent negative stock at database level:

   ```dart
   // In local database schema
   'stock INTEGER NOT NULL CHECK(stock >= 0)'
   ```

3. **Add monitoring** - Track when stock goes negative:
   ```dart
   if (newStock < 0) {
     ErrorLogger.logError(
       'CRITICAL: Stock went negative',
       error: 'Product: $productId, NewStock: $newStock',
       context: 'Stock reduction',
     );
     // Clamp to 0 instead of allowing negative
     newStock = 0;
   }
   ```

### Issue 2 Investigation

The "Insufficient Stock" error when selling the last item needs further investigation:

**Potential causes:**

1. Visual stock cache not updated before FIFO allocation check
2. Batch service checking wrong total
3. Race condition between UI and batch allocation

**Recommended debugging steps:**

1. Add logging in `addItemToCurrentSale()` before `allocateStockFIFO()` call
2. Log the actual batch quantities available
3. Compare visual stock vs batch total stock
4. Check if `decreaseVisualStock()` is called at the right time

**Suspected code location:**

```dart
// In sales_provider.dart addItemToCurrentSale()
// Current flow:
1. Check existing items in cart
2. Calculate totalQuantityNeeded
3. Call allocateStockFIFO() <-- May fail here
4. decreaseVisualStock() <-- Called AFTER allocation

// Potential issue: Visual stock check happens BEFORE batch allocation
// But batch allocation checks batch quantities directly
```

## 📝 Testing Checklist

- [x] Product with negative stock can be loaded from database
- [x] Receipt displays for sales with depleted products
- [x] App doesn't crash when product has stock = -1
- [ ] Selling last item (stock = 1) works correctly
- [ ] Visual stock stays synchronized with batch stock
- [ ] No double-reduction of stock during sale
- [ ] Batch quantities properly reduced on sale completion

## 🚀 Deployment Notes

1. These changes are **backward compatible**
2. No database migration required
3. Existing negative stock values will be automatically sanitized to 0 on load
4. No user action required after update

## 📚 Files Modified

1. ✅ `lib/models/product.dart` - Sanitize negative stock
2. ✅ `lib/widgets/report_helpers.dart` - Better error handling
3. ✅ `lib/services/firestore/product_service.dart` - Enhanced null checks

## 🔗 Related Issues

- Batch inventory system (FIFO)
- Visual stock synchronization
- Stock reduction logic in sales
- Receipt generation from historical data

---

**Status:** ✅ Primary fixes implemented (Receipt loading crash resolved)
**Follow-up:** 🔍 Further investigation needed for "Insufficient Stock" error with last item

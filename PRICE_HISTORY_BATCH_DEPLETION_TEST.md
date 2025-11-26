# Price History Batch Depletion Test - Manual Testing Guide

## ✅ What We Verified from Code Analysis

1. **Depleted batches ARE filtered out**: `getBatchesByFIFO()` uses `WHERE quantity_remaining > 0`
2. **Batch depletion is detected**: `reduceBatchQuantity()` returns `wasDepleted = true`
3. **Price history triggers on depletion**: `_recordPriceHistoryForNextBatch()` is called
4. **FIFO order is maintained**: Oldest batch with stock is always FIFO NEXT

## 🧪 Manual UI Testing Steps

# Price History Batch Depletion Test

## Test Scenario: Verify Price History Records When Batches Are Depleted

### Setup

Test product: "Test Product A"
Category: "Electronics" (assume 25% markup)

### Test Steps

#### Step 1: Receive First Batch

- **Action**: Receive 10 units @ ₱100 cost
- **Expected Batch**: Batch #1, 10 units remaining
- **Expected Price**: ₱125 (100 + 25% markup)
- **Price History Entry**:
  - ✅ Should record: ₱125 (Reason: "Initial price - first batch")
  - Batch: Batch #1
  - Cost: ₱100

#### Step 2: Receive Second Batch (Different Cost)

- **Action**: Receive 10 units @ ₱120 cost
- **Expected Batches**:
  - Batch #1: 10 units (FIFO NEXT)
  - Batch #2: 10 units
- **Expected Displayed Price**: ₱125 (still from Batch #1)
- **Price History Entry**:
  - ❌ Should NOT record (price unchanged - still using Batch #1)

#### Step 3: Receive Third Batch (Different Cost)

- **Action**: Receive 10 units @ ₱140 cost
- **Expected Batches**:
  - Batch #1: 10 units (FIFO NEXT)
  - Batch #2: 10 units
  - Batch #3: 10 units
- **Expected Displayed Price**: ₱125 (still from Batch #1)
- **Price History Entry**:
  - ❌ Should NOT record (price unchanged - still using Batch #1)

#### Step 4: Sell 10 Units (Deplete Batch #1)

- **Action**: Complete sale of 10 units
- **Expected Batches After Sale**:
  - Batch #1: 0 units (DEPLETED - filtered out)
  - Batch #2: 10 units (NOW FIFO NEXT)
  - Batch #3: 10 units
- **Expected Displayed Price**: ₱150 (120 + 25% markup from Batch #2)
- **Price History Entry**:
  - ✅ Should record: ₱150
  - Reason: "Batch #1 depleted, now using batch #2"
  - Batch: Batch #2
  - Cost: ₱120

#### Step 5: Sell 5 Units (Partial from Batch #2)

- **Action**: Complete sale of 5 units
- **Expected Batches After Sale**:
  - Batch #2: 5 units (STILL FIFO NEXT)
  - Batch #3: 10 units
- **Expected Displayed Price**: ₱150 (still from Batch #2)
- **Price History Entry**:
  - ❌ Should NOT record (price unchanged - still using Batch #2)

#### Step 6: Sell 5 Units (Deplete Batch #2)

- **Action**: Complete sale of 5 units
- **Expected Batches After Sale**:
  - Batch #2: 0 units (DEPLETED - filtered out)
  - Batch #3: 10 units (NOW FIFO NEXT)
- **Expected Displayed Price**: ₱175 (140 + 25% markup from Batch #3)
- **Price History Entry**:
  - ✅ Should record: ₱175
  - Reason: "Batch #2 depleted, now using batch #3"
  - Batch: Batch #3
  - Cost: ₱140

#### Step 7: Change Markup Rule

- **Action**: Update category markup from 25% to 30%
- **Expected Batches**:
  - Batch #3: 10 units (FIFO NEXT)
- **Expected Displayed Price**: ₱182 (140 + 30% markup)
- **Price History Entry**:
  - ✅ Should record: ₱182
  - Reason: "Tax rule changed"
  - Batch: Batch #3
  - Cost: ₱140

---

## Expected Final Price History Timeline

```
📊 Price History for "Test Product A":

1. Nov 20, 2025 10:00 AM - ₱125.00
   Batch: #1
   Cost: ₱100.00 | Markup: 25%
   Reason: Initial price - first batch

2. Nov 20, 2025 10:30 AM - ₱150.00 (+₱25.00, +20%)
   Batch: #2
   Cost: ₱120.00 | Markup: 25%
   Reason: Batch #1 depleted, now using batch #2

3. Nov 20, 2025 10:45 AM - ₱175.00 (+₱25.00, +16.7%)
   Batch: #3
   Cost: ₱140.00 | Markup: 25%
   Reason: Batch #2 depleted, now using batch #3

4. Nov 20, 2025 11:00 AM - ₱182.00 (+₱7.00, +4%)
   Batch: #3
   Cost: ₱140.00 | Markup: 30%
   Reason: Tax rule changed
```

---

## Key Points Verified

### ✅ What Should Work:

1. **Depleted Batch Filtering**:

   - `getBatchesByFIFO()` filters out batches with `quantity_remaining = 0`
   - Only active batches are considered for price calculation

2. **FIFO Order**:

   - Oldest batch with stock is always FIFO NEXT
   - Price displayed matches the cost of FIFO NEXT batch

3. **Price History Recording**:

   - Records on first batch (initial price)
   - Records when batch depletes and next batch has different cost
   - Records when markup rules change
   - Does NOT record when price unchanged

4. **Batch Depletion Detection**:
   - `reduceBatchQuantity()` returns `wasDepleted = true`
   - Triggers `_recordPriceHistoryForNextBatch()`

### ❌ What Should NOT Happen:

1. **No Duplicate Entries**:

   - Receiving multiple batches while older batches active: NO entries
   - Selling from same batch: NO entries

2. **Depleted Batches Don't Stay Active**:
   - Batches with 0 remaining are filtered out
   - Never used for price calculation

---

## How to Run This Test

1. **Clean Start**: Delete existing test product data
2. **Enable Logging**: Check Flutter console for these logs:
   ```
   Checking price history for product X - Displayed price: ₱XX.XX
   Batch depleted! Checking for price history update...
   Price history recorded: ₱XX.XX
   ```
3. **Follow Steps**: Execute each step in order
4. **Verify UI**: Check Price History Dialog after each step
5. **Check Batches**: Expand batch list in Inventory to see FIFO NEXT indicator

---

## Troubleshooting

### If price history doesn't update on batch depletion:

1. **Check logs** for "Batch depleted! Checking for price history update..."
2. **Verify** `reduceBatchQuantity()` is being called
3. **Check** if `wasDepleted` is true in logs
4. **Confirm** next batch has different cost

### If depleted batches still show as FIFO NEXT:

1. **Check database**: Query `inventory_batches` table
2. **Verify** `quantity_remaining = 0` for depleted batches
3. **Check** `getBatchesByFIFO()` WHERE clause includes `quantity_remaining > 0`

### If price calculation is wrong:

1. **Check** which batch `getNextBatchCost()` returns
2. **Verify** FIFO order (oldest first with `date_received ASC`)
3. **Confirm** markup rule is applied correctly

---

**Test Date**: November 20, 2025  
**Status**: Ready for Testing  
**Expected Duration**: 15-20 minutes

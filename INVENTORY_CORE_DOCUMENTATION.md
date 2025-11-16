# ProStock - Inventory System Core Documentation

**Generated:** November 12, 2025  
**Project:** ProStock Inventory Management System  
**Module:** Inventory Core

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Core Components](#core-components)
3. [Key Features](#key-features)
4. [Code Structure](#code-structure)

---

## Architecture Overview

The inventory system follows a **Provider-based state management** pattern with the following layers:

```
┌─────────────────────────────────────────┐
│      Presentation Layer (UI)            │
│  - inventory_screen.dart                │
│  - Widgets & Dialogs                    │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│      Business Logic Layer               │
│  - inventory_provider.dart              │
│  - State Management & Operations        │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│      Data Layer                         │
│  - inventory_service.dart (Firestore)   │
│  - local_database_service.dart (SQLite) │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│      Data Models                        │
│  - inventory_batch.dart                 │
│  - product.dart                         │
│  - stock_movement.dart                  │
└─────────────────────────────────────────┘
```

---

## Core Components

### 1. **InventoryProvider** (State Management)

**File:** `lib/providers/inventory_provider.dart`

**Responsibilities:**

- Manages product inventory state
- Handles stock operations (add, update, reduce)
- Implements FIFO batch tracking
- Manages online/offline synchronization
- Provides stock alerts and notifications

**Key Methods:**

```dart
// Product Management
Future<Product?> addProduct(Product product)
Future<UpdateResult> updateProduct(Product product)
Product? getProductById(String id)
Future<void> loadProducts({bool refresh, String? searchQuery})

// Stock Operations
Future<UpdateResult> updateStock(String productId, int newStock, {String? reason})
Future<bool> receiveStock(String productId, int quantity)
Future<bool> receiveStockWithCost(String productId, int quantity, double newCost, {...})
Future<bool> reduceStock(String productId, int quantity, {String? reason, bool offline})

// Batch Management (FIFO)
Future<List<InventoryBatch>> getBatchesForProduct(String productId)
Future<List<InventoryBatch>> getAllBatchesForProduct(String productId)

// Stock Reservations
bool reserveStock(String productId, int quantity)
void releaseReservedStock(String productId, int quantity)
int getAvailableStock(String productId)

// Loss Tracking
Future<bool> addLoss({required String productId, required int quantity, required LossReason reason})

// Bulk Operations
Future<bool> batchUpdateStock(Map<String, int> stockUpdates, {String? reason})
Future<bool> reconcileStock(Map<String, int> physicalCounts)
```

**State Properties:**

```dart
List<Product> products              // Current product list
bool isLoading                      // Loading state
String? error                       // Error message
Map<String, int> visualStock        // UI stock display
Map<String, int> reservedStock      // Reserved for POS
bool isOnline                       // Connectivity status
```

---

### 2. **InventoryService** (Firestore Operations)

**File:** `lib/services/firestore/inventory_service.dart`

**Responsibilities:**

- Firestore CRUD operations for inventory
- Stock movement tracking
- Loss record management

**Key Methods:**

```dart
// Stock Movements
Future<String> insertStockMovement(
  String productId,
  String productName,
  String movementType,
  int quantity,
  String? reason
)

Future<List<StockMovement>> getStockMovementsByProduct(String productId)
Future<PaginatedResult<StockMovement>> getStockMovements({...})
Future<List<StockMovement>> getAllStockMovements({DateTime? startDate, DateTime? endDate})

// Loss Management
Future<void> insertLoss(Loss loss)
Future<List<Loss>> getLosses()
```

---

### 3. **InventoryBatch** (Data Model)

**File:** `lib/models/inventory_batch.dart`

**Purpose:** Implements FIFO (First-In-First-Out) inventory tracking

**Properties:**

```dart
final String id;
final String productId;
final String batchNumber;
final int quantityReceived;
final int quantityRemaining;
final double unitCost;
final DateTime dateReceived;
final String? supplierId;
final String? notes;
```

**Computed Properties:**

```dart
int get quantitySold => quantityReceived - quantityRemaining;
bool get isDepleted => quantityRemaining <= 0;
bool get hasStock => quantityRemaining > 0;
double get totalValue => quantityRemaining * unitCost;
double get soldValue => quantitySold * unitCost;
double get percentageSold => (quantitySold / quantityReceived) * 100;
```

---

### 4. **InventoryScreen** (User Interface)

**File:** `lib/screens/inventory/inventory_screen.dart`

**Features:**

- Product search with debouncing (300ms)
- Barcode scanner integration
- Product list view
- Add/Edit product dialogs
- Sync status indicator
- Action buttons for quick operations

**UI Structure:**

```
AppBar (Title + Barcode Scanner + Sync Status)
  └─ Search Bar
     └─ Action Buttons
        └─ Product List (Scrollable)
           └─ Product Cards
              └─ Expandable Details
                 └─ Batch Information
```

---

## Key Features

### 1. **Offline-First Architecture**

- Local SQLite database for offline operations
- Automatic sync when connection is restored
- Operation queue for failed requests
- Conflict resolution with version control

### 2. **FIFO Batch Tracking**

- Each stock receipt creates a new batch
- Batches consumed in order received
- Cost tracking per batch
- Average cost calculation across batches

**Example Flow:**

```
Receive Stock:
  Batch 1: 100 units @ ₱50/unit
  Batch 2: 50 units @ ₱55/unit

Sell 120 units:
  - First 100 from Batch 1 @ ₱50 = ₱5,000
  - Next 20 from Batch 2 @ ₱55 = ₱1,100
  Total Cost: ₱6,100

Remaining:
  Batch 2: 30 units @ ₱55/unit
```

### 3. **Stock Reservations**

- Reserve stock during POS transactions
- Prevent overselling
- Automatic release on transaction cancel
- Available stock = Total stock - Reserved stock

### 4. **Stock Alerts**

- Low stock notifications
- Out of stock alerts
- Restock confirmations
- Customizable reorder points

### 5. **Loss Tracking**

Supported loss reasons:

- Expired
- Damaged
- Theft
- Spoilage
- Other

---

## Code Structure

### Critical Code Snippets

#### 1. Adding Product with FIFO Batch

```dart
Future<bool> receiveStockWithCost(
  String productId,
  int quantity,
  double newCost, {
  String? supplierId,
  String? notes,
}) async {
  // Create new batch
  final batch = await _batchService.createBatch(
    productId: productId,
    quantity: quantity,
    unitCost: newCost,
    supplierId: supplierId,
    notes: notes,
  );

  // Calculate new totals from all batches
  final totalStock = await _batchService.getTotalAvailableStock(productId);
  final averageCost = await _batchService.calculateAverageCost(productId);

  // Update product with new stock and average cost
  final updatedProduct = product.copyWith(
    stock: totalStock,
    cost: averageCost,
    updatedAt: DateTime.now(),
    version: product.version + 1,
  );

  // Sync to Firestore or queue for offline
  // ... (sync logic)
}
```

#### 2. Stock Reduction with Reservation

```dart
Future<bool> reduceStock(
  String productId,
  int quantity, {
  String? reason,
  bool offline = false,
}) async {
  final product = getProductById(productId);

  // Check sufficient stock
  if (product.stock < quantity) {
    _error = 'Insufficient stock for ${product.name}';
    return false;
  }

  final newStock = product.stock - quantity;
  final updatedProduct = product.copyWith(
    stock: newStock,
    updatedAt: DateTime.now(),
  );

  // Update local database
  await db.update('products', updatedProduct.toMap(),
    where: 'id = ?', whereArgs: [productId]);

  // Sync or queue operation
  if (_offlineManager.isOnline && !offline) {
    await productService.updateProduct(updatedProduct);
    await inventoryService.insertStockMovement(...);
  } else {
    await _offlineManager.queueOperation(...);
  }

  // Release reserved stock
  releaseReservedStock(productId, quantity);

  // Check for stock alerts
  _checkStockAlerts(updatedProduct);
}
```

#### 3. Stock Reconciliation

```dart
Future<bool> reconcileStock(Map<String, int> physicalCounts) async {
  final discrepancies = <String, Map<String, int>>{};

  for (final entry in physicalCounts.entries) {
    final productId = entry.key;
    final physicalCount = entry.value;
    final product = getProductById(productId);

    if (product != null && product.stock != physicalCount) {
      discrepancies[productId] = {
        'system': product.stock,
        'physical': physicalCount,
        'difference': (physicalCount - product.stock).toInt(),
      };

      await updateStock(
        productId,
        physicalCount,
        reason: 'Stock reconciliation',
      );
    }
  }

  return true;
}
```

---

## Database Schema

### Products Table (SQLite)

```sql
CREATE TABLE products (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  barcode TEXT,
  category TEXT,
  stock INTEGER DEFAULT 0,
  cost REAL DEFAULT 0,
  selling_price REAL,
  min_stock INTEGER DEFAULT 5,
  version INTEGER DEFAULT 0,
  created_at TEXT,
  updated_at TEXT
)
```

### Inventory Batches Table (SQLite)

```sql
CREATE TABLE inventory_batches (
  id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL,
  batch_number TEXT NOT NULL,
  quantity_received INTEGER NOT NULL,
  quantity_remaining INTEGER NOT NULL,
  unit_cost REAL NOT NULL,
  date_received TEXT NOT NULL,
  supplier_id TEXT,
  notes TEXT,
  created_at TEXT,
  updated_at TEXT,
  FOREIGN KEY (product_id) REFERENCES products(id)
)
```

### Stock Movements (Firestore)

```json
{
  "productId": "string",
  "productName": "string",
  "movementType": "stock_in|stock_out|adjustment",
  "quantity": "number",
  "reason": "string",
  "createdAt": "timestamp"
}
```

### Losses (Firestore)

```json
{
  "productId": "string",
  "quantity": "number",
  "totalCost": "number",
  "reason": "expired|damaged|theft|spoilage|other",
  "timestamp": "timestamp",
  "recordedBy": "userId"
}
```

---

## Dependencies

### Key Packages Used:

- `cloud_firestore` - Firebase database
- `sqflite` - Local SQLite database
- `provider` - State management
- `uuid` - Unique ID generation
- `mobile_scanner` - Barcode scanning

---

## Best Practices Implemented

1. **Optimistic Updates**: Update local state immediately, sync to cloud afterward
2. **Error Recovery**: Automatic rollback on failed operations
3. **Conflict Resolution**: Version-based conflict detection
4. **Data Validation**: Input validation in models and providers
5. **Logging**: Comprehensive error logging throughout
6. **Notifications**: Real-time stock alerts
7. **Caching**: Product cache for fast lookups
8. **Debouncing**: Search input debouncing (300ms)

---

## Future Enhancements

- [ ] Multi-location inventory tracking
- [ ] Transfer orders between locations
- [ ] Automated reorder suggestions
- [ ] Inventory forecasting
- [ ] Expiry date tracking per batch
- [ ] Supplier performance analytics
- [ ] Barcode generation for products

---

**End of Documentation**

class AppConstants {
  // Firestore collection names
  static const String productsCollection = 'products';
  static const String customersCollection = 'customers';
  static const String salesCollection = 'sales';
  static const String usersCollection = 'users';
  static const String activitiesCollection = 'activities';
  static const String creditTransactionsCollection = 'credit_transactions';
  static const String saleItemsCollection = 'sale_items';
  static const String stockMovementsCollection = 'stock_movements';
  static const String errorLogsCollection = 'error_logs';
  static const String lossesCollection = 'losses';
  static const String priceHistoryCollection = 'price_history';

  // Operation types
  static const String operationInsert = 'insert';
  static const String operationUpdate = 'update';
  static const String operationDelete = 'delete';
  static const String operationCreateSaleTransaction = 'createSaleTransaction';

  // Tax rate
  static const double taxRate = 0.12;

  // Product Categories
  static const List<String> productCategories = [
    'Snacks (Chichirya)',
    'Drinks (Inumin)',
    'Canned Goods (De Lata)',
    'Noodles & Pasta',
    'Condiments (Pampalasa)',
    'Cleaning Supplies (Panlinis)',
    'Personal Care',
    'Medicine (Gamot)',
    'Cigarettes & Lighters',
    'Others (Iba pa)',
  ];
}

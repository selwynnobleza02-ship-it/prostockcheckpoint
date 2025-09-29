import 'package:prostock/utils/app_constants.dart';

class Product {
  final String? id;
  final String name;
  final String? barcode;
  final double cost;
  final int stock;
  final int minStock;
  final String? category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  Product({
    this.id,
    required this.name,
    this.barcode,
    required this.cost,
    required this.stock,
    this.minStock = 5,
    this.category,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  }) {
    _validateProduct();
  }

  // Price calculation moved to UI level using TaxService
  // This allows dynamic tax rate configuration

  void _validateProduct() {
    if (name.trim().isEmpty) {
      throw ArgumentError('Product name cannot be empty');
    }
    if (name.length > ValidationConstants.maxNameLength) {
      throw ArgumentError('Product name cannot exceed 100 characters');
    }
    if (cost < 0) {
      throw ArgumentError('Product cost cannot be negative');
    }
    if (stock < 0) {
      throw ArgumentError('Product stock cannot be negative');
    }
    if (minStock < 0) {
      throw ArgumentError('Minimum stock cannot be negative');
    }
    if (barcode != null && barcode!.isNotEmpty) {
      if (!_isValidBarcode(barcode!)) {
        throw ArgumentError('Invalid barcode format');
      }
    }
    if (category != null &&
        category!.length > ValidationConstants.maxCategoryLength) {
      throw ArgumentError('Category name cannot exceed 50 characters');
    }
  }

  bool _isValidBarcode(String barcode) {
    // Basic barcode validation - alphanumeric, 8-13 characters
    final barcodeRegex = RegExp(r'^[A-Za-z0-9]{8,13}');
    return barcodeRegex.hasMatch(barcode);
  }

  // Price-dependent methods moved to UI level using TaxService
  // This allows dynamic tax rate configuration

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'cost': cost,
      'stock': stock,
      'min_stock': minStock,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'version': version,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id']?.toString(),
      name: map['name'],
      barcode: map['barcode'],
      cost: map['cost'].toDouble(),
      stock: map['stock'],
      minStock: map['min_stock'] ?? 5,
      category: map['category'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      version: map['version'] ?? 1,
    );
  }

  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    double? cost,
    int? stock,
    int? minStock,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  bool get isLowStock => stock <= minStock;
}

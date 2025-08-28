import 'package:prostock/utils/app_constants.dart';

class Customer {
  final String? id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? imageUrl;
  final String? localImagePath;
  final double utangBalance;
  final DateTime createdAt;
  final DateTime updatedAt;

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.imageUrl,
    this.localImagePath,
    this.utangBalance = 0,
    required this.createdAt,
    required this.updatedAt,
  }) {
    _validateCustomer();
  }

  void _validateCustomer() {
    if (name.trim().isEmpty) {
      throw ArgumentError('Customer name cannot be empty');
    }
    if (name.length > ValidationConstants.maxNameLength) {
      throw ArgumentError('Customer name cannot exceed 100 characters');
    }
    if (phone != null && phone!.isNotEmpty && !_isValidPhoneNumber(phone!)) {
      throw ArgumentError('Invalid phone number format');
    }
    if (email != null && email!.isNotEmpty && !_isValidEmail(email!)) {
      throw ArgumentError('Invalid email format');
    }
    if (address != null && address!.length > ValidationConstants.maxDescriptionLength) {
      throw ArgumentError('Address cannot exceed 200 characters');
    }
    if (utangBalance < 0) {
      throw ArgumentError('Utang balance cannot be negative');
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    );
    return emailRegex.hasMatch(email);
  }

  bool _isValidPhoneNumber(String phone) {
    // Philippine phone number format validation
    final phoneRegex = RegExp(r'^(\+63|0)[0-9]{10}');
    return phoneRegex.hasMatch(phone.replaceAll(RegExp(r'[\s\-$]'), ''));
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'imageUrl': imageUrl,
      'localImagePath': localImagePath,
      'utang_balance': utangBalance,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id']?.toString(),
      name: map['name'] ?? '',
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      address: map['address']?.toString(),
      imageUrl: map['imageUrl']?.toString(),
      localImagePath: map['localImagePath']?.toString(),
      utangBalance: (map['utang_balance'] ?? 0).toDouble(),
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  bool get hasUtang => utangBalance > 0;
}

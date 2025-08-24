import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/utils/error_logger.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AddCustomerDialog extends StatefulWidget {
  const AddCustomerDialog({super.key});

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _creditLimitController = TextEditingController(text: '0');

  bool _isLoading = false;
  File? _imageFile;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e, s) {
      ErrorLogger.logError('Error picking image', error: e, stackTrace: s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Customer'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _showImageSourceActionSheet,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _imageFile != null
                        ? Image.file(_imageFile!, fit: BoxFit.cover)
                        : const Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 16),
                // Customer Name
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter customer name';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone Number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                    helperText: 'Optional - e.g. 09123456789',
                    prefixText: '+63 ',
                  ),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      // Basic Philippine mobile number validation
                      final cleanNumber = value.trim().replaceAll(
                        RegExp(r'[^\d]'),
                        '',
                      );
                      if (cleanNumber.length < 10 || cleanNumber.length > 11) {
                        return 'Enter a valid phone number';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                    helperText: 'Optional',
                  ),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}',
                      ).hasMatch(value.trim())) {
                        return 'Enter a valid email address';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Address
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                    helperText: 'Optional',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Credit Limit
                TextFormField(
                  controller: _creditLimitController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Credit Limit',
                    border: OutlineInputBorder(),
                    prefixText: '₱ ', // Philippine Peso symbol
                    prefixIcon: Icon(Icons.credit_card),
                    helperText: 'Maximum credit amount allowed',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter credit limit (0 for no credit)';
                    }
                    final creditLimit = double.tryParse(value.trim());
                    if (creditLimit == null || creditLimit < 0) {
                      return 'Enter valid credit limit';
                    }
                    if (creditLimit > 1000000) {
                      return 'Credit limit seems too high';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Credit Info Card
                _buildCreditInfoCard(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveCustomer,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add Customer'),
        ),
      ],
    );
  }

  Widget _buildCreditInfoCard() {
    final creditLimit =
        double.tryParse(_creditLimitController.text.trim()) ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: creditLimit > 0 ? Colors.orange.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: creditLimit > 0
              ? Colors.orange.shade200
              : Colors.blue.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            creditLimit > 0 ? Icons.warning : Icons.info,
            color: creditLimit > 0 ? Colors.orange : Colors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creditLimit > 0
                      ? 'Credit Customer (₱${creditLimit.toStringAsFixed(2)} limit)'
                      : 'Cash-Only Customer',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  creditLimit > 0
                      ? 'This customer can purchase on credit up to the specified limit.'
                      : 'This customer can only make cash purchases.',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('customer_images')
          .child('${DateTime.now().toIso8601String()}.jpg');
      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() => {});
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e, s) {
      String message = 'An error occurred during image upload.';
      if (e.code == 'object-not-found') {
        message = 'The image could not be found.';
      } else if (e.code == 'unauthorized') {
        message = 'You do not have permission to upload images.';
      } else if (e.code == 'canceled') {
        message = 'Image upload was canceled.';
      }
      ErrorLogger.logError('Error uploading image', error: e, stackTrace: s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    } catch (e, s) {
      ErrorLogger.logError('Error uploading image', error: e, stackTrace: s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unknown error occurred during image upload.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await _uploadImage(_imageFile!);
        if (imageUrl == null) {
          // Handle upload failure
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Safely parse credit limit
      final creditLimit = double.tryParse(_creditLimitController.text.trim());
      if (creditLimit == null) {
        throw const FormatException('Invalid credit limit format');
      }

      // Clean and prepare optional fields
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();
      final address = _addressController.text.trim();

      final customer = Customer(
        name: _nameController.text.trim(),
        phone: phone.isEmpty ? null : phone,
        email: email.isEmpty ? null : email,
        address: address.isEmpty ? null : address,
        imageUrl: imageUrl,
        creditLimit: creditLimit,
        currentBalance: 0.0, // New customers start with zero balance
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Call addCustomer - assumes it returns void and throws on error
      await Provider.of<CustomerProvider>(
        context,
        listen: false,
      ).addCustomer(customer);

      // If we reach here, the customer was added successfully
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Customer "${customer.name}" added successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to customer screen
                // You can add navigation logic here
              },
            ),
          ),
        );
      }
    } on FormatException catch (e, s) {
      ErrorLogger.logError(
        'Invalid number format in add customer dialog',
        error: e,
        stackTrace: s,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid number format. Please check credit limit.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } on ArgumentError catch (e, s) {
      ErrorLogger.logError(
        'Invalid argument in add customer dialog',
        error: e,
        stackTrace: s,
      );
      // Catch ArgumentError from model validation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Input Error: ${e.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e, s) {
      ErrorLogger.logError('Error adding customer', error: e, stackTrace: s);
      if (mounted) {
        String errorMessage = 'Error adding customer';

        // Provide more specific error messages based on common issues
        if (e.toString().contains('already exists')) {
          errorMessage =
              'Customer with this name, phone, or email already exists.';
        } else if (e.toString().contains('network') ||
            e.toString().contains('connection')) {
          errorMessage = 'Network error. Please check your connection.';
        } else {
          errorMessage = 'An unexpected error occurred: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _saveCustomer,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

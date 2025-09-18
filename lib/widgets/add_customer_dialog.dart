import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/services/cloudinary_service.dart';
import 'package:prostock/services/offline_manager.dart';
import 'package:prostock/utils/error_logger.dart';
import 'package:prostock/widgets/confirmation_dialog.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AddCustomerDialog extends StatefulWidget {
  final Customer? customer;
  final OfflineManager offlineManager;
  const AddCustomerDialog({super.key, this.customer, required this.offlineManager});

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _creditLimitController = TextEditingController();

  bool _isLoading = false;
  File? _imageFile;
  String? _networkImageUrl;

  bool get _isEditMode => widget.customer != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final customer = widget.customer!;
      _nameController.text = customer.name;

      String? displayPhone = customer.phone;
      if (displayPhone != null && displayPhone.isNotEmpty) {
        displayPhone = displayPhone.replaceAll(RegExp(r'[\s\-]'), '');
        if (displayPhone.startsWith('+63')) {
          displayPhone = displayPhone.substring(3);
        } else if (displayPhone.startsWith('63')) {
          displayPhone = displayPhone.substring(2);
        } else if (displayPhone.startsWith('0')) {
          displayPhone = displayPhone.substring(1);
        }
      }
      _phoneController.text = displayPhone ?? '';

      _emailController.text = customer.email ?? '';
      _addressController.text = customer.address ?? '';
      _creditLimitController.text = customer.creditLimit.toString();
      _networkImageUrl = customer.imageUrl;
      if (customer.localImagePath != null) {
        _imageFile = File(customer.localImagePath!);
      }
    }
  }

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
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = p.basename(pickedFile.path);
        final savedImage = await File(
          pickedFile.path,
        ).copy('${appDir.path}/$fileName');
        setState(() {
          _imageFile = savedImage;
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

  Future<String?> _uploadImage(File imageFile) async {
    try {
      return await CloudinaryService.instance.uploadImage(imageFile);
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

    final confirmed = await showConfirmationDialog(
      context: context,
      title: _isEditMode ? 'Update Customer' : 'Add Customer',
      content: _isEditMode
          ? 'Are you sure you want to save changes to ${widget.customer!.name}?'
          : 'Are you sure you want to add this customer?',
      confirmText: _isEditMode ? 'Save' : 'Add',
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl = _networkImageUrl;
      String? localImagePath = _imageFile?.path;

      if (_imageFile != null && widget.offlineManager.isOnline) {
        imageUrl = await _uploadImage(_imageFile!);
        if (imageUrl == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      String? phone = _phoneController.text.trim();
      final email = _emailController.text.trim();
      final address = _addressController.text.trim();
      final creditLimit =
          double.tryParse(_creditLimitController.text.trim()) ?? 0.0;

      if (phone.isNotEmpty) {
        phone = phone.replaceAll(RegExp(r'[\s\-\+]'), '');
        if (phone.startsWith('63')) {
          phone = phone.substring(2);
        }
        if (phone.startsWith('0')) {
          phone = phone.substring(1);
        }
        phone = '+63$phone';
      } else {
        phone = null;
      }

      final customerData = Customer(
        id: _isEditMode ? widget.customer!.id : null,
        name: _nameController.text.trim(),
        phone: phone,
        email: email.isEmpty ? null : email,
        address: address.isEmpty ? null : address,
        imageUrl: imageUrl,
        localImagePath: localImagePath,
        balance: _isEditMode ? widget.customer!.balance : 0.0,
        creditLimit: creditLimit,
        createdAt: _isEditMode ? widget.customer!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (!mounted) return;

      final provider = Provider.of<CustomerProvider>(context, listen: false);
      Customer? result;
      if (_isEditMode) {
        result = await provider.updateCustomer(customerData);
      } else {
        result = await provider.addCustomer(customerData);
      }

      if (result != null) {
        if (imageUrl != null) {
          ErrorLogger.logError(
            'INFO: Image uploaded for customer ${result.id}',
            context: 'AddCustomerDialog._saveCustomer',
            metadata: {'imageUrl': imageUrl},
          );
        }
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Customer "${result.name}" ${_isEditMode ? 'updated' : 'added'} successfully!',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to ${_isEditMode ? 'update' : 'add'} customer. ${provider.error ?? ''}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
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
      ErrorLogger.logError('Error saving customer', error: e, stackTrace: s);
      if (mounted) {
        String errorMessage = 'Error saving customer';

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditMode ? 'Edit Customer' : 'Add New Customer'),
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
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(_imageFile!, fit: BoxFit.cover),
                          )
                        : widget.customer?.localImagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(widget.customer!.localImagePath!),
                              fit: BoxFit.cover,
                            ),
                          )
                        : _networkImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _networkImageUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.add_a_photo,
                            size: 50,
                            color: Colors.grey,
                          ),
                  ),
                ),
                const SizedBox(height: 16),

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

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                    helperText: 'e.g. 9123456789',
                    prefixText: '+63 ',
                  ),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final cleanNumber = value.trim();
                      if (!RegExp(r'^[9][0-9]{9}').hasMatch(cleanNumber)) {
                        return 'Enter a valid 10-digit number starting with 9';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

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

                TextFormField(
                  controller: _creditLimitController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Credit Limit',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      if (double.tryParse(value.trim()) == null) {
                        return 'Please enter a valid number';
                      }
                    }
                    return null;
                  },
                ),
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
              : Text(_isEditMode ? 'Save Changes' : 'Add Customer'),
        ),
      ],
    );
  }
}

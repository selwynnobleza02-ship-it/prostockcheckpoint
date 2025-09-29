import 'package:flutter/material.dart';
import 'package:prostock/services/tax_service.dart';
import 'package:prostock/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'tax_history_dialog.dart';

// Deprecated: Use Markup Rules screen instead. This screen is no longer used.
class TaxSettingsScreen extends StatefulWidget {
  const TaxSettingsScreen({super.key});

  @override
  State<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends State<TaxSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tuboAmountController = TextEditingController();

  double _tuboAmount = 2.0; // Default ₱2
  bool _tuboInclusive = true;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTaxSettings();
  }

  @override
  void dispose() {
    _tuboAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadTaxSettings() async {
    setState(() => _isLoading = true);

    try {
      // Load tubo settings using TaxService
      _tuboAmount = await TaxService.getTuboAmount();
      _tuboAmountController.text = _tuboAmount.toStringAsFixed(2);

      _tuboInclusive = await TaxService.isTuboInclusive();

      setState(() {});
    } catch (e) {
      setState(() {
        _error = 'Failed to load tubo settings: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTaxSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Save tubo settings using TaxService with history tracking
      final amountSuccess = await TaxService.setTuboAmount(
        _tuboAmount,
        changedByUserId: currentUser.id ?? 'unknown',
        changedByUserName: currentUser.username,
        source: 'settings_screen',
      );

      final inclusiveSuccess = await TaxService.setTuboInclusive(
        _tuboInclusive,
        changedByUserId: currentUser.id ?? 'unknown',
        changedByUserName: currentUser.username,
        source: 'settings_screen',
      );

      if (amountSuccess && inclusiveSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tubo settings saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to save one or more settings');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to save tubo settings: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateTuboAmount(String value) {
    final amount = double.tryParse(value);
    if (amount != null && amount >= 0) {
      setState(() {
        _tuboAmount = amount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Markup Settings'),
        actions: [
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const TaxHistoryDialog(),
              );
            },
            icon: const Icon(Icons.history),
            tooltip: 'View History',
          ),
          if (!_isLoading)
            TextButton(
              onPressed: _saveTaxSettings,
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading && _tuboAmountController.text.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tubo Amount Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.attach_money, color: Colors.blue),
                                SizedBox(width: 8),
                                Text(
                                  'Tubo Configuration',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _tuboAmountController,
                              decoration: InputDecoration(
                                labelText: 'Tubo Amount (₱)',
                                border: const OutlineInputBorder(),
                                suffixText: '₱',
                                helperText: 'Enter fixed tubo amount in pesos',
                              ),
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              onChanged: _updateTuboAmount,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Tubo amount is required';
                                }
                                final amount = double.tryParse(value);
                                if (amount == null) {
                                  return 'Please enter a valid number';
                                }
                                if (amount < 0) {
                                  return 'Tubo amount must be 0 or greater';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Current tubo: ₱${_tuboAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Pricing Method Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.calculate, color: Colors.green),
                                SizedBox(width: 8),
                                Text(
                                  'Tubo Method',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            RadioGroup<bool>(
                              groupValue: _tuboInclusive,
                              onChanged: (value) {
                                setState(() {
                                  _tuboInclusive = value ?? true;
                                });
                              },
                              child: Column(
                                children: [
                                  RadioListTile<bool>(
                                    title: const Text('Tubo Inclusive'),
                                    subtitle: const Text(
                                      'Selling price equals cost (tubo included)',
                                    ),
                                    value: true,
                                  ),
                                  RadioListTile<bool>(
                                    title: const Text('Tubo Added on Top'),
                                    subtitle: const Text(
                                      'Tubo is added to the cost',
                                    ),
                                    value: false,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _tuboInclusive
                                            ? Icons.check_circle
                                            : Icons.add_circle,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _tuboInclusive
                                            ? 'Tubo Inclusive'
                                            : 'Tubo Added on Top',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _tuboInclusive
                                        ? 'Example: Cost ₱100 → Selling ₱100 (tubo included)'
                                        : 'Example: Cost ₱100 → Selling ₱${(100 + _tuboAmount).toStringAsFixed(0)} (₱100 + ₱${_tuboAmount.toStringAsFixed(0)} tubo)',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tax Information Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.orange),
                                SizedBox(width: 8),
                                Text(
                                  'Tubo Information',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildTaxInfoRow(
                              'Current Tubo',
                              '₱${_tuboAmount.toStringAsFixed(2)}',
                            ),
                            _buildTaxInfoRow(
                              'Tubo Method',
                              _tuboInclusive
                                  ? 'Tubo Inclusive'
                                  : 'Tubo Added on Top',
                            ),
                            _buildTaxInfoRow(
                              'Tubo Application',
                              _tuboInclusive
                                  ? 'Included in price'
                                  : 'Added on top of cost',
                            ),
                            _buildTaxInfoRow(
                              'Receipt Display',
                              'Profit shown via tubo settings',
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveTaxSettings,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save Markup Settings',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTaxInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

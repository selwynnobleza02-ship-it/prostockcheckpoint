import 'package:flutter/material.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/widgets/manage_balance_dialog.dart';

class DialogHelpers {
  static Future<bool?> showManageBalanceDialog({
    required BuildContext context,
    required Customer customer,
    required Function(String customerId, double amount) onUpdateBalance,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ManageBalanceDialog(
        customer: customer,
        onUpdateBalance: onUpdateBalance,
      ),
    );
  }
}

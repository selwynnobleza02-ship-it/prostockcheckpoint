import 'package:flutter/material.dart';
import 'package:prostock/models/product.dart';
import 'package:prostock/models/sale_item.dart';

class TopSellingProductsList extends StatelessWidget {
  final List<Product> topProducts;
  final List<SaleItem> saleItems;

  const TopSellingProductsList({
    super.key,
    required this.topProducts,
    required this.saleItems,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Selling Products',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: topProducts.length,
          itemBuilder: (context, index) {
            final product = topProducts[index];
            final quantitySold = _getQuantitySold(product.id!);
            return ListTile(
              leading: CircleAvatar(
                child: Text((index + 1).toString()),
              ),
              title: Text(product.name),
              trailing: Text('Sold: $quantitySold'),
            );
          },
        ),
      ],
    );
  }

  int _getQuantitySold(String productId) {
    return saleItems
        .where((item) => item.productId == productId)
        .fold(0, (sum, item) => sum + item.quantity);
  }
}

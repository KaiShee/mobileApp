import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AvailableDiscountsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Available Vouchers'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('discounts')
            .where('isActive', isEqualTo: true)
            .where('expiry', isGreaterThan: Timestamp.now())
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('Voucher load error: \\${snapshot.error}');
            return Center(child: Text('Error loading vouchers.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final discounts = snapshot.data?.docs ?? [];
          if (discounts.isEmpty) {
            return Center(child: Text('No vouchers available.'));
          }
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: discounts.length,
            itemBuilder: (context, index) {
              final discount = discounts[index].data() as Map<String, dynamic>;
              print('Discount expiry type: \\${discount['expiry']?.runtimeType}');
              final expiryRaw = discount['expiry'];
              if (expiryRaw == null || expiryRaw is! Timestamp) {
                // Skip this document if expiry is missing or not a Timestamp
                return SizedBox.shrink();
              }
              final expiryDate = expiryRaw.toDate();
              return Card(
                margin: EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Row(
                    children: [
                      Text(
                        discount['code'] ?? '',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${discount['rate']}% OFF",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 4),
                      Text("Expires: ${expiryDate.toLocal().toString().split(' ')[0]}"),
                      if (discount['description']?.isNotEmpty ?? false)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            discount['description'],
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
} 
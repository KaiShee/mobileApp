import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DiscountManagement extends StatefulWidget {
  @override
  _DiscountManagementState createState() => _DiscountManagementState();
}

class _DiscountManagementState extends State<DiscountManagement> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _limitController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _expiryDate;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _rateController.dispose();
    _limitController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Format date as a string without using intl package
  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _expiryDate) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  void _clearForm() {
    _codeController.clear();
    _rateController.clear();
    _limitController.clear();
    _descriptionController.clear();
    setState(() {
      _expiryDate = null;
    });
  }

  Future<void> _createDiscount() async {
    if (_codeController.text.isEmpty ||
        _rateController.text.isEmpty ||
        _limitController.text.isEmpty ||
        _expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    // Validate discount rate and usage limit
    final rate = double.tryParse(_rateController.text);
    final limit = int.tryParse(_limitController.text);

    if (rate == null || rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Discount rate must be greater than 0')),
      );
      return;
    }

    if (limit == null || limit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usage limit must be greater than 0')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('discounts').add({
        'code': _codeController.text.toUpperCase(),
        'description': _descriptionController.text,
        'rate': double.parse(_rateController.text),
        'limit': int.parse(_limitController.text),
        'used': 0,
        'expiry': Timestamp.fromDate(_expiryDate!),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _clearForm();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Discount created successfully')),
      );
      _tabController.animateTo(0); // Switch to Active Discounts tab
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating discount: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Discount Management",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue[800],
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Active Discounts", icon: Icon(Icons.local_offer)),
            Tab(text: "Expired Discounts", icon: Icon(Icons.history)),
            Tab(text: "Create New", icon: Icon(Icons.add_circle_outline)),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDiscountsList(isActive: true),
          _buildDiscountsList(isActive: false),
          _buildCreateDiscountForm(),
        ],
      ),
    );
  }
  
  Widget _buildDiscountsList({required bool isActive}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('discounts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (snapshot.error.toString().contains('failed-precondition')) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded, 
                         size: 48, 
                         color: Colors.orange),
                    SizedBox(height: 16),
                    Text(
                      'Setting up the discount system...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please create your first discount to initialize the system.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: Text('Error loading discounts. Please try again later.')
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final discounts = snapshot.data?.docs ?? [];
        
        // Filter discounts based on tab
        final filteredDiscounts = discounts.where((doc) {
          final discount = doc.data() as Map<String, dynamic>;
          final expiryDate = (discount['expiry'] as Timestamp).toDate();
          final isExpired = expiryDate.isBefore(DateTime.now());
          final isActiveDiscount = (discount['isActive'] ?? true) == true;
          if (isActive) {
            // Show only active and not expired
            return isActiveDiscount && !isExpired;
          } else {
            // Show only expired (regardless of isActive)
            return isExpired;
          }
        }).toList();

        if (filteredDiscounts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_offer_outlined, 
                     size: 48, 
                     color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  isActive ? 'No Active Discounts' : 'No Expired Discounts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  isActive ? 'Create your first discount code' : 'No expired discounts yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: EdgeInsets.all(16.0),
          itemCount: filteredDiscounts.length,
          itemBuilder: (context, index) {
            final discount = filteredDiscounts[index].data() as Map<String, dynamic>;
            final expiryDate = (discount['expiry'] as Timestamp).toDate();
            final isExpired = expiryDate.isBefore(DateTime.now());
            final isExpiringSoon = !isExpired && expiryDate.difference(DateTime.now()).inDays < 30;

            return Card(
              elevation: 2,
              margin: EdgeInsets.only(bottom: 12.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Row(
                      children: [
                        Text(
                          discount['code'],
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isExpired ? Colors.grey : Theme.of(context).primaryColor,
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
                        Row(
                          children: [
                            Icon(Icons.event, size: 16, color: isExpired ? Colors.red : Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              "Expires: ${_formatDate(expiryDate)}",
                              style: TextStyle(
                                color: isExpired ? Colors.red : null,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.person, size: 16, color: Colors.grey),
                            SizedBox(width: 4),
                            Text("Used: ${discount['used']}/${discount['limit']}"),
                          ],
                        ),
                        if (discount['description']?.isNotEmpty ?? false) ...[
                          SizedBox(height: 2),
                          Text(
                            discount['description'],
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                    trailing: isActive
                        ? PopupMenuButton(
                            icon: Icon(Icons.more_vert),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text("Delete"),
                                  ],
                                ),
                                value: 'delete',
                              ),
                            ],
                            onSelected: (value) async {
                              if (value == 'delete') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Confirm Delete'),
                                    content: Text('Are you sure you want to delete this active discount?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  try {
                                    await _firestore
                                        .collection('discounts')
                                        .doc(filteredDiscounts[index].id)
                                        .update({'isActive': false});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Discount deleted successfully')),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error deleting discount: $e')),
                                    );
                                  }
                                }
                              }
                            },
                          )
                        : IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Delete Discount',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Confirm Delete'),
                                  content: Text('Are you sure you want to permanently delete this expired discount?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                try {
                                  await _firestore
                                      .collection('discounts')
                                      .doc(filteredDiscounts[index].id)
                                      .delete();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Expired discount deleted successfully')),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error deleting expired discount: $e')),
                                  );
                                }
                              }
                            },
                          ),
                  ),
                  if (isActive) LinearProgressIndicator(
                    value: discount['used'] / discount['limit'],
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      discount['used'] / discount['limit'] > 0.8 ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCreateDiscountForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Create New Discount",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(height: 20),
          TextFormField(
            controller: _codeController,
            decoration: InputDecoration(
              labelText: "Discount Code*",
              prefixIcon: Icon(Icons.code),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              hintText: "e.g., SUMMER25",
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _rateController,
                  decoration: InputDecoration(
                    labelText: "Discount Rate (%)* ",
                    prefixIcon: Icon(Icons.percent),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _limitController,
                  decoration: InputDecoration(
                    labelText: "Usage Limit*",
                    prefixIcon: Icon(Icons.people),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          InkWell(
            onTap: () => _selectDate(context),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: "Expiry Date*",
                prefixIcon: Icon(Icons.calendar_today),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _expiryDate == null
                        ? "Select Date"
                        : _formatDate(_expiryDate!),
                  ),
                  Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: "Description (Optional)",
              prefixIcon: Icon(Icons.description),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            maxLines: 3,
          ),
          SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createDiscount,
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                      "CREATE DISCOUNT",
                      style: TextStyle(fontSize: 16),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
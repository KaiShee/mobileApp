import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/booking_model.dart';
import 'services/booking_service.dart';

class PaymentPage extends StatefulWidget {
  final List<Map<String, dynamic>> selectedRooms;
  final String hotelName;
  final double totalPrice;
  final String? appliedDiscountCode;
  final double discountAmount;

  const PaymentPage({
    Key? key,
    required this.selectedRooms,
    required this.hotelName,
    required this.totalPrice,
    this.appliedDiscountCode,
    this.discountAmount = 0.0,
  }) : super(key: key);

  @override
  _PaymentPageState createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _selectedPaymentMethod = "Credit Card";
  final _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Light mode colors
  static const Color lightBackgroundColor = Color(0xFFF5F6FA);
  static const Color lightSurfaceColor = Colors.white;
  static const Color lightTextColor = Color(0xFF1F2937);
  static const Color lightSubtitleColor = Color(0xFF6B7280);
  
  // Dark mode colors
  static const Color darkBackgroundColor = Color(0xFF121212);
  static const Color darkSurfaceColor = Color(0xFF1E1E1E);
  static const Color darkCardColor = Color(0xFF2C2C2C);
  static const Color darkTextColor = Color(0xFFE1E1E1);
  static const Color darkSubtitleColor = Color(0xFFB0B0B0);

  // Get theme-aware colors
  Color getBackgroundColor(bool isDark) => isDark ? darkBackgroundColor : lightBackgroundColor;
  Color getSurfaceColor(bool isDark) => isDark ? darkSurfaceColor : lightSurfaceColor;
  Color getCardColor(bool isDark) => isDark ? darkCardColor : lightSurfaceColor;
  Color getTextColor(bool isDark) => isDark ? darkTextColor : lightTextColor;
  Color getSubtitleColor(bool isDark) => isDark ? darkSubtitleColor : lightSubtitleColor;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveBookingDetails(String paymentId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Create bookings for each selected room
      for (var room in widget.selectedRooms) {
        // Validate required fields
        if (room['hotelId'] == null || room['hotelId'].isEmpty ||
            room['roomTypeId'] == null || room['roomTypeId'].isEmpty) {
          throw Exception('Missing hotel or room information');
        }

        if (room['checkInDate'] == null || room['checkOutDate'] == null) {
          throw Exception('Missing check-in or check-out dates');
        }

        final bookingData = {
          'userId': user.uid,
          'hotelId': room['hotelId'],
          'roomTypeId': room['roomTypeId'],
          'quantity': room['selected'],
          'numberOfNights': room['numberOfNights'],
          'checkInDate': room['checkInDate'],
          'checkOutDate': room['checkOutDate'],
          'totalAmount': room['price'] * room['selected'],
          'discountAmount': widget.discountAmount / widget.selectedRooms.length, // Split discount equally
          'status': 'confirmed',
          'isPaid': true,
          'paymentMethod': _selectedPaymentMethod,
          'paymentId': paymentId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Create the booking in Firestore
        final docRef = await _firestore.collection('bookings').add(bookingData);
        
        // Update the document with its ID
        await docRef.update({'id': docRef.id});
      }
    } catch (e) {
      throw Exception('Failed to save booking: $e');
    }
  }

  void _processPayment() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isProcessing = true;
      });

      // Simulate payment processing
      Timer(const Duration(seconds: 2), () async {
        try {
          final paymentId = 'PAY-${DateTime.now().millisecondsSinceEpoch}';
          await _saveBookingDetails(paymentId);

          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => _SuccessPage(
                hotelName: widget.hotelName,
                totalPrice: widget.totalPrice,
              ),
            ),
            (route) => false,
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving booking: $e')),
          );
          setState(() {
            _isProcessing = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: getBackgroundColor(isDark),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
          "Payment",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: _isProcessing
          ? _buildProcessingView()
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Booking Summary Card
              _buildBookingSummaryCard(),

              const SizedBox(height: 24),

              // Payment Method Selection
              _buildPaymentMethodSelection(),

              const SizedBox(height: 24),

              // Payment Form (Only show for Credit Card)
              if (_selectedPaymentMethod == "Credit Card")
                _buildCreditCardForm(),

              const SizedBox(height: 32),

              // Payment Button
              _buildPaymentButton(),

              const SizedBox(height: 24),

              // Security Notice
              _buildSecurityNotice(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingSummaryCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 4,
      color: getCardColor(isDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.hotel,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.hotelName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: getTextColor(isDark),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Divider(
              height: 24,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            ),
            Text(
              "Booking Summary",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: getTextColor(isDark),
              ),
            ),
            const SizedBox(height: 16),
            ...widget.selectedRooms.map((room) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "${room["name"]} x ${room["selected"]}",
                      style: TextStyle(
                        fontSize: 15,
                        color: getTextColor(isDark),
                      ),
                    ),
                  ),
                  Text(
                    "RM${(room["price"] * room["selected"]).toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: getTextColor(isDark),
                    ),
                  ),
                ],
              ),
            )),
            Divider(
              height: 24,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            ),
            // Subtotal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Subtotal",
                  style: TextStyle(
                    fontSize: 15,
                    color: getTextColor(isDark),
                  ),
                ),
                Text(
                  "RM${(widget.totalPrice + widget.discountAmount).toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: getTextColor(isDark),
                  ),
                ),
              ],
            ),
            if (widget.appliedDiscountCode != null && widget.discountAmount > 0) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Discount (${widget.appliedDiscountCode})",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.green[400],
                    ),
                  ),
                  Text(
                    "-RM${widget.discountAmount.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.green[400],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Amount",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: getTextColor(isDark),
                  ),
                ),
                Text(
                  "RM${widget.totalPrice.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 4,
      color: getCardColor(isDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Payment Method",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: getTextColor(isDark),
              ),
            ),
            const SizedBox(height: 16),
            _buildPaymentOption(
              value: "Credit Card",
              title: "Credit Card",
              subtitle: "Visa, Mastercard, Amex",
              icon: Icons.credit_card,
            ),
            Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            _buildPaymentOption(
              value: "PayPal",
              title: "PayPal",
              subtitle: "Pay with your PayPal account",
              icon: Icons.account_balance_wallet,
            ),
            Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            _buildPaymentOption(
              value: "FPX",
              title: "FPX",
              subtitle: "Online Banking",
              icon: Icons.account_balance,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return RadioListTile<String>(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: getTextColor(isDark),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: getSubtitleColor(isDark),
        ),
      ),
      value: value,
      groupValue: _selectedPaymentMethod,
      secondary: Icon(
        icon,
        color: Theme.of(context).primaryColor,
      ),
      activeColor: Theme.of(context).primaryColor,
      onChanged: (newValue) {
        setState(() {
          _selectedPaymentMethod = newValue!;
        });
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
    );
  }

  Widget _buildCreditCardForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Form(
      key: _formKey,
      child: Card(
        elevation: 4,
        color: getCardColor(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Card Details",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: getTextColor(isDark),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: getTextColor(isDark)),
                decoration: _inputDecoration(
                  label: "Cardholder Name",
                  hint: "Enter cardholder name",
                  icon: Icons.person_outline,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter cardholder name";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cardNumberController,
                style: TextStyle(color: getTextColor(isDark)),
                decoration: _inputDecoration(
                  label: "Card Number",
                  hint: "XXXX XXXX XXXX XXXX",
                  icon: Icons.credit_card,
                ),
                keyboardType: TextInputType.number,
                maxLength: 19,
                validator: (value) {
                  final cleaned = value?.replaceAll(' ', '') ?? '';
                  if (cleaned.length != 16 || int.tryParse(cleaned) == null) {
                    return "Card number must be 16 digits";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryDateController,
                      style: TextStyle(color: getTextColor(isDark)),
                      decoration: _inputDecoration(
                        label: "Expiry Date",
                        hint: "MM/YY",
                        icon: Icons.date_range,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Required";
                        }
                        final exp = RegExp(r'^(0[1-9]|1[0-2])\/([0-9]{2})$');
                        if (!exp.hasMatch(value)) {
                          return "Invalid format (MM/YY)";
                        }
                        final parts = value.split('/');
                        final month = int.tryParse(parts[0]) ?? 0;
                        final year = int.tryParse(parts[1]) ?? 0;
                        final now = DateTime.now();
                        final fourDigitYear = 2000 + year;
                        final lastDate = DateTime(fourDigitYear, month + 1, 0);
                        if (lastDate.isBefore(DateTime(now.year, now.month, 1))) {
                          return "Card expired";
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cvvController,
                      style: TextStyle(color: getTextColor(isDark)),
                      decoration: _inputDecoration(
                        label: "CVV",
                        hint: "XXX",
                        icon: Icons.security,
                      ),
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                      validator: (value) {
                        if (value == null || value.length != 3 || int.tryParse(value) == null) {
                          return "CVV must be 3 digits";
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: getSubtitleColor(isDark)),
      hintText: hint,
      hintStyle: TextStyle(color: getSubtitleColor(isDark).withOpacity(0.7)),
      prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: Theme.of(context).primaryColor,
        ),
      ),
      filled: true,
      fillColor: isDark ? darkCardColor : Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }

  Widget _buildPaymentButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          "Complete Payment",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityNotice() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.security,
            size: 16,
            color: getSubtitleColor(isDark),
          ),
          const SizedBox(width: 8),
          Text(
            "Your payment information is secure",
            style: TextStyle(
              color: getSubtitleColor(isDark),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            "Processing Payment...",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: getTextColor(isDark),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Please do not close this page",
            style: TextStyle(
              color: getSubtitleColor(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessPage extends StatelessWidget {
  final String hotelName;
  final double totalPrice;

  const _SuccessPage({
    required this.hotelName,
    required this.totalPrice,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? const Color(0xFFE1E1E1) : Colors.black;
    final subtitleColor = isDark ? const Color(0xFFB0B0B0) : Colors.grey;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: isDark ? Colors.green.shade900 : Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 60,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "Payment Successful!",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Your booking at $hotelName has been confirmed",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Amount Paid: RM${totalPrice.toStringAsFixed(2)}",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.home, color: Colors.white),
                  label: const Text(
                    "Return to Home",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
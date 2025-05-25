import 'package:flutter/material.dart';
import 'payment.dart';
import 'services/discount_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BookingPage extends StatefulWidget {
  final String hotelName;
  final List<Map<String, dynamic>> selectedRooms;

  const BookingPage({Key? key, required this.hotelName, required this.selectedRooms}) : super(key: key);

  @override
  _BookingPageState createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final TextEditingController _discountController = TextEditingController();
  final DiscountService _discountService = DiscountService();
  final ScrollController _scrollController = ScrollController();
  
  String? appliedDiscountCode;
  double discountAmount = 0.0;
  bool isValidatingCode = false;
  String? errorMessage;

  // Add date variables
  DateTime checkInDate = DateTime.now();
  DateTime checkOutDate = DateTime.now().add(const Duration(days: 1));

  // Light mode colors
  static const Color primaryColor = Color(0xFF3F51B5);
  static const Color accentColor = Color(0xFF536DFE);
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
  
  // Success and error colors remain consistent
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);

  // Get theme-aware colors
  Color getBackgroundColor(bool isDark) => isDark ? darkBackgroundColor : lightBackgroundColor;
  Color getSurfaceColor(bool isDark) => isDark ? darkSurfaceColor : lightSurfaceColor;
  Color getCardColor(bool isDark) => isDark ? darkCardColor : lightSurfaceColor;
  Color getTextColor(bool isDark) => isDark ? darkTextColor : lightTextColor;
  Color getSubtitleColor(bool isDark) => isDark ? darkSubtitleColor : lightSubtitleColor;
  Color getAccentColor(bool isDark) => isDark ? accentColor : primaryColor;

  @override
  void dispose() {
    _discountController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _selectDates() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: checkInDate, end: checkOutDate),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark 
                ? ColorScheme.dark(
                    primary: accentColor,
                    onPrimary: Colors.white,
                    surface: darkSurfaceColor,
                    onSurface: darkTextColor,
                    background: darkBackgroundColor,
                  )
                : ColorScheme.light(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: lightSurfaceColor,
                    onSurface: lightTextColor,
                    background: lightBackgroundColor,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        checkInDate = picked.start;
        checkOutDate = picked.end;
      });
    }
  }

  Future<void> applyDiscountCode() async {
    final code = _discountController.text.trim();
    if (code.isEmpty) {
      setState(() {
        errorMessage = 'Please enter a discount code';
      });
      return;
    }

    setState(() {
      isValidatingCode = true;
      errorMessage = null;
    });

    try {
      final result = await _discountService.validateDiscountCode(
        code,
        calculateSubtotal(),
        null,
        null
      );
      
      if (!result.isValid) {
        setState(() {
          isValidatingCode = false;
          errorMessage = result.message;
          discountAmount = 0.0;
          appliedDiscountCode = null;
        });
        return;
      }

      if (result.discount?.id != null) {
        try {
          await _discountService.applyDiscountCode(result.discount!.id);
          setState(() {
            isValidatingCode = false;
            appliedDiscountCode = code;
            discountAmount = result.discountAmount ?? 0.0;
            errorMessage = null;
            _discountController.clear();
          });
        } catch (usageError) {
          setState(() {
            isValidatingCode = false;
            errorMessage = usageError.toString().replaceAll('Exception: ', '');
            discountAmount = 0.0;
            appliedDiscountCode = null;
          });
        }
      }
    } catch (e) {
      setState(() {
        isValidatingCode = false;
        errorMessage = e.toString().replaceAll('Exception: ', '');
        discountAmount = 0.0;
        appliedDiscountCode = null;
      });
    }
  }

  void removeDiscount() {
    setState(() {
      appliedDiscountCode = null;
      discountAmount = 0.0;
      errorMessage = null;
      _discountController.clear();
    });
  }

  double calculateSubtotal() {
    final numberOfNights = checkOutDate.difference(checkInDate).inDays;
    return widget.selectedRooms.fold(
      0,
      (sum, room) => sum + (room["price"] * room["selected"] * numberOfNights),
    );
  }

  double calculateTotal() {
    return calculateSubtotal() - discountAmount;
  }

  Widget _buildHotelIcon() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.hotel,
        color: primaryColor,
        size: 32,
      ),
    );
  }

  Widget _buildRoomImage(String? imageUrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: getBackgroundColor(isDark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.hotel_outlined,
                    color: primaryColor.withOpacity(0.5),
                    size: 32,
                  );
                },
              ),
            )
          : Icon(
              Icons.hotel_outlined,
              color: primaryColor.withOpacity(0.5),
              size: 32,
            ),
    );
  }

  void _showAvailableVouchers() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: getCardColor(isDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available Vouchers',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: getTextColor(isDark),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: getTextColor(isDark)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('discounts')
                          .where('isActive', isEqualTo: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(getAccentColor(isDark)),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error loading vouchers',
                              style: TextStyle(color: getTextColor(isDark)),
                            ),
                          );
                        }

                        final discounts = snapshot.data?.docs ?? [];
                        final validDiscounts = discounts.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final expiry = data['expiry'] as Timestamp?;
                          if (expiry == null) return false;
                          return expiry.toDate().isAfter(DateTime.now());
                        }).toList();

                        if (validDiscounts.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.local_offer_outlined, 
                                  size: 48, 
                                  color: getSubtitleColor(isDark),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No vouchers available',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: getTextColor(isDark),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Check back later for new offers',
                                  style: TextStyle(
                                    color: getSubtitleColor(isDark),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: validDiscounts.length,
                          itemBuilder: (context, index) {
                            final discount = validDiscounts[index].data() as Map<String, dynamic>;
                            final expiryRaw = discount['expiry'];
                            if (expiryRaw == null || expiryRaw is! Timestamp) {
                              return SizedBox.shrink();
                            }
                            final expiryDate = expiryRaw.toDate();
                            final isExpiringSoon = expiryDate.difference(DateTime.now()).inDays < 7;

                            return Card(
                              margin: EdgeInsets.only(bottom: 12),
                              color: getCardColor(isDark),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isExpiringSoon 
                                      ? Colors.orange 
                                      : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                                  width: 1,
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  setState(() {
                                    _discountController.text = discount['code'];
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  discount['code'] ?? '',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                    letterSpacing: 1.2,
                                                    color: getTextColor(isDark),
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  "${discount['rate']}% OFF",
                                                  style: TextStyle(
                                                    color: getAccentColor(isDark),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: getAccentColor(isDark).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'Tap to Apply',
                                              style: TextStyle(
                                                color: getAccentColor(isDark),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.event,
                                            size: 16,
                                            color: isExpiringSoon ? Colors.orange : getSubtitleColor(isDark),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            "Expires: ${DateFormat('MMM d, y').format(expiryDate)}",
                                            style: TextStyle(
                                              color: isExpiringSoon ? Colors.orange : getSubtitleColor(isDark),
                                              fontWeight: isExpiringSoon ? FontWeight.w500 : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (discount['description']?.isNotEmpty ?? false) ...[
                                        SizedBox(height: 8),
                                        Text(
                                          discount['description'],
                                          style: TextStyle(
                                            color: getSubtitleColor(isDark),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtotal = calculateSubtotal();
    final totalPrice = calculateTotal();
    final numberOfNights = checkOutDate.difference(checkInDate).inDays;

    return Scaffold(
      backgroundColor: getBackgroundColor(isDark),
      appBar: AppBar(
        title: Text(
          'Booking Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: getAccentColor(isDark),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hotel Info Card
            Card(
              elevation: 0,
              margin: EdgeInsets.all(16),
              color: getCardColor(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark 
                      ? Colors.grey.shade800 
                      : Colors.grey.shade200,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: getAccentColor(isDark).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.hotel,
                            color: getAccentColor(isDark),
                            size: 32,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.hotelName,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: getTextColor(isDark),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '$numberOfNights ${numberOfNights == 1 ? 'night' : 'nights'}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: getSubtitleColor(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : lightBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectDates,
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Check-in',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: getSubtitleColor(isDark),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      DateFormat('EEE, MMM d').format(checkInDate),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: getTextColor(isDark),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(
                            height: 32,
                            width: 1,
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: _selectDates,
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Check-out',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: getSubtitleColor(isDark),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      DateFormat('EEE, MMM d').format(checkOutDate),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: getTextColor(isDark),
                                      ),
                                    ),
                                  ],
                                ),
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

            // Your Rooms Section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Your Rooms',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: getTextColor(isDark),
                ),
              ),
            ),
            SizedBox(height: 16),
            ...widget.selectedRooms.map((room) => Card(
              elevation: 0,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: getCardColor(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark 
                      ? Colors.grey.shade800 
                      : Colors.grey.shade200,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : lightBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: room['image'] != null && room['image'].toString().isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                room['image'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.hotel_outlined,
                                    color: getAccentColor(isDark).withOpacity(0.5),
                                    size: 32,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.hotel_outlined,
                              color: getAccentColor(isDark).withOpacity(0.5),
                              size: 32,
                            ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room['name'] ?? 'Room',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: getTextColor(isDark),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${room['selected']} ${room['selected'] == 1 ? 'room' : 'rooms'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: getSubtitleColor(isDark),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'RM${(room['price'] * room['selected']).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: getAccentColor(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )).toList(),

            // Discount Section
            Card(
              elevation: 0,
              margin: EdgeInsets.all(16),
              color: getCardColor(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark 
                      ? Colors.grey.shade800 
                      : Colors.grey.shade200,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Promo Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: getTextColor(isDark),
                      ),
                    ),
                    SizedBox(height: 16),
                    if (appliedDiscountCode == null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _discountController,
                              style: TextStyle(color: getTextColor(isDark)),
                              decoration: InputDecoration(
                                hintText: 'Enter promo code',
                                hintStyle: TextStyle(color: getSubtitleColor(isDark)),
                                errorText: errorMessage,
                                filled: true,
                                fillColor: isDark ? Colors.black26 : lightBackgroundColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.local_offer, color: getAccentColor(isDark)),
                            tooltip: 'Show available vouchers',
                            onPressed: _showAvailableVouchers,
                          ),
                          SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: isValidatingCode ? null : applyDiscountCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: getAccentColor(isDark),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 24,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isValidatingCode
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text('Apply'),
                          ),
                        ],
                      ),
                    ] else ...[
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? successColor.withOpacity(0.2)
                              : successColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: successColor,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appliedDiscountCode!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: successColor,
                                    ),
                                  ),
                                  Text(
                                    'RM${discountAmount.toStringAsFixed(2)} discount applied',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: successColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: removeDiscount,
                              child: Text(
                                'Remove',
                                style: TextStyle(
                                  color: errorColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Price Summary
            Card(
              elevation: 0,
              margin: EdgeInsets.all(16),
              color: getCardColor(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark 
                      ? Colors.grey.shade800 
                      : Colors.grey.shade200,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: getTextColor(isDark),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal',
                          style: TextStyle(
                            color: getSubtitleColor(isDark),
                          ),
                        ),
                        Text(
                          'RM${subtotal.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: getTextColor(isDark),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (discountAmount > 0) ...[
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Discount',
                            style: TextStyle(
                              color: successColor,
                            ),
                          ),
                          Text(
                            '-RM${discountAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: successColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Taxes & Fees',
                          style: TextStyle(
                            color: getSubtitleColor(isDark),
                          ),
                        ),
                        Text(
                          'Included',
                          style: TextStyle(
                            color: getSubtitleColor(isDark),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(
                        height: 1,
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: getTextColor(isDark),
                          ),
                        ),
                        Text(
                          'RM${totalPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: getAccentColor(isDark),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: getCardColor(isDark),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    final updatedRooms = widget.selectedRooms.map((room) {
                      return {
                        ...room,
                        'hotelId': room['hotelId'] ?? '',
                        'roomTypeId': room['roomNumber']?.toString() ?? '',
                        'checkInDate': Timestamp.fromDate(checkInDate),
                        'checkOutDate': Timestamp.fromDate(checkOutDate),
                        'numberOfNights': checkOutDate.difference(checkInDate).inDays,
                      };
                    }).toList();

                    return PaymentPage(
                      hotelName: widget.hotelName,
                      selectedRooms: updatedRooms,
                      totalPrice: totalPrice,
                      appliedDiscountCode: appliedDiscountCode,
                      discountAmount: discountAmount,
                    );
                  },
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: getAccentColor(isDark),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Proceed to Payment • RM${totalPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

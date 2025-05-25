import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String id;
  final String hotelId;
  final String userId;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final DateTime createdAt;
  final num discountAmount;
  final num totalAmount;
  final String status;
  final String paymentId;
  final String paymentMethod;
  final bool isPaid;

  Booking({
    required this.id,
    required this.hotelId,
    required this.userId,
    required this.checkInDate,
    required this.checkOutDate,
    required this.createdAt,
    required this.discountAmount,
    required this.totalAmount,
    required this.status,
    required this.paymentId,
    required this.paymentMethod,
    required this.isPaid,
  });

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Booking(
      id: doc.id,
      hotelId: data['hotelId'] ?? '',
      userId: data['userId'] ?? '',
      checkInDate: (data['checkInDate'] as Timestamp).toDate(),
      checkOutDate: (data['checkOutDate'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      discountAmount: data['discountAmount'] ?? 0,
      totalAmount: data['totalAmount'] ?? 0,
      status: data['status'] ?? 'pending',
      paymentId: data['paymentId'] ?? '',
      paymentMethod: data['paymentMethod'] ?? '',
      isPaid: data['isPaid'] ?? false,
    );
  }
}

class BookingManagement extends StatefulWidget {
  const BookingManagement({Key? key}) : super(key: key);

  @override
  _BookingManagementState createState() => _BookingManagementState();
}

class _BookingManagementState extends State<BookingManagement> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Active', 'Upcoming', 'Completed', 'Cancelled'];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Filter state
  List<Map<String, dynamic>> _hotels = [];
  String? _selectedHotelId;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadHotels();
  }

  Future<void> _loadHotels() async {
    final snapshot = await _firestore.collection('hotels').get();
    setState(() {
      _hotels = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                'name': doc.data()['name'] as String,
              })
          .toList();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _getBookingsStream(String status) {
    final now = DateTime.now();
    Query query = _firestore.collection('bookings');
    switch (status) {
      case 'Active':
        return query
            .where('status', isEqualTo: 'confirmed')
            .where('isPaid', isEqualTo: true)
            .where('checkInDate', isLessThanOrEqualTo: Timestamp.fromDate(now))
            .where('checkOutDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
            .orderBy('checkInDate', descending: false)
            .snapshots();
      case 'Upcoming':
        return query
            .where('status', isEqualTo: 'confirmed')
            .where('isPaid', isEqualTo: true)
            .where('checkInDate', isGreaterThan: Timestamp.fromDate(now))
            .orderBy('checkInDate', descending: false)
            .snapshots();
      case 'Completed':
        return query
            .where('status', isEqualTo: 'confirmed')
            .where('isPaid', isEqualTo: true)
            .where('checkOutDate', isLessThan: Timestamp.fromDate(now))
            .orderBy('checkOutDate', descending: true)
            .snapshots();
      case 'Cancelled':
        return query
            .where('status', isEqualTo: 'cancelled')
            .orderBy('cancelledAt', descending: true)
            .snapshots();
      default:
        return query.orderBy('createdAt', descending: true).snapshots();
    }
  }

  Future<void> _deleteBooking(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting booking: $e')),
      );
    }
  }

  Widget _buildBookingCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final checkInDate = (data['checkInDate'] as Timestamp).toDate();
    final checkOutDate = (data['checkOutDate'] as Timestamp).toDate();
    final now = DateTime.now();

    // Add null check for hotelId and roomTypeId
    final hotelId = data['hotelId']?.toString() ?? '';
    final roomTypeId = data['roomTypeId']?.toString() ?? '';
    final userId = data['userId']?.toString() ?? 'Unknown User';
    final cancelledBy = data['cancelledBy']?.toString() ?? '';
    final cancelledAt = data['cancelledAt'] as Timestamp?;
    final isPaid = data['isPaid'] ?? false;

    // Calculate booking status for display
    String displayStatus = data['status'].toString().toLowerCase();
    if (displayStatus == 'confirmed') {
      if (!isPaid) {
        displayStatus = 'pending_payment';
      } else if (checkOutDate.isBefore(now)) {
        displayStatus = 'completed';
      } else if (checkInDate.isBefore(now) && checkOutDate.isAfter(now)) {
        displayStatus = 'active';
      }
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('hotels').doc(hotelId).get(),
      builder: (context, hotelSnapshot) {
        String hotelName = 'Loading...';

        if (hotelSnapshot.hasData && hotelSnapshot.data != null) {
          final hotelData = hotelSnapshot.data!.data() as Map<String, dynamic>?;
          hotelName = hotelData?['name'] ?? 'Unknown Hotel';
        }

        return Card(
          margin: EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                            hotelName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Booking #${doc.id}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(displayStatus).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _getDisplayStatus(displayStatus),
                            style: TextStyle(
                              color: _getStatusColor(displayStatus),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          if (displayStatus == 'cancelled' && cancelledBy.isNotEmpty)
                            Text(
                              'by ${cancelledBy == 'admin' ? 'Admin' : 'User'}',
                              style: TextStyle(
                                color: _getStatusColor(displayStatus),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Simplified room type display
                _buildInfoRow('Room Type', '${data['roomType'] ?? 'Single Room'} × ${data['quantity'] ?? 1}'),
                _buildInfoRow('Duration', '${data['numberOfNights'] ?? 1} night(s)'),
                _buildInfoRow('Check-in', '${checkInDate.day}/${checkInDate.month}/${checkInDate.year}'),
                _buildInfoRow('Check-out', '${checkOutDate.day}/${checkOutDate.month}/${checkOutDate.year}'),
                _buildInfoRow('Total Amount', 'RM${data['totalAmount']?.toStringAsFixed(2) ?? '0.00'}'),
                if (data['discountAmount'] != null && data['discountAmount'] > 0)
                  _buildInfoRow('Discount', 'RM${data['discountAmount'].toStringAsFixed(2)}'),
                _buildInfoRow('Payment Status', data['isPaid'] == true ? 'Paid' : 'Pending'),
                if (data['paymentMethod'] != null)
                  _buildInfoRow('Payment Method', data['paymentMethod']),
                if (cancelledAt != null)
                  _buildInfoRow('Cancelled At', '${cancelledAt.toDate().day}/${cancelledAt.toDate().month}/${cancelledAt.toDate().year}'),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (data['status'].toString().toLowerCase() != 'cancelled')
                      TextButton.icon(
                        icon: Icon(Icons.edit),
                        label: Text('Edit'),
                        onPressed: () => _showUpdateBookingDialog(doc),
                      ),
                    SizedBox(width: 8),
                    TextButton.icon(
                      icon: Icon(Icons.delete, color: Colors.red),
                      label: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                      onPressed: () => _showDeleteDialog(doc.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: Text(
          "Bookings",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[800],
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((tab) {
            IconData icon;
            switch(tab) {
              case 'Active':
                icon = Icons.play_circle_outline;
                break;
              case 'Upcoming':
                icon = Icons.schedule;
                break;
              case 'Completed':
                icon = Icons.check_circle_outline;
                break;
              case 'Cancelled':
                icon = Icons.cancel_outlined;
                break;
              default:
                icon = Icons.help_outline;
            }
            return Tab(
              icon: Icon(icon, size: 20),
              text: tab,
              iconMargin: EdgeInsets.only(bottom: 4),
            );
          }).toList(),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorSize: TabBarIndicatorSize.label,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Hotel filter
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedHotelId,
                    hint: Text('Filter by Hotel'),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Hotels'),
                      ),
                      ..._hotels.map((hotel) => DropdownMenuItem<String>(
                            value: hotel['id'],
                            child: Text(hotel['name']),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedHotelId = value;
                      });
                    },
                  ),
                ),
                SizedBox(width: 12),
                // Date filter
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Filter by Date',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.date_range, size: 20),
                          SizedBox(width: 8),
                          Text(_selectedDate == null
                              ? 'All Dates'
                              : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                          if (_selectedDate != null)
                            IconButton(
                              icon: Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  _selectedDate = null;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) {
                return StreamBuilder<QuerySnapshot>(
                  stream: _getBookingsStream(tab),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: \\${snapshot.error}'),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getStatusIcon(tab),
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No \\${tab} bookings',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Filter bookings by hotel and date
                    var bookings = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      bool hotelMatch = _selectedHotelId == null || data['hotelId'] == _selectedHotelId;
                      bool dateMatch = true;
                      if (_selectedDate != null && data['checkInDate'] is Timestamp) {
                        final checkIn = (data['checkInDate'] as Timestamp).toDate();
                        dateMatch = checkIn.year == _selectedDate!.year && checkIn.month == _selectedDate!.month && checkIn.day == _selectedDate!.day;
                      }
                      return hotelMatch && dateMatch;
                    }).toList();

                    return ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: bookings.length,
                      itemBuilder: (context, index) {
                        return _buildBookingCard(bookings[index]);
                      },
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Active':
        return Icons.play_circle_outline;
      case 'Completed':
        return Icons.check_circle_outline;
      case 'Cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _getDisplayStatus(String status) {
    switch (status) {
      case 'active':
        return 'ACTIVE';
      case 'completed':
        return 'COMPLETED';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return status.toUpperCase();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showUpdateBookingDialog(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Booking'),
        content: Text('Would you like to update this booking with hotel and room information?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL'),
          ),
          TextButton(
        onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to booking update screen
              // You should create a new screen to select hotel and room
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Update functionality coming soon')),
              );
            },
            child: Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(String bookingId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Booking'),
        content: Text('Are you sure you want to delete this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteBooking(bookingId);
            },
                    child: Text(
              'DELETE',
              style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
    );
  }

  // Add this helper method for consistent info row styling
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
                    child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
          SizedBox(
            width: 100,
            child: Text(
              label + ':',
                          style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
                  ),
                ),
          Expanded(
                      child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
                        ),
                      ),
                    ),
                  ],
      ),
    );
  }
}


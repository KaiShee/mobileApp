import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/booking_model.dart';
import 'package:intl/intl.dart';

class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({super.key});

  @override
  _BookingHistoryPageState createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedFilter = "All";
  List<BookingModel> _bookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      Query<Map<String, dynamic>> query = _firestore.collection('bookings')
          .where('userId', isEqualTo: user.uid);

      if (_selectedFilter != "All") {
        query = query.where('status', isEqualTo: _selectedFilter.toLowerCase());
      }

      query = query.orderBy('createdAt', descending: true);

      final snapshot = await query.get();
      final bookings = await Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data();
        data['id'] = doc.id;
        
        final hotelDoc = await _firestore.collection('hotels').doc(data['hotelId']).get();
        final hotelData = hotelDoc.data() as Map<String, dynamic>?;
        
        final roomTypeDoc = await _firestore
            .collection('hotels')
            .doc(data['hotelId'])
            .collection('roomTypes')
            .doc(data['roomTypeId'])
            .get();
        final roomData = roomTypeDoc.data() as Map<String, dynamic>?;
        
        data['hotelName'] = hotelData?['name'] ?? 'Unknown Hotel';
        data['hotelImage'] = hotelData?['images']?[0] ?? '';
        data['roomName'] = roomData?['name'] ?? 'Unknown Room';
        data['roomAmenities'] = roomData?['amenities'] ?? [];
        data['roomDescription'] = roomData?['description'] ?? '';
        data['roomImage'] = roomData?['images']?[0] ?? '';
        
        return BookingModel.fromMap(data);
      }).toList());

      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.primary,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Booking History",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: isDark ? theme.colorScheme.surface : theme.cardColor,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip("All"),
                  const SizedBox(width: 8),
                  _buildFilterChip("Confirmed"),
                  const SizedBox(width: 8),
                  _buildFilterChip("Completed"),
                  const SizedBox(width: 8),
                  _buildFilterChip("Cancelled"),
                ],
              ),
            ),
          ),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, 
              size: 48, 
              color: theme.colorScheme.error
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadBookings,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      );
    }

    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hotel_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              "No bookings found",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Your booking history will appear here",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookings.length,
      itemBuilder: (context, index) {
        return _buildBookingCard(_bookings[index]);
      },
    );
  }

  Widget _buildFilterChip(String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _selectedFilter == label;
    
    return FilterChip(
      selected: isSelected,
      backgroundColor: isSelected 
          ? theme.colorScheme.primary
          : isDark 
              ? theme.colorScheme.surfaceVariant
              : theme.colorScheme.surface,
      label: Text(
        label,
        style: TextStyle(
          color: isSelected 
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _selectedFilter = label;
          });
          _loadBookings();
        }
      },
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected 
              ? Colors.transparent
              : theme.colorScheme.outline.withOpacity(isDark ? 0.2 : 0.3),
        ),
      ),
    );
  }

  Widget _buildBookingCard(BookingModel booking) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final nights = booking.checkOutDate.toDate().difference(booking.checkInDate.toDate()).inDays;
    
    return Card(
      elevation: isDark ? 0 : 2,
      color: isDark ? theme.colorScheme.surfaceVariant : theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark 
              ? theme.colorScheme.outline.withOpacity(0.2)
              : Colors.transparent,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              image: DecorationImage(
                image: NetworkImage(booking.hotelImage ?? 'https://via.placeholder.com/400x200'),
                fit: BoxFit.cover,
                colorFilter: isDark 
                    ? ColorFilter.mode(
                        Colors.black.withOpacity(0.4),
                        BlendMode.darken,
                      )
                    : null,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(isDark ? 0.8 : 0.7),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.hotelName ?? 'Unknown Hotel',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  _buildStatusBadge(booking.status),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 80,
                        height: 80,
                        color: isDark ? theme.colorScheme.surface : theme.colorScheme.surfaceVariant,
                        child: booking.roomImage != null
                            ? Image.network(
                                booking.roomImage!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.hotel,
                                  size: 40,
                                  color: isDark ? theme.colorScheme.onSurface.withOpacity(0.7) : theme.colorScheme.onSurfaceVariant,
                                ),
                              )
                            : Icon(
                                Icons.hotel,
                                size: 40,
                                color: isDark ? theme.colorScheme.onSurface.withOpacity(0.7) : theme.colorScheme.onSurfaceVariant,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.roomName ?? 'Standard Room',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? theme.colorScheme.onSurface : theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (booking.roomDescription != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              booking.roomDescription!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? theme.colorScheme.onSurface.withOpacity(0.8) : theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: theme.colorScheme.outline.withOpacity(isDark ? 0.2 : 0.1)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Flexible(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            Icons.calendar_today,
                            'Check-in',
                            DateFormat('MMM d, yyyy').format(booking.checkInDate.toDate()),
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.calendar_today,
                            'Check-out',
                            DateFormat('MMM d, yyyy').format(booking.checkOutDate.toDate()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            Icons.nights_stay,
                            'Duration',
                            '$nights ${nights == 1 ? 'night' : 'nights'}',
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.payment,
                            'Total Amount',
                            'RM${booking.totalAmount.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: theme.colorScheme.outline.withOpacity(isDark ? 0.2 : 0.1)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPaymentStatus(booking.isPaid),
                    if (booking.status.toLowerCase() == 'confirmed')
                      TextButton.icon(
                        onPressed: () {
                          // TODO: Implement cancel booking functionality
                        },
                        icon: Icon(
                          Icons.cancel_outlined,
                          color: theme.colorScheme.error,
                          size: 20,
                        ),
                        label: Text(
                          'Cancel Booking',
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final theme = Theme.of(context);
    final color = _getStatusColor(status, theme);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(status),
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? theme.colorScheme.onSurface.withOpacity(0.7) : theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? theme.colorScheme.onSurface.withOpacity(0.7) : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? theme.colorScheme.onSurface : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStatus(bool isPaid) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = isPaid 
        ? theme.colorScheme.primary 
        : theme.colorScheme.tertiary;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid ? Icons.check_circle : Icons.pending,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Text(
            isPaid ? 'Paid' : 'Payment Pending',
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return theme.colorScheme.primary;
      case 'completed':
        return theme.colorScheme.tertiary;
      case 'cancelled':
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.secondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }
}
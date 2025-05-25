import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'models/booking_model.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'utils/app_localizations.dart';

class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({super.key});

  @override
  State<BookingHistoryPage> createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedFilter = "All";
  List<BookingModel> _bookings = [];
  bool _isLoading = true;
  String? _error;
  late AppLocalizations _l10n;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _l10n = AppLocalizations.of(context);
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception(_l10n.get('user_not_authenticated'));
      }

      // Create the base query
      Query<Map<String, dynamic>> query = _firestore.collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true);

      final snapshot = await query.get();
      final bookings = await Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data();
        data['id'] = doc.id;
        
        // Get current timestamp for date comparison
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final checkOutDate = (data['checkOutDate'] as Timestamp).toDate();
        
        // Filter bookings based on selected tab
        if (_selectedFilter == "Confirmed") {
          if (data['status'] != 'confirmed' || checkOutDate.isBefore(today)) {
            return null;
          }
        } else if (_selectedFilter == "Completed") {
          if (data['status'] != 'confirmed' || checkOutDate.isAfter(today)) {
            return null;
          }
        } else if (_selectedFilter == "Cancelled") {
          if (data['status'] != 'cancelled') {
            return null;
          }
        }
        
        // Fetch hotel details
        final hotelDoc = await _firestore.collection('hotels').doc(data['hotelId']).get();
        final hotelData = hotelDoc.data() as Map<String, dynamic>?;
        
        // First try to get room type from the new structure
        final roomTypeDoc = await _firestore.collection('roomTypes').doc(data['roomTypeId']).get();
        
        if (!roomTypeDoc.exists) {
          // If not found in new structure, try the old structure
          final oldRoomTypeDoc = await _firestore
              .collection('hotels')
              .doc(data['hotelId'])
              .collection('roomTypes')
              .where('roomNumber', isEqualTo: data['roomTypeId'])
              .limit(1)
              .get();

          if (oldRoomTypeDoc.docs.isNotEmpty) {
            final roomData = oldRoomTypeDoc.docs.first.data();
            data['roomName'] = roomData['name'] ?? '${_l10n.get('room')} ${data['roomTypeId']}';
            data['roomDescription'] = roomData['description'] ?? _l10n.get('standard_room');
            data['roomImage'] = roomData['imageUrl'] ?? '';
            data['roomAmenities'] = roomData['amenities'] ?? [];
          } else {
            // If room type is not found in either location, extract info from the ID
            final floorNumber = data['roomTypeId'].toString().substring(0, 1);
            final roomNumber = data['roomTypeId'].toString();
            data['roomName'] = '${_l10n.get('room')} $roomNumber';
            data['roomDescription'] = '${_l10n.get('floor')} $floorNumber ${_l10n.get('room')}';
            data['roomImage'] = '';
            data['roomAmenities'] = [];
          }
        } else {
          // Use data from the new structure
          final roomData = roomTypeDoc.data() as Map<String, dynamic>;
          data['roomName'] = roomData['name'] ?? '${_l10n.get('room')} ${data['roomTypeId']}';
          data['roomDescription'] = roomData['description'] ?? _l10n.get('standard_room');
          data['roomImage'] = roomData['image'] ?? '';
          data['roomAmenities'] = roomData['amenities'] ?? [];
        }
        
        // Update hotel data
        data['hotelName'] = hotelData?['name'] ?? _l10n.get('unknown_hotel');
        data['hotelImage'] = hotelData?['imageUrl'] ?? '';
        
        return BookingModel.fromMap(data);
      }).toList());

      if (!mounted) return;

      setState(() {
        _bookings = bookings.where((booking) => booking != null).cast<BookingModel>().toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
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
        title: Text(
          _l10n.get('booking_history'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadBookings,
        color: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.surface,
        child: Column(
          children: [
            _buildFilterSection(),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildFilterChip("All", _l10n.get('all')),
            const SizedBox(width: 12),
            _buildFilterChip("Confirmed", _l10n.get('confirmed')),
            const SizedBox(width: 12),
            _buildFilterChip("Completed", _l10n.get('completed')),
            const SizedBox(width: 12),
            _buildFilterChip("Cancelled", _l10n.get('cancelled')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingShimmer();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_bookings.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookings.length,
      itemBuilder: (context, index) {
        return _buildBookingCard(_bookings[index]);
      },
    );
  }

  Widget _buildLoadingShimmer() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Card(
          elevation: isDark ? 0 : 2,
          color: theme.colorScheme.surface,
          shadowColor: theme.shadowColor.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isDark ? BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ) : BorderSide.none,
          ),
          margin: const EdgeInsets.only(bottom: 16),
          child: Shimmer.fromColors(
            baseColor: isDark 
                ? theme.colorScheme.surfaceVariant 
                : Colors.grey[300]!,
            highlightColor: isDark 
                ? theme.colorScheme.surface 
                : Colors.grey[100]!,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: 20,
                                  color: theme.colorScheme.surface,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: 200,
                                  height: 16,
                                  color: theme.colorScheme.surface,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            _l10n.get('error_loading_bookings'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            _l10n.get('no_bookings'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _selectedFilter == value;
    
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          color: isSelected 
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected 
              ? Colors.transparent
              : theme.colorScheme.outline.withOpacity(isDark ? 0.2 : 0.3),
        ),
      ),
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });
          _loadBookings();
        }
      },
    );
  }

  Widget _buildBookingCard(BookingModel booking) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final nights = booking.checkOutDate.toDate().difference(booking.checkInDate.toDate()).inDays;
    
    return Card(
      elevation: isDark ? 0 : 2,
      color: theme.colorScheme.surface,
      shadowColor: theme.shadowColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isDark ? BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ) : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHotelImageHeader(booking),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRoomInfo(booking),
                const SizedBox(height: 16),
                Divider(color: theme.colorScheme.outline.withOpacity(isDark ? 0.2 : 0.1)),
                const SizedBox(height: 16),
                _buildBookingDetails(booking, nights),
                if (booking.roomAmenities != null && booking.roomAmenities!.isNotEmpty)
                  _buildAmenitiesSection(booking),
                const SizedBox(height: 16),
                Divider(color: theme.colorScheme.outline.withOpacity(isDark ? 0.2 : 0.1)),
                const SizedBox(height: 16),
                _buildBottomSection(booking),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotelImageHeader(BookingModel booking) {
    final theme = Theme.of(context);
    
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: CachedNetworkImage(
            imageUrl: booking.hotelImage ?? '',
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildLoadingShimmer(),
            errorWidget: (context, url, error) => Container(
              height: 200,
              color: theme.colorScheme.surfaceVariant,
              child: Icon(
                Icons.hotel,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.hotelName ?? _l10n.get('unknown_hotel'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildStatusChip(booking.status),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _getStatusColor(status).withAlpha(230);
    
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
            _getStatusIcon(status),
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
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

  Widget _buildRoomInfo(BookingModel booking) {
    final theme = Theme.of(context);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: booking.roomImage ?? '',
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 80,
              height: 80,
              color: theme.colorScheme.surfaceVariant,
              child: Icon(
                Icons.hotel_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 80,
              height: 80,
              color: theme.colorScheme.surfaceVariant,
              child: Icon(
                Icons.hotel_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.roomName ?? _l10n.get('standard_room'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (booking.roomDescription != null && booking.roomDescription!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  booking.roomDescription!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookingDetails(BookingModel booking, int nights) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDetailItem(
                Icons.calendar_today,
                _l10n.get('check_in'),
                DateFormat('MMM d, yyyy').format(booking.checkInDate.toDate()),
              ),
            ),
            Expanded(
              child: _buildDetailItem(
                Icons.calendar_today,
                _l10n.get('check_out'),
                DateFormat('MMM d, yyyy').format(booking.checkOutDate.toDate()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDetailItem(
                Icons.nights_stay,
                _l10n.get('duration'),
                '$nights ${nights == 1 ? _l10n.get('night') : _l10n.get('nights')}',
              ),
            ),
            Expanded(
              child: _buildDetailItem(
                Icons.payment,
                _l10n.get('total_amount'),
                'RM${booking.totalAmount.toStringAsFixed(2)}',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAmenitiesSection(BookingModel booking) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Divider(color: theme.colorScheme.outline.withOpacity(isDark ? 0.2 : 0.1)),
        const SizedBox(height: 16),
        Text(
          _l10n.get('room_amenities'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (booking.roomAmenities as List<dynamic>).map((amenity) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                amenity.toString(),
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBottomSection(BookingModel booking) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildPaymentStatus(booking.isPaid),
        if (booking.status.toLowerCase() == 'confirmed')
          TextButton.icon(
            onPressed: () async {
              // Show confirmation dialog
              final bool? confirm = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(_l10n.get('cancel_booking')),
                    content: Text(_l10n.get('cancel_booking_confirmation')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(_l10n.get('no')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(
                          _l10n.get('yes'),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  );
                },
              );

              if (confirm == true) {
                try {
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                  );

                  // Update booking status in Firestore
                  await _firestore
                      .collection('bookings')
                      .doc(booking.id)
                      .update({
                    'status': 'cancelled',
                    'cancelledAt': FieldValue.serverTimestamp(),
                  });

                  // Close loading indicator
                  if (mounted) {
                    Navigator.of(context).pop();
                  }

                  // Show success message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_l10n.get('booking_cancelled')),
                        backgroundColor: theme.colorScheme.primary,
                      ),
                    );
                  }

                  // Refresh the bookings list
                  _loadBookings();
                } catch (e) {
                  // Close loading indicator
                  if (mounted) {
                    Navigator.of(context).pop();
                  }

                  // Show error message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_l10n.get('error_cancelling_booking')),
                        backgroundColor: theme.colorScheme.error,
                      ),
                    );
                  }
                }
              }
            },
            icon: Icon(
              Icons.cancel_outlined,
              color: theme.colorScheme.error,
              size: 20,
            ),
            label: Text(
              _l10n.get('cancel_booking'),
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
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
            isPaid ? _l10n.get('paid') : _l10n.get('payment_pending'),
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
}
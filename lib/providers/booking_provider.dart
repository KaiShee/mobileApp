import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../services/discount_service.dart';

class BookingProvider with ChangeNotifier {
  final BookingService _bookingService = BookingService();
  final DiscountService _discountService = DiscountService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<BookingModel> _bookings = [];
  BookingModel? _selectedBooking;
  Map<String, dynamic>? _bookingStatistics;
  bool _isLoading = false;
  String? _error;
  double? _calculatedPrice;
  double? _discountAmount;

  // Getters
  List<BookingModel> get bookings => _bookings;
  BookingModel? get selectedBooking => _selectedBooking;
  Map<String, dynamic>? get bookingStatistics => _bookingStatistics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double? get calculatedPrice => _calculatedPrice;
  double? get discountAmount => _discountAmount;

  void setSelectedBooking(BookingModel? booking) {
    _selectedBooking = booking;
    notifyListeners();
  }

  // Create booking
  Future<String?> createBooking(BookingModel booking) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final docRef = await _firestore.collection('bookings').add(booking.toMap());
      await docRef.update({'id': docRef.id});
      await loadUserBookings(booking.userId);
      return docRef.id;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get booking by ID
  Future<void> getBookingById(String bookingId) async {
    try {
      final doc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      data['id'] = doc.id;
      _selectedBooking = BookingModel.fromMap(data);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Update booking status
  Future<bool> updateBookingStatus(String bookingId, String status) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update selected booking if it's the one being updated
      if (_selectedBooking != null && _selectedBooking!.id == bookingId) {
        _selectedBooking = _selectedBooking!.copyWith(
          status: status,
          updatedAt: Timestamp.now(),
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Cancel booking
  Future<bool> cancelBooking(String bookingId) async {
    return await updateBookingStatus(bookingId, 'cancelled');
  }

  // Update booking payment status
  Future<bool> updateBookingPaymentStatus(
    String bookingId,
    bool isPaid, {
    String? paymentMethod,
    String? paymentId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Map<String, dynamic> updateData = {
        'isPaid': isPaid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (paymentMethod != null) updateData['paymentMethod'] = paymentMethod;
      if (paymentId != null) updateData['paymentId'] = paymentId;

      await _firestore.collection('bookings').doc(bookingId).update(updateData);

      // Update selected booking if it's the one being updated
      if (_selectedBooking != null && _selectedBooking!.id == bookingId) {
        _selectedBooking = _selectedBooking!.copyWith(
          isPaid: isPaid,
          paymentMethod: paymentMethod ?? _selectedBooking!.paymentMethod,
          paymentId: paymentId ?? _selectedBooking!.paymentId,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Load user bookings
  Future<void> loadUserBookings(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      _bookings = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return BookingModel.fromMap(data);
      }).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load hotel bookings
  Future<void> loadHotelBookings(String hotelId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('bookings')
          .where('hotelId', isEqualTo: hotelId)
          .orderBy('createdAt', descending: true)
          .get();

      _bookings = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return BookingModel.fromMap(data);
      }).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load all bookings
  Future<void> loadAllBookings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('bookings')
          .orderBy('createdAt', descending: true)
          .get();

      _bookings = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return BookingModel.fromMap(data);
      }).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Filter bookings
  Future<void> filterBookings({
    String? userId,
    String? hotelId,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
    bool? isPaid,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Query<Map<String, dynamic>> query = _firestore.collection('bookings');

      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      if (hotelId != null) {
        query = query.where('hotelId', isEqualTo: hotelId);
      }
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }
      if (isPaid != null) {
        query = query.where('isPaid', isEqualTo: isPaid);
      }
      if (fromDate != null) {
        query = query.where('checkInDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate));
      }
      if (toDate != null) {
        query = query.where('checkOutDate',
            isLessThanOrEqualTo: Timestamp.fromDate(toDate));
      }

      query = query.orderBy('createdAt', descending: true);

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      _bookings = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return BookingModel.fromMap(data);
      }).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check room availability
  Future<bool> checkRoomAvailability(
    String hotelId,
    String roomTypeId,
    DateTime checkInDate,
    DateTime checkOutDate,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final checkInTimestamp = Timestamp.fromDate(checkInDate);
      final checkOutTimestamp = Timestamp.fromDate(checkOutDate);

      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('bookings')
          .where('hotelId', isEqualTo: hotelId)
          .where('roomTypeId', isEqualTo: roomTypeId)
          .where('status', whereIn: ['confirmed', 'checkedIn'])
          .get();

      // Check if any existing booking overlaps with the requested dates
      for (var doc in snapshot.docs) {
        final booking = doc.data();
        final existingCheckIn = booking['checkInDate'] as Timestamp;
        final existingCheckOut = booking['checkOutDate'] as Timestamp;

        if (!(checkOutTimestamp.toDate().isBefore(existingCheckIn.toDate()) ||
            checkInTimestamp.toDate().isAfter(existingCheckOut.toDate()))) {
          return false; // Room is not available
        }
      }

      return true; // Room is available
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Calculate booking price
  Future<void> calculateBookingPrice(
    String hotelId,
    String roomTypeId,
    DateTime checkInDate,
    DateTime checkOutDate,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final DocumentSnapshot<Map<String, dynamic>> roomDoc = await _firestore
          .collection('hotels')
          .doc(hotelId)
          .collection('roomTypes')
          .doc(roomTypeId)
          .get();

      if (!roomDoc.exists) {
        throw Exception('Room type not found');
      }

      final roomData = roomDoc.data()!;
      final pricePerNight = (roomData['price'] ?? 0.0) as num;

      // Calculate number of nights
      final nights = checkOutDate.difference(checkInDate).inDays;
      _calculatedPrice = pricePerNight.toDouble() * nights;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get booking statistics
  Future<void> getBookingStatistics({
    DateTime? fromDate,
    DateTime? toDate,
    String? hotelId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _bookingStatistics = await _bookingService.getBookingStatistics(
        fromDate: fromDate,
        toDate: toDate,
        hotelId: hotelId,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear selected booking
  void clearSelectedBooking() {
    _selectedBooking = null;
    notifyListeners();
  }

  // Clear calculated price
  void clearCalculatedPrice() {
    _calculatedPrice = null;
    _discountAmount = null;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
} 
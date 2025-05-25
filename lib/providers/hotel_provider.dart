import 'package:flutter/foundation.dart';
import '../models/hotel_model.dart';
import '../models/review_model.dart';
import '../services/hotel_service.dart';
import '../services/review_service.dart';

class HotelProvider with ChangeNotifier {
  final HotelService _hotelService = HotelService();
  final ReviewService _reviewService = ReviewService();

  List<HotelModel> _hotels = [];
  HotelModel? _selectedHotel;
  List<ReviewModel> _hotelReviews = [];
  bool _isLoading = false;
  String? _error;
  Map<String, List<HotelModel>> _cachedSearchResults = {};

  // Getters
  List<HotelModel> get hotels => _hotels;
  HotelModel? get selectedHotel => _selectedHotel;
  List<ReviewModel> get hotelReviews => _hotelReviews;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load all hotels
  Future<void> loadHotels({bool includeInactive = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _hotels = await _hotelService.getAllHotels(includeInactive: includeInactive);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get hotel by ID
  Future<void> getHotelById(String hotelId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _selectedHotel = await _hotelService.getHotelById(hotelId);
      await loadHotelReviews(hotelId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create hotel
  Future<String?> createHotel(HotelModel hotel) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final hotelId = await _hotelService.createHotel(hotel);
      await loadHotels();
      return hotelId;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update hotel
  Future<bool> updateHotel(HotelModel hotel) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _hotelService.updateHotel(hotel);
      if (_selectedHotel != null && _selectedHotel!.id == hotel.id) {
        _selectedHotel = hotel;
      }
      await loadHotels();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete hotel
  Future<bool> deleteHotel(String hotelId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _hotelService.deleteHotel(hotelId);
      if (_selectedHotel != null && _selectedHotel!.id == hotelId) {
        _selectedHotel = null;
      }
      _hotels.removeWhere((hotel) => hotel.id == hotelId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Permanently delete hotel (admin only)
  Future<bool> permanentlyDeleteHotel(String hotelId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _hotelService.permanentlyDeleteHotel(hotelId);
      if (_selectedHotel != null && _selectedHotel!.id == hotelId) {
        _selectedHotel = null;
      }
      _hotels.removeWhere((hotel) => hotel.id == hotelId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Search hotels
  Future<List<HotelModel>> searchHotels(String query) async {
    if (query.isEmpty) {
      return _hotels;
    }

    // Check cache first
    if (_cachedSearchResults.containsKey(query)) {
      return _cachedSearchResults[query]!;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _hotelService.searchHotels(query);
      
      // Cache results
      _cachedSearchResults[query] = results;
      
      _isLoading = false;
      notifyListeners();
      return results;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  // Filter hotels
  Future<List<HotelModel>> filterHotels({
    double? minRating,
    double? maxPrice,
    String? location,
    List<String>? amenities,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _hotelService.filterHotels(
        minRating: minRating,
        maxPrice: maxPrice,
        location: location,
        amenities: amenities,
      );
      
      _isLoading = false;
      notifyListeners();
      return results;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  // Add room type
  Future<bool> addRoomType(String hotelId, RoomType roomType) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _hotelService.addRoomType(hotelId, roomType);
      if (_selectedHotel != null && _selectedHotel!.id == hotelId) {
        await getHotelById(hotelId);
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update room type
  Future<bool> updateRoomType(String hotelId, RoomType roomType) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _hotelService.updateRoomType(hotelId, roomType);
      if (_selectedHotel != null && _selectedHotel!.id == hotelId) {
        await getHotelById(hotelId);
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete room type
  Future<bool> deleteRoomType(String hotelId, String roomTypeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _hotelService.deleteRoomType(hotelId, roomTypeId);
      if (_selectedHotel != null && _selectedHotel!.id == hotelId) {
        await getHotelById(hotelId);
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load hotel reviews
  Future<void> loadHotelReviews(String hotelId, {bool approvedOnly = true}) async {
    try {
      _hotelReviews = await _reviewService.getHotelReviews(hotelId, approvedOnly: approvedOnly);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Upload hotel images
  Future<List<String>?> uploadHotelImages(String hotelId, List<dynamic> imageFiles) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final imageUrls = await _hotelService.uploadHotelImages(hotelId, imageFiles);
      if (_selectedHotel != null && _selectedHotel!.id == hotelId) {
        await getHotelById(hotelId);
      }
      return imageUrls;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Upload room type images
  Future<List<String>?> uploadRoomTypeImages(
      String hotelId, String roomTypeId, List<dynamic> imageFiles) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final imageUrls = await _hotelService.uploadRoomTypeImages(
          hotelId, roomTypeId, imageFiles);
      if (_selectedHotel != null && _selectedHotel!.id == hotelId) {
        await getHotelById(hotelId);
      }
      return imageUrls;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear selected hotel
  void clearSelectedHotel() {
    _selectedHotel = null;
    _hotelReviews = [];
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Clear cache
  void clearCache() {
    _cachedSearchResults.clear();
  }
} 
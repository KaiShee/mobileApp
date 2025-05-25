import 'dart:convert';

class HotelModel {
  final String id;
  final String name;
  final String location;
  final String description;
  final List<String> imageUrls;
  final double rating;
  final int reviewCount;
  final List<RoomType> roomTypes;
  final List<String> amenities;
  final String contactPhone;
  final String contactEmail;
  final Map<String, dynamic> geoLocation;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  HotelModel({
    required this.id,
    required this.name,
    required this.location,
    required this.description,
    required this.imageUrls,
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.roomTypes,
    required this.amenities,
    required this.contactPhone,
    required this.contactEmail,
    required this.geoLocation,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'description': description,
      'imageUrls': imageUrls,
      'rating': rating,
      'reviewCount': reviewCount,
      'roomTypes': roomTypes.map((x) => x.toMap()).toList(),
      'amenities': amenities,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'geoLocation': geoLocation,
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory HotelModel.fromMap(Map<String, dynamic> map) {
    return HotelModel(
      id: map['id'],
      name: map['name'],
      location: map['location'],
      description: map['description'],
      imageUrls: List<String>.from(map['imageUrls']),
      rating: map['rating']?.toDouble() ?? 0.0,
      reviewCount: map['reviewCount'] ?? 0,
      roomTypes: List<RoomType>.from(
          map['roomTypes']?.map((x) => RoomType.fromMap(x)) ?? []),
      amenities: List<String>.from(map['amenities']),
      contactPhone: map['contactPhone'],
      contactEmail: map['contactEmail'],
      geoLocation: Map<String, dynamic>.from(map['geoLocation']),
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory HotelModel.fromJson(String source) =>
      HotelModel.fromMap(json.decode(source));

  HotelModel copyWith({
    String? id,
    String? name,
    String? location,
    String? description,
    List<String>? imageUrls,
    double? rating,
    int? reviewCount,
    List<RoomType>? roomTypes,
    List<String>? amenities,
    String? contactPhone,
    String? contactEmail,
    Map<String, dynamic>? geoLocation,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HotelModel(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      description: description ?? this.description,
      imageUrls: imageUrls ?? this.imageUrls,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      roomTypes: roomTypes ?? this.roomTypes,
      amenities: amenities ?? this.amenities,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      geoLocation: geoLocation ?? this.geoLocation,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RoomType {
  final String id;
  final String name;
  final String description;
  final List<String> imageUrls;
  final double price;
  final int maxOccupancy;
  final int totalRooms;
  final int availableRooms;
  final List<String> amenities;
  final bool isActive;

  RoomType({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrls,
    required this.price,
    required this.maxOccupancy,
    required this.totalRooms,
    required this.availableRooms,
    required this.amenities,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrls': imageUrls,
      'price': price,
      'maxOccupancy': maxOccupancy,
      'totalRooms': totalRooms,
      'availableRooms': availableRooms,
      'amenities': amenities,
      'isActive': isActive,
    };
  }

  factory RoomType.fromMap(Map<String, dynamic> map) {
    return RoomType(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      imageUrls: List<String>.from(map['imageUrls']),
      price: map['price']?.toDouble() ?? 0.0,
      maxOccupancy: map['maxOccupancy'] ?? 0,
      totalRooms: map['totalRooms'] ?? 0,
      availableRooms: map['availableRooms'] ?? 0,
      amenities: List<String>.from(map['amenities']),
      isActive: map['isActive'] ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory RoomType.fromJson(String source) =>
      RoomType.fromMap(json.decode(source));

  RoomType copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? imageUrls,
    double? price,
    int? maxOccupancy,
    int? totalRooms,
    int? availableRooms,
    List<String>? amenities,
    bool? isActive,
  }) {
    return RoomType(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrls: imageUrls ?? this.imageUrls,
      price: price ?? this.price,
      maxOccupancy: maxOccupancy ?? this.maxOccupancy,
      totalRooms: totalRooms ?? this.totalRooms,
      availableRooms: availableRooms ?? this.availableRooms,
      amenities: amenities ?? this.amenities,
      isActive: isActive ?? this.isActive,
    );
  }
} 
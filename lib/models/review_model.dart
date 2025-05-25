import 'dart:convert';

class ReviewModel {
  final String id;
  final String userId;
  final String hotelId;
  final String? bookingId;
  final double rating;
  final String comment;
  final List<String>? imageUrls;
  final bool isApproved;
  final bool isReported;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ReviewModel({
    required this.id,
    required this.userId,
    required this.hotelId,
    this.bookingId,
    required this.rating,
    required this.comment,
    this.imageUrls,
    this.isApproved = false,
    this.isReported = false,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'hotelId': hotelId,
      'bookingId': bookingId,
      'rating': rating,
      'comment': comment,
      'imageUrls': imageUrls,
      'isApproved': isApproved,
      'isReported': isReported,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map) {
    return ReviewModel(
      id: map['id'],
      userId: map['userId'],
      hotelId: map['hotelId'],
      bookingId: map['bookingId'],
      rating: map['rating']?.toDouble() ?? 0.0,
      comment: map['comment'] ?? '',
      imageUrls: map['imageUrls'] != null
          ? List<String>.from(map['imageUrls'])
          : null,
      isApproved: map['isApproved'] ?? false,
      isReported: map['isReported'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory ReviewModel.fromJson(String source) =>
      ReviewModel.fromMap(json.decode(source));

  ReviewModel copyWith({
    String? id,
    String? userId,
    String? hotelId,
    String? bookingId,
    double? rating,
    String? comment,
    List<String>? imageUrls,
    bool? isApproved,
    bool? isReported,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      hotelId: hotelId ?? this.hotelId,
      bookingId: bookingId ?? this.bookingId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      imageUrls: imageUrls ?? this.imageUrls,
      isApproved: isApproved ?? this.isApproved,
      isReported: isReported ?? this.isReported,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 
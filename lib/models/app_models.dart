import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole { visitante, publicador }

class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final UserRole role;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.profileImageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${data['role']}',
        orElse: () => UserRole.visitante,
      ),
      profileImageUrl: data['profileImageUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.toString().split('.').last,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Método para crear desde Auth de Supabase (user_metadata)
  factory UserProfile.fromSupabaseAuth(User user) {
    return UserProfile(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'] ?? 'Usuario',
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${user.userMetadata?['role'] ?? 'visitante'}',
        orElse: () => UserRole.visitante,
      ),
      profileImageUrl: null, // Por ahora sin imagen
      createdAt: DateTime.parse(user.createdAt),
      updatedAt: DateTime.now(),
    );
  }

  // Métodos para Supabase tabla (mantenemos por compatibilidad pero no los usaremos)
  factory UserProfile.fromSupabase(Map<String, dynamic> data, String userId) {
    return UserProfile(
      id: userId,
      email: data['email'] ?? '',
      displayName: data['display_name'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${data['role']}',
        orElse: () => UserRole.visitante,
      ),
      profileImageUrl: data['profile_image_url'],
      createdAt: DateTime.parse(data['created_at']),
      updatedAt: DateTime.parse(data['updated_at']),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'role': role.toString().split('.').last,
      'profile_image_url': profileImageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? email,
    String? displayName,
    UserRole? role,
    String? profileImageUrl,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class TouristSpot {
  final String id;
  final String title;
  final String description;
  final String location;
  final double latitude;
  final double longitude;
  final List<String> imageUrls;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int likesCount;
  final int reviewsCount;

  TouristSpot({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.imageUrls,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.updatedAt,
    this.likesCount = 0,
    this.reviewsCount = 0,
  });

  factory TouristSpot.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TouristSpot(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      likesCount: data['likesCount'] ?? 0,
      reviewsCount: data['reviewsCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrls': imageUrls,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'likesCount': likesCount,
      'reviewsCount': reviewsCount,
    };
  }
}

class Review {
  final String id;
  final String touristSpotId;
  final String authorId;
  final String authorName;
  final String content;
  final double rating;
  final DateTime createdAt;
  final List<String> imageUrls;

  Review({
    required this.id,
    required this.touristSpotId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.rating,
    required this.createdAt,
    this.imageUrls = const [],
  });

  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Review(
      id: doc.id,
      touristSpotId: data['touristSpotId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      content: data['content'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'touristSpotId': touristSpotId,
      'authorId': authorId,
      'authorName': authorName,
      'content': content,
      'rating': rating,
      'createdAt': Timestamp.fromDate(createdAt),
      'imageUrls': imageUrls,
    };
  }
}

class Reply {
  final String id;
  final String reviewId;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime createdAt;

  Reply({
    required this.id,
    required this.reviewId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  factory Reply.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Reply(
      id: doc.id,
      reviewId: data['reviewId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reviewId': reviewId,
      'authorId': authorId,
      'authorName': authorName,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

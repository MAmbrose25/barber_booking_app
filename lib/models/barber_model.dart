class Barber {
  final String id;
  final String name;
  final String role;
  final String avatarUrl;
  final double? rating; // null nghĩa là chưa có ai đánh giá
  final int reviewCount;

  const Barber({
    required this.id,
    required this.name,
    required this.role,
    required this.avatarUrl,
    this.rating,
    this.reviewCount = 0,
  });

  factory Barber.fromMap(Map<String, dynamic> map,
      {Map<String, dynamic>? ratingRow}) {
    return Barber(
      id: map['id'] as String,
      name: map['name'] as String,
      role: map['role'] as String,
      avatarUrl: map['avatar_url'] as String,
      rating: (ratingRow?['avg_rating'] as num?)?.toDouble(),
      reviewCount: (ratingRow?['review_count'] as num?)?.toInt() ?? 0,
    );
  }
}
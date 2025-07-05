class ReviewStats {
  final String doctorId;
  final int totalReviews;
  final double averageRating;
  final Map<int, int> ratingBreakdown;
  final DateTime updatedAt;

  ReviewStats({
    required this.doctorId,
    required this.totalReviews,
    required this.averageRating,
    required this.ratingBreakdown,
    required this.updatedAt,
  });

  factory ReviewStats.fromJson(Map<String, dynamic> json) {
    return ReviewStats(
      doctorId: json['doctor_id'],
      totalReviews: json['total_reviews'] ?? 0,
      averageRating: (json['average_rating'] ?? 0.0).toDouble(),
      ratingBreakdown: {
        5: json['five_star_count'] ?? 0,
        4: json['four_star_count'] ?? 0,
        3: json['three_star_count'] ?? 0,
        2: json['two_star_count'] ?? 0,
        1: json['one_star_count'] ?? 0,
      },
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
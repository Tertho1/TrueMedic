class Review {
  final String id;
  final String doctorId;
  final String patientId;
  final int rating;
  final String? reviewText;
  final bool isAnonymous;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? patientName;
  final String? doctorResponse;
  final int helpfulVotes;
  final int totalVotes;

  Review({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.rating,
    this.reviewText,
    required this.isAnonymous,
    required this.isVerified,
    required this.createdAt,
    required this.updatedAt,
    this.patientName,
    this.doctorResponse,
    this.helpfulVotes = 0,
    this.totalVotes = 0,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'],
      doctorId: json['doctor_id'],
      patientId: json['patient_id'],
      rating: json['rating'],
      reviewText: json['review_text'],
      isAnonymous: json['is_anonymous'] ?? false,
      isVerified: json['is_verified'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      patientName: json['patient_name'],
      doctorResponse: json['doctor_response'],
      helpfulVotes: json['helpful_votes'] ?? 0,
      totalVotes: json['total_votes'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doctor_id': doctorId,
      'patient_id': patientId,
      'rating': rating,
      'review_text': reviewText,
      'is_anonymous': isAnonymous,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
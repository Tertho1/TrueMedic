import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review.dart';
import '../models/review_stats.dart';

class ReviewService {
  final _supabase = Supabase.instance.client;

  // Get reviews for a doctor
  Future<List<Review>> getDoctorReviews(String doctorId, {
    int limit = 10,
    int offset = 0,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    final response = await _supabase
        .from('reviews')
        .select('''
          *,
          users!reviews_patient_id_fkey(full_name)
        ''')
        .eq('doctor_id', doctorId)
        .order(orderBy, ascending: ascending)
        .range(offset, offset + limit - 1);

    return response.map((json) {
      json['patient_name'] = json['users']?['full_name'];
      return Review.fromJson(json);
    }).toList();
  }

  // Get review stats for a doctor
  Future<ReviewStats?> getDoctorReviewStats(String doctorId) async {
    final response = await _supabase
        .from('doctor_review_stats')
        .select()
        .eq('doctor_id', doctorId)
        .maybeSingle();

    if (response != null) {
      return ReviewStats.fromJson(response);
    }
    return null;
  }

  // Submit a review
  Future<Review> submitReview({
    required String doctorId,
    required String patientId,
    required int rating,
    String? reviewText,
    bool isAnonymous = false,
  }) async {
    // 🛡️ ANTI-SPAM: Check if user has already reviewed this doctor
    final existingReview = await _supabase
        .from('reviews')
        .select('id')
        .eq('doctor_id', doctorId)
        .eq('patient_id', patientId)
        .maybeSingle();

    if (existingReview != null) {
      throw Exception('You have already reviewed this doctor. You can edit your existing review instead.');
    }

    final reviewData = {
      'doctor_id': doctorId,
      'patient_id': patientId,
      'rating': rating,
      'review_text': reviewText,
      'is_anonymous': isAnonymous,
    };

    final response = await _supabase
        .from('reviews')
        .insert(reviewData)
        .select()
        .single();

    // Update review stats
    await _updateReviewStats(doctorId);

    return Review.fromJson(response);
  }

  // Update review stats
  Future<void> _updateReviewStats(String doctorId) async {
    final reviews = await _supabase
        .from('reviews')
        .select('rating')
        .eq('doctor_id', doctorId);

    if (reviews.isEmpty) return;

    final totalReviews = reviews.length;
    final averageRating = reviews
        .map((r) => r['rating'] as int)
        .reduce((a, b) => a + b) / totalReviews;

    final ratingCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final review in reviews) {
      ratingCounts[review['rating'] as int] = 
          (ratingCounts[review['rating'] as int] ?? 0) + 1;
    }

    final statsData = {
      'doctor_id': doctorId,
      'total_reviews': totalReviews,
      'average_rating': averageRating,
      'one_star_count': ratingCounts[1],
      'two_star_count': ratingCounts[2],
      'three_star_count': ratingCounts[3],
      'four_star_count': ratingCounts[4],
      'five_star_count': ratingCounts[5],
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _supabase
        .from('doctor_review_stats')
        .upsert(statsData);
  }

  // Check if user has already reviewed a doctor
  Future<bool> hasUserReviewed(String doctorId, String patientId) async {
    final response = await _supabase
        .from('reviews')
        .select('id')
        .eq('doctor_id', doctorId)
        .eq('patient_id', patientId)
        .maybeSingle();

    return response != null;
  }

  // Get user's reviews
  Future<List<Review>> getUserReviews(String userId) async {
    final response = await _supabase
        .from('reviews')
        .select('''
          *,
          doctors!reviews_doctor_id_fkey(full_name)
        ''')
        .eq('patient_id', userId)
        .order('created_at', ascending: false);

    return response.map((json) {
      json['doctor_name'] = json['doctors']?['full_name'];
      return Review.fromJson(json);
    }).toList();
  }

  // Update a review
  Future<Review> updateReview(
    String reviewId,
    String patientId, {
    required int rating,
    String? reviewText,
    bool? isAnonymous,
  }) async {
    final updateData = {
      'rating': rating,
      'review_text': reviewText,
      'is_anonymous': isAnonymous,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await _supabase
        .from('reviews')
        .update(updateData)
        .eq('id', reviewId)
        .eq('patient_id', patientId)
        .select()
        .single();

    return Review.fromJson(response);
  }

  // Delete a review
  Future<void> deleteReview(String reviewId, String patientId) async {
    await _supabase
        .from('reviews')
        .delete()
        .eq('id', reviewId)
        .eq('patient_id', patientId);
  }
}
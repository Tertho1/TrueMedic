import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review.dart';
import '../models/review_stats.dart';

class ReviewService {
  final _supabase = Supabase.instance.client;

  // Get reviews for a doctor
  Future<List<Review>> getDoctorReviews(
    String doctorId, {
    int limit = 10,
    int offset = 0,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      // Get reviews without joins first
      final reviewsResponse = await _supabase
          .from('reviews')
          .select('*')
          .eq('doctor_id', doctorId)
          .order(orderBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      // Process each review and fetch patient names separately
      final List<Review> reviews = [];

      for (var reviewJson in reviewsResponse) {
        String patientName = 'Anonymous User';

        // Only fetch patient name if review is not anonymous
        if (reviewJson['is_anonymous'] != true &&
            reviewJson['patient_id'] != null) {
          try {
            final userResponse =
                await _supabase
                    .from('users')
                    .select('full_name')
                    .eq('id', reviewJson['patient_id'])
                    .maybeSingle();

            if (userResponse != null && userResponse['full_name'] != null) {
              patientName = userResponse['full_name'];
            }
          } catch (e) {
            print('Error fetching patient name: $e');
          }
        }

        reviewJson['patient_name'] = patientName;
        reviewJson['doctor_name'] = null; // Not needed for doctor reviews

        reviews.add(Review.fromJson(reviewJson));
      }

      return reviews;
    } catch (e) {
      print('Error in getDoctorReviews: $e');
      rethrow;
    }
  }

  // Get review stats for a doctor
  Future<ReviewStats?> getDoctorReviewStats(String doctorId) async {
    final response =
        await _supabase
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
    final existingReview =
        await _supabase
            .from('reviews')
            .select('id')
            .eq('doctor_id', doctorId)
            .eq('patient_id', patientId)
            .maybeSingle();

    if (existingReview != null) {
      throw Exception(
        'You have already reviewed this doctor. You can edit your existing review instead.',
      );
    }

    final reviewData = {
      'doctor_id': doctorId,
      'patient_id': patientId,
      'rating': rating,
      'review_text': reviewText,
      'is_anonymous': isAnonymous,
    };

    final response =
        await _supabase.from('reviews').insert(reviewData).select().single();

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
    final averageRating =
        reviews.map((r) => r['rating'] as int).reduce((a, b) => a + b) /
        totalReviews;

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

    await _supabase.from('doctor_review_stats').upsert(statsData);
  }

  // Check if user has already reviewed a doctor
  Future<bool> hasUserReviewed(String doctorId, String patientId) async {
    final response =
        await _supabase
            .from('reviews')
            .select('id')
            .eq('doctor_id', doctorId)
            .eq('patient_id', patientId)
            .maybeSingle();

    return response != null;
  }

  // Get user's reviews
  Future<List<Review>> getUserReviews(String userId) async {
    try {
      print('🔍 =================== USER REVIEWS DEBUG ===================');
      print('🔍 Fetching reviews for user: $userId');

      // First, get the reviews without joins
      final reviewsResponse = await _supabase
          .from('reviews')
          .select('*')
          .eq('patient_id', userId)
          .order('created_at', ascending: false);

      print('✅ Found ${reviewsResponse.length} reviews');

      if (reviewsResponse.isEmpty) {
        return [];
      }

      // Process each review and fetch doctor names separately
      final List<Review> reviews = [];

      for (var reviewJson in reviewsResponse) {
        String doctorName = 'Unknown Doctor';
        String patientName = 'You';

        // Fetch doctor name using doctor_id
        if (reviewJson['doctor_id'] != null) {
          try {
            print('🔍 Fetching doctor name for ID: ${reviewJson['doctor_id']}');

            final doctorResponse =
                await _supabase
                    .from('doctors')
                    .select('full_name')
                    .eq('id', reviewJson['doctor_id'])
                    .maybeSingle();

            if (doctorResponse != null && doctorResponse['full_name'] != null) {
              doctorName = doctorResponse['full_name'];
              print('✅ Found doctor: $doctorName');
            } else {
              print('⚠️ Doctor not found for ID: ${reviewJson['doctor_id']}');
            }
          } catch (e) {
            print('⚠️ Error fetching doctor name: $e');
          }
        }

        // Fetch patient name (current user)
        try {
          final userResponse =
              await _supabase
                  .from('users')
                  .select('full_name')
                  .eq('id', userId)
                  .maybeSingle();

          if (userResponse != null && userResponse['full_name'] != null) {
            patientName = userResponse['full_name'];
          }
        } catch (e) {
          print('⚠️ Error fetching user name: $e');
        }

        // Add the names to the review JSON
        reviewJson['doctor_name'] = doctorName;
        reviewJson['patient_name'] = patientName;

        print(
          '🔍 Processing review: ${reviewJson['id']} for doctor: $doctorName',
        );

        reviews.add(Review.fromJson(reviewJson));
      }

      print(
        '✅ Successfully processed ${reviews.length} reviews with doctor names',
      );
      return reviews;
    } catch (e) {
      print('💥 Error in getUserReviews: $e');
      print('💥 Error type: ${e.runtimeType}');
      rethrow;
    }
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

    final response =
        await _supabase
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

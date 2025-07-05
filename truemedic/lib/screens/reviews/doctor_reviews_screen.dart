import 'package:flutter/material.dart';
import '../../services/review_service.dart';
import '../../models/review.dart';
import '../../models/review_stats.dart';
import 'write_review_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorReviewsScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const DoctorReviewsScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<DoctorReviewsScreen> createState() => _DoctorReviewsScreenState();
}

class _DoctorReviewsScreenState extends State<DoctorReviewsScreen> {
  final _reviewService = ReviewService();
  List<Review> _reviews = [];
  ReviewStats? _reviewStats;
  bool _isLoading = true;
  String _sortBy = 'created_at';
  bool _ascending = false;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);

    try {
      final reviews = await _reviewService.getDoctorReviews(
        widget.doctorId,
        orderBy: _sortBy,
        ascending: _ascending,
      );

      final stats = await _reviewService.getDoctorReviewStats(widget.doctorId);

      setState(() {
        _reviews = reviews;
        _reviewStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading reviews: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.doctorName} Reviews'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                switch (value) {
                  case 'newest':
                    _sortBy = 'created_at';
                    _ascending = false;
                    break;
                  case 'oldest':
                    _sortBy = 'created_at';
                    _ascending = true;
                    break;
                  case 'highest':
                    _sortBy = 'rating';
                    _ascending = false;
                    break;
                  case 'lowest':
                    _sortBy = 'rating';
                    _ascending = true;
                    break;
                }
              });
              _loadReviews();
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'newest',
                    child: Text('Newest First'),
                  ),
                  const PopupMenuItem(
                    value: 'oldest',
                    child: Text('Oldest First'),
                  ),
                  const PopupMenuItem(
                    value: 'highest',
                    child: Text('Highest Rating'),
                  ),
                  const PopupMenuItem(
                    value: 'lowest',
                    child: Text('Lowest Rating'),
                  ),
                ],
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadReviews,
                child: Column(
                  children: [
                    // Review statistics
                    if (_reviewStats != null) _buildReviewStats(),

                    // Reviews list
                    Expanded(
                      child:
                          _reviews.isEmpty
                              ? const Center(
                                child: Text(
                                  'No reviews yet\nBe the first to review this doctor!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                              : ListView.builder(
                                itemCount: _reviews.length,
                                itemBuilder: (context, index) {
                                  return _buildReviewCard(_reviews[index]);
                                },
                              ),
                    ),
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToWriteReview,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.rate_review),
        label: const Text('Write Review'),
      ),
    );
  }

  Widget _buildReviewStats() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Column(
                  children: [
                    Text(
                      _reviewStats!.averageRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    _buildStarRating(_reviewStats!.averageRating),
                    Text(
                      '${_reviewStats!.totalReviews} reviews',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    children: [
                      for (int i = 5; i >= 1; i--)
                        _buildRatingBar(
                          i,
                          _reviewStats!.ratingBreakdown[i] ?? 0,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 20,
        );
      }),
    );
  }

  Widget _buildRatingBar(int stars, int count) {
    final percentage =
        _reviewStats!.totalReviews > 0
            ? count / _reviewStats!.totalReviews
            : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$stars'),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade400),
            ),
          ),
          const SizedBox(width: 8),
          Text('$count'),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Text(
                    // Use doctorName for the avatar initial
                    (review.doctorName ?? review.patientName ?? 'D')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // ✅ FIX: Use doctorName instead of patientName
                        review.doctorName ?? review.patientName ?? 'Unknown Doctor',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          _buildStarRating(review.rating.toDouble()),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(review.createdAt),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editReview(review);
                    } else if (value == 'delete') {
                      _deleteReview(review);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (review.reviewText != null && review.reviewText!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                review.reviewText!,
                style: const TextStyle(fontSize: 14),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (review.isAnonymous)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Anonymous',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                const Spacer(),
                if (review.helpfulVotes > 0)
                  Row(
                    children: [
                      Icon(Icons.thumb_up, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${review.helpfulVotes} helpful',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _navigateToWriteReview() {
    // Check if user is logged in
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentUser == null) {
      _showLoginPrompt();
      return;
    }

    // 🛡️ Check if user already reviewed this doctor
    _checkAndNavigateToReview();
  }

  // Add this method
  Future<void> _checkAndNavigateToReview() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final hasReviewed = await _reviewService.hasUserReviewed(
        widget.doctorId,
        userId,
      );

      if (hasReviewed) {
        _showExistingReviewDialog();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => WriteReviewScreen(
                  doctorId: widget.doctorId,
                  doctorName: widget.doctorName,
                ),
          ),
        ).then((result) {
          if (result == true) {
            _loadReviews();
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  void _showExistingReviewDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Review Already Exists'),
            content: const Text(
              'You have already reviewed this doctor. Would you like to edit your existing review?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/user-reviews');
                },
                child: const Text('Edit My Review'),
              ),
            ],
          ),
    );
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Login Required'),
            content: const Text('You need to be logged in to write a review.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/user-login');
                },
                child: const Text('Login'),
              ),
            ],
          ),
    );
  }

  void _editReview(Review review) {
    // Only allow users to edit their own reviews
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId != review.patientId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only edit your own reviews')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WriteReviewScreen(
          doctorId: review.doctorId,
          doctorName: widget.doctorName,
          existingReview: review,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadReviews(); // Refresh reviews after editing
      }
    });
  }

  Future<void> _deleteReview(Review review) async {
    // Only allow users to delete their own reviews
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId != review.patientId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only delete your own reviews')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _reviewService.deleteReview(review.id, currentUserId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadReviews(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting review: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

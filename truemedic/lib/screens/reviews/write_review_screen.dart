import 'package:flutter/material.dart';
import '../../services/review_service.dart';
import '../../models/review.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class WriteReviewScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final Review? existingReview;

  const WriteReviewScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
    this.existingReview,
  });

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final _reviewService = ReviewService();
  final _textController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _rating = 0;
  bool _isAnonymous = false;
  bool _isLoading = false;
  bool _hasExistingReview = false; // Add this

  @override
  void initState() {
    super.initState();
    if (widget.existingReview != null) {
      _rating = widget.existingReview!.rating;
      _textController.text = widget.existingReview!.reviewText ?? '';
      _isAnonymous = widget.existingReview!.isAnonymous;
    } else {
      // 🛡️ Check if user already has a review for this doctor
      _checkExistingReview();
    }
  }

  // Add this method
  Future<void> _checkExistingReview() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final hasReviewed = await _reviewService.hasUserReviewed(
        widget.doctorId,
        userId,
      );

      if (mounted) {
        setState(() {
          _hasExistingReview = hasReviewed;
        });

        if (hasReviewed) {
          // Show dialog and navigate back
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showExistingReviewDialog();
          });
        }
      }
    } catch (e) {
      print('Error checking existing review: $e'); // Keep this print for debugging
    }
  }

  void _showExistingReviewDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Review Already Exists'),
            content: const Text(
              'You have already reviewed this doctor. You can only submit one review per doctor.\n\n'
              'To update your review, go to "My Reviews" and edit your existing review.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to previous screen
                },
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back
                  // Navigate to user reviews
                  Navigator.pushNamed(context, '/user-reviews');
                },
                child: const Text('View My Reviews'),
              ),
            ],
          ),
    );
  }

  Future<void> _submitReview() async {
    // Prevent submission if user already has a review (double-check)
    if (_hasExistingReview && widget.existingReview == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already reviewed this doctor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate() || _rating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please provide a rating')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      if (widget.existingReview != null) {
        // Update existing review
        await _reviewService.updateReview(
          widget.existingReview!.id,
          userId,
          rating: _rating,
          reviewText: _textController.text.trim(),
          isAnonymous: _isAnonymous,
        );
      } else {
        // Submit new review (with built-in duplicate check)
        await _reviewService.submitReview(
          doctorId: widget.doctorId,
          patientId: userId,
          rating: _rating,
          reviewText: _textController.text.trim(),
          isAnonymous: _isAnonymous,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingReview != null
                  ? 'Review updated successfully'
                  : 'Review submitted successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();

        // Handle specific duplicate review error
        if (errorMessage.contains('already reviewed')) {
          errorMessage =
              'You have already reviewed this doctor. Please edit your existing review instead.';

          // Update local state
          setState(() {
            _hasExistingReview = true;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingReview != null ? 'Edit Review' : 'Write Review',
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.teal,
                        child: Text(
                          widget.doctorName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.doctorName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Rate your experience',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Rating section
              const Text(
                'Rating *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () => setState(() => _rating = index + 1),
                    child: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 40,
                    ),
                  );
                }),
              ),
              if (_rating > 0) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _getRatingText(_rating),
                    style: TextStyle(
                      fontSize: 16,
                      color: _getRatingColor(_rating),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Review text
              const Text(
                'Review (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _textController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Share your experience with this doctor...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value != null &&
                      value.trim().isNotEmpty &&
                      value.trim().length < 10) {
                    return 'Review must be at least 10 characters long';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Anonymous option
              CheckboxListTile(
                title: const Text('Submit anonymously'),
                subtitle: const Text(
                  'Your name will not be shown with this review',
                ),
                value: _isAnonymous,
                onChanged:
                    (value) => setState(() => _isAnonymous = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),

              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                            widget.existingReview != null
                                ? 'Update Review'
                                : 'Submit Review',
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.amber;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

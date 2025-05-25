import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AllReviewsTranslations {
  static const Map<String, Map<String, String>> translations = {
    'en': {
      'reviewsFor': 'Reviews for',
      'editReview': 'Edit Review',
      'updateReviewHint': 'Update your review...',
      'cancel': 'Cancel',
      'save': 'Save',
      'reviewUpdated': 'Review updated successfully!',
      'errorUpdating': 'Error updating review:',
      'noReviews': 'No reviews yet',
      'anonymous': 'Anonymous',
      'editReviewOption': 'Edit Review',
      'canEditUntil': 'You can edit this review until',
    },
    'zh': {
      'reviewsFor': '评价',
      'editReview': '编辑评价',
      'updateReviewHint': '更新您的评价...',
      'cancel': '取消',
      'save': '保存',
      'reviewUpdated': '评价更新成功！',
      'errorUpdating': '更新评价时出错：',
      'noReviews': '暂无评价',
      'anonymous': '匿名',
      'editReviewOption': '编辑评价',
      'canEditUntil': '您可以编辑此评价直到',
    },
  };

  static String getText(BuildContext context, String key) {
    final locale = Localizations.localeOf(context).languageCode;
    return translations[locale]?[key] ?? translations['en']![key]!;
  }
}

class AllReviewsPage extends StatelessWidget {
  final String hotelId;
  final String hotelName;
  final String currentUserId;

  const AllReviewsPage({
    Key? key,
    required this.hotelId,
    required this.hotelName,
    required this.currentUserId,
  }) : super(key: key);

  bool _canEditReview(Timestamp timestamp) {
    final reviewTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(reviewTime);
    return difference.inHours <= 24;
  }

  Future<void> _showEditReviewDialog(
    BuildContext context,
    String reviewId,
    num currentRating,
    String currentReview,
  ) async {
    double newRating = currentRating.toDouble();
    final reviewController = TextEditingController(text: currentReview);

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(AllReviewsTranslations.getText(context, 'editReview')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < newRating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                          ),
                          onPressed: () {
                            setState(() {
                              newRating = index + 1.0;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reviewController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: AllReviewsTranslations.getText(context, 'updateReviewHint'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text(AllReviewsTranslations.getText(context, 'cancel')),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text(AllReviewsTranslations.getText(context, 'save')),
                  onPressed: () async {
                    try {
                      await FirebaseFirestore.instance
                          .collection('reviews')
                          .doc(reviewId)
                          .update({
                        'rating': newRating,
                        'review': reviewController.text.trim(),
                      });

                      final hotelRef = FirebaseFirestore.instance.collection('hotels').doc(hotelId);
                      await FirebaseFirestore.instance.runTransaction((transaction) async {
                        final hotelDoc = await transaction.get(hotelRef);
                        if (!hotelDoc.exists) return;

                        final reviews = await FirebaseFirestore.instance
                            .collection('reviews')
                            .where('hotelId', isEqualTo: hotelId)
                            .get();

                        double totalRating = 0;
                        for (var doc in reviews.docs) {
                          totalRating += (doc.data()['rating'] as num).toDouble();
                        }

                        final newAverageRating = totalRating / reviews.docs.length;
                        transaction.update(hotelRef, {
                          'averageRating': newAverageRating,
                        });
                      });

                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AllReviewsTranslations.getText(context, 'reviewUpdated'))),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${AllReviewsTranslations.getText(context, 'errorUpdating')} $e')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.blue[800]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${AllReviewsTranslations.getText(context, 'reviewsFor')} $hotelName",
          style: TextStyle(
            color: Colors.blue[800],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reviews')
            .where('hotelId', isEqualTo: hotelId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final reviews = snapshot.data?.docs ?? [];

          if (reviews.isEmpty) {
            return Center(
              child: Text(AllReviewsTranslations.getText(context, 'noReviews')),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index].data() as Map<String, dynamic>;
              final reviewId = reviews[index].id;
              final timestamp = review['timestamp'] as Timestamp;
              final isCurrentUserReview = review['userId'] == currentUserId;
              final canEdit = isCurrentUserReview && _canEditReview(timestamp);

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            review['userName'] ?? AllReviewsTranslations.getText(context, 'anonymous'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (canEdit)
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditReviewDialog(
                                    context,
                                    reviewId,
                                    review['rating'] as num,
                                    review['review'] as String,
                                  );
                                }
                              },
                              itemBuilder: (BuildContext context) => [
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Text(AllReviewsTranslations.getText(context, 'editReviewOption')),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (i) {
                          return Icon(
                            i < (review['rating'] as num) ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 20,
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(review['review'] as String),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('MMM d, yyyy, h:mm a').format(timestamp.toDate()),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      if (canEdit)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${AllReviewsTranslations.getText(context, 'canEditUntil')} ${DateFormat('MMM d, yyyy, h:mm a').format(timestamp.toDate().add(const Duration(hours: 24)))}',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
} 
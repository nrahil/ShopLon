import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/product_model.dart';

class ProductReviewsScreen extends StatelessWidget {
  const ProductReviewsScreen({super.key, this.product});

  final ProductModel? product;

  static String _formatDate(DateTime? date) {
    if (date == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final reviews = product?.reviews ?? const <ReviewModel>[];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Reviews")),
      body: reviews.isEmpty
          ? const Center(child: Text("No reviews yet"))
          : ListView.separated(
              padding: const EdgeInsets.all(defaultPadding),
              itemCount: reviews.length + 1,
              separatorBuilder: (_, __) =>
                  const Divider(height: defaultPadding * 2),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Row(
                    children: [
                      Text(
                        product!.rating.toStringAsFixed(1),
                        style: theme.textTheme.headlineMedium!
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: defaultPadding),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RatingBarIndicator(
                              rating: product!.rating,
                              itemSize: 20,
                              itemBuilder: (_, __) => const Icon(
                                  Icons.star_rounded,
                                  color: warningColor),
                            ),
                            Text("Based on ${reviews.length} reviews"),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                final review = reviews[index - 1];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: primaryColor.withValues(alpha: 0.1),
                          child: Text(
                            review.reviewerName.isNotEmpty
                                ? review.reviewerName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: primaryColor),
                          ),
                        ),
                        const SizedBox(width: defaultPadding / 2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(review.reviewerName,
                                  style: theme.textTheme.titleSmall),
                              Text(_formatDate(review.date),
                                  style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        RatingBarIndicator(
                          rating: review.rating.toDouble(),
                          itemSize: 16,
                          itemBuilder: (_, __) => const Icon(Icons.star_rounded,
                              color: warningColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: defaultPadding / 2),
                    Text(review.comment),
                  ],
                );
              },
            ),
    );
  }
}

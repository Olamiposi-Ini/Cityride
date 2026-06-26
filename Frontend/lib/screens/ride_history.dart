import 'dart:convert';
import 'package:cityride/models/ride_model.dart';
import 'package:cityride/services/rideservice.dart';
import 'package:cityride/theme/colors.dart';
import 'package:cityride/utils/format.dart';
import 'package:flutter/material.dart';

Future<void> showRatingSheet(
  BuildContext context,
  RideService rideService,
  String rideId, {
  VoidCallback? onSubmitted,
}) async {
  int selected = 5;
  final commentController = TextEditingController();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.lg,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Rate this trip", style: AppText.h2),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final starIndex = i + 1;
                    return IconButton(
                      onPressed: () => setSheetState(() => selected = starIndex),
                      icon: Icon(
                        starIndex <= selected ? Icons.star : Icons.star_border,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Comment (optional)",
                    hintText: "How was your trip?",
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      final response = await rideService.submitRating(
                        rideId,
                        selected,
                        comment: commentController.text.trim(),
                      );
                      if (response.statusCode == 201) {
                        onSubmitted?.call();
                      }
                    } catch (e) {
                      debugPrint("Submit Rating Error: $e");
                    }
                  },
                  child: const Text("Submit Rating"),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  final RideService _rideService = RideService();
  List<Ride> _rides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final response = await _rideService.getRideHistory();
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded['rides'] ?? [];
        setState(() {
          _rides = data.map((r) => Ride.fromJson(r)).toList();
        });
      }
    } catch (e) {
      debugPrint("Ride History Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final date = DateTime.tryParse(iso);
    if (date == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackgroundGray,
      appBar: AppBar(title: const Text("Trip History")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: _rides.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Icon(Icons.history, size: 44, color: AppColors.muted),
                        SizedBox(height: 16),
                        Center(child: Text("No trips yet", style: AppText.h2)),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: _rides.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final ride = _rides[index];
                        final bool isCompleted = ride.status == 'COMPLETED';
                        return Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            boxShadow: AppShadows.card,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDate(ride.createdAt), style: AppText.caption),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCompleted
                                          ? AppColors.cardFill
                                          : AppColors.errorBackground,
                                      borderRadius: BorderRadius.circular(AppRadius.pill),
                                    ),
                                    child: Text(
                                      ride.status,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isCompleted
                                            ? AppColors.primary
                                            : Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                "${ride.pickupAddress} → ${ride.destinationAddress}",
                                style: AppText.body.copyWith(fontSize: 14),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    ride.fareEstimate != null
                                        ? formatNaira(ride.fareEstimate)
                                        : "",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  if (isCompleted && ride.rating == null)
                                    TextButton(
                                      onPressed: () => showRatingSheet(
                                        context,
                                        _rideService,
                                        ride.id,
                                        onSubmitted: _loadHistory,
                                      ),
                                      child: const Text("Rate this trip"),
                                    )
                                  else if (ride.rating != null)
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text("${ride.rating}", style: AppText.body),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

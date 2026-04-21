import 'package:flutter/material.dart';

import '../services/prediction_service.dart';
import 'empty_state_card.dart';
import 'recent_scan_card.dart';

class RecentScansList extends StatefulWidget {
  final String accessToken;
  final int refreshKey;
  final int maxItems;

  const RecentScansList({
    super.key,
    required this.accessToken,
    required this.refreshKey,
    this.maxItems = 3,
  });

  @override
  State<RecentScansList> createState() => _RecentScansListState();
}

class _RecentScansListState extends State<RecentScansList> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchPredictions();
  }

  @override
  void didUpdateWidget(covariant RecentScansList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey ||
        oldWidget.accessToken != widget.accessToken) {
      _future = _fetchPredictions();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPredictions() async {
    return PredictionService(widget.accessToken).fetchPredictions();
  }

  void _refreshList() {
    setState(() {
      _future = _fetchPredictions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const EmptyStateCard(
            title: 'Unable to load scans',
            subtitle: 'The app could not load your saved scan history.',
            icon: Icons.error_outline,
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const EmptyStateCard(
            title: 'No scans yet',
            subtitle: 'Start scanning to build your history!',
            icon: Icons.history,
          );
        }

        final capped = items.take(widget.maxItems).toList();
        return Column(
          children: [
            for (final item in capped)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: RecentScanCard(
                  item: item,
                  accessToken: widget.accessToken,
                  onDeleted: _refreshList,
                ),
              ),
            if (items.length > capped.length)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Showing ${capped.length} of ${items.length}. Tap “View All” to see more.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ),
          ],
        );
      },
    );
  }
}

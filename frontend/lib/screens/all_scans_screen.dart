import 'package:flutter/material.dart';

import '../services/prediction_service.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/recent_scan_card.dart';

class AllScansScreen extends StatefulWidget {
  final String accessToken;

  const AllScansScreen({super.key, required this.accessToken});

  @override
  State<AllScansScreen> createState() => _AllScansScreenState();
}

class _AllScansScreenState extends State<AllScansScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    return PredictionService(widget.accessToken).fetchPredictions();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All scans'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: EmptyStateCard(
                  title: 'Unable to load scans',
                  subtitle: 'The app could not load your saved scan history.',
                  icon: Icons.error_outline,
                ),
              );
            }

            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: EmptyStateCard(
                  title: 'No scans yet',
                  subtitle: 'Start scanning to build your history!',
                  icon: Icons.history,
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => RecentScanCard(
                item: items[i],
                accessToken: widget.accessToken,
                onDeleted: _reload,
              ),
            );
          },
        ),
      ),
    );
  }
}


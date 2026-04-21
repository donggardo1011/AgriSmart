// lib/widgets/top_stats_row.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import 'stat_card.dart';

class TopStatsRow extends StatelessWidget {
  final String accessToken;

  const TopStatsRow({super.key, required this.accessToken});

  Future<int> _fetchDiseaseCount() async {
    final uri = Uri.parse('$apiBaseUrl/api/diseases/count');
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final v = data['count'];
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _fetchDiseaseCount(),
      builder: (context, snapshot) {
        final count = snapshot.data;
        return Row(
          children: [
            const Expanded(
              flex: 2,
              child: StatCard(
                title: 'AgriBot',
                subtitle: 'AI Assistant',
                highlight: 'Ready',
                color: Color(0xFF22A45D),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'Diseases',
                subtitle: 'Tracked',
                highlight: snapshot.connectionState == ConnectionState.waiting
                    ? '…'
                    : (count ?? 0).toString(),
              ),
            ),
          ],
        );
      },
    );
  }
}

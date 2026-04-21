// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';

import '../screens/chatbot_screen.dart';
import '../screens/all_diseases_screen.dart';
import '../screens/all_scans_screen.dart';
import '../screens/scan_screen.dart';
import '../screens/login_screen.dart';
import '../services/offline_activity_service.dart';
import '../widgets/diseases_grid.dart';
import '../widgets/recent_scans_list.dart';
import '../widgets/section_header.dart';
import '../widgets/top_stats_row.dart';

class DashboardScreen extends StatefulWidget {
  final String? accessToken;
  final bool isGuestMode;
  final VoidCallback onLogout;

  const DashboardScreen({
    super.key,
    required this.accessToken,
    required this.onLogout,
    this.isGuestMode = false,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _refreshCounter = 0;

  @override
  void initState() {
    super.initState();
    // Log dashboard view
    OfflineActivityService.logDashboardView();
  }

  void _refreshScans() {
    setState(() {
      _refreshCounter++;
    });
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onLoggedIn: (token) {
            if (token != null) {
              // User logged in
              Navigator.of(context).pushReplacementNamed('/');
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF22A45D),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.agriculture_outlined,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AgriSmart',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.isGuestMode
                      ? 'Guest Mode (Offline)'
                      : 'Rice Disease Detector',
                  style: textTheme.bodySmall?.copyWith(
                    color: widget.isGuestMode ? Colors.orange : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (widget.accessToken != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ChatbotScreen(accessToken: widget.accessToken!),
                  ),
                );
              },
            ),
          if (widget.isGuestMode)
            IconButton(
              icon: const Icon(Icons.login),
              tooltip: 'Log In',
              onPressed: _goToLogin,
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: widget.onLogout,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Guest mode warning
              if (widget.isGuestMode) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha((0.06 * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withAlpha((0.3 * 255).round()),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You are in guest mode. Log in to sync your activities and access all features.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.orange[700],
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.accessToken != null)
                TopStatsRow(accessToken: widget.accessToken!),
              if (widget.accessToken != null)
                const SizedBox(height: 24),
              SectionHeader(
                title: 'Types of Rice Diseases',
                actionText: 'View All',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AllDiseasesScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              const DiseasesGrid(),
              const SizedBox(height: 24),
              SectionHeader(
                title: 'Recent Scans',
                actionText: 'View All',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AllScansScreen(
                        accessToken: widget.accessToken ?? '',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              RecentScansList(
                accessToken: widget.accessToken ?? '',
                refreshKey: _refreshCounter,
                maxItems: 3,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => ScanScreen(accessToken: widget.accessToken ?? ''),
            ),
          );
          if (created == true) {
            _refreshScans();
          }
        },
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('Scan Leaf'),
      ),
    );
  }
}

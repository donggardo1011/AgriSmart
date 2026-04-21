import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/admin_insights_service.dart';

class AdminActivitiesScreen extends StatefulWidget {
  final String accessToken;

  const AdminActivitiesScreen({super.key, required this.accessToken});

  @override
  State<AdminActivitiesScreen> createState() => _AdminActivitiesScreenState();
}

class _AdminActivitiesScreenState extends State<AdminActivitiesScreen> {
  final _service = AdminInsightsService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.listActivities(token: widget.accessToken);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatActionDescription(String action, String? detail) {
    try {
      final detailObj = detail != null && detail.isNotEmpty ? jsonDecode(detail) : {};
      
      switch (action) {
        case 'auth.register':
          return "Registered account";
        case 'auth.login':
          return "Logged in";
        case 'auth.logout':
          return "Logged out";
        case 'user.update_profile':
          return "Updated profile";
        case 'user.change_password':
          return "Changed password";
        case 'dataset.upload':
          final datasetName = detailObj['dataset_name'] ?? 'Unknown dataset';
          return "Uploaded dataset: $datasetName";
        case 'dataset.delete':
          final datasetName = detailObj['dataset_name'] ?? 'Unknown dataset';
          return "Deleted dataset: $datasetName";
        case 'dataset.process':
          return "Processed dataset";
        case 'model.train':
          final modelName = detailObj['model_name'] ?? 'Unknown model';
          final epochs = detailObj['epochs'] ?? 'N/A';
          return "Trained model: $modelName ($epochs epochs)";
        case 'model.export':
          final modelName = detailObj['model_name'] ?? 'Unknown model';
          final format = detailObj['format'] ?? 'Unknown format';
          return "Exported model: $modelName ($format)";
        case 'model.delete':
          final modelName = detailObj['model_name'] ?? 'Unknown model';
          return "Deleted model: $modelName";
        case 'prediction.create':
          final imageCount = detailObj['image_count'] ?? 1;
          return "Created $imageCount prediction(s)";
        case 'admin.user_role_change':
          final targetUser = detailObj['target_user'] ?? 'Unknown user';
          final newRole = detailObj['new_role'] ?? 'Unknown role';
          return "Changed role for $targetUser to $newRole";
        case 'admin.user_deactivate':
          final targetUser = detailObj['target_user'] ?? 'Unknown user';
          return "Deactivated user: $targetUser";
        case 'admin.user_activate':
          final targetUser = detailObj['target_user'] ?? 'Unknown user';
          return "Activated user: $targetUser";
        case 'backup.create':
          return "Created backup";
        case 'backup.restore':
          return "Restored from backup";
        default:
          return action;
      }
    } catch (_) {
      return action;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Activities'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha((0.06 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: textTheme.bodySmall?.copyWith(color: Colors.red[700]),
                      ),
                    )
                  : _items.isEmpty
                      ? const Center(child: Text('No activity yet.'))
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final it = _items[i];
                            final action = it['action']?.toString() ?? '';
                            final username = it['username']?.toString() ?? 'Unknown user';
                            final email = it['email']?.toString() ?? '';
                            final userId = it['user_id'];
                            final createdAt = it['created_at']?.toString() ?? '';
                            final detailStr = it['detail']?.toString();
                            final formattedAction = _formatActionDescription(action, detailStr);
                            
                            final userInfo = email.isNotEmpty ? '$username ($email)' : username;

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha((0.04 * 255).round()),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                title: Text(
                                  formattedAction,
                                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.black87),
                                ),
                                subtitle: Text(
                                  '$userInfo\n$createdAt',
                                  style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                                ),
                                isThreeLine: false,
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}


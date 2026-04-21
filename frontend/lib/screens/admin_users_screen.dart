import 'package:flutter/material.dart';

import '../services/admin_insights_service.dart';

class AdminUsersScreen extends StatefulWidget {
  final String accessToken;

  const AdminUsersScreen({super.key, required this.accessToken});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _service = AdminInsightsService();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _counts;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final counts = await _service.userCount(token: widget.accessToken);
      final users = await _service.listUsers(
        token: widget.accessToken,
        q: _searchCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _counts = counts;
        _users = users;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Users'),
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
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search username or email',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _load(),
              ),
              const SizedBox(height: 12),
              if (_counts != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withAlpha((0.15 * 255).round()),
                    ),
                  ),
                  child: Text(
                    'Total: ${_counts!['total'] ?? 0} • '
                    'Active: ${_counts!['active'] ?? 0} • '
                    'Admins: ${_counts!['admins'] ?? 0}',
                    style: textTheme.bodySmall,
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
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
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        itemCount: _users.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final u = _users[i];
                          final username = u['username']?.toString() ?? '';
                          final email = u['email']?.toString() ?? '';
                          final role = u['role']?.toString() ?? 'user';
                          final createdAt = u['created_at']?.toString();

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
                              leading: CircleAvatar(
                                backgroundColor: role == 'admin'
                                    ? Colors.amber.withAlpha((0.16 * 255).round())
                                    : Colors.blue.withAlpha((0.12 * 255).round()),
                                child: Icon(
                                  role == 'admin'
                                      ? Icons.admin_panel_settings_outlined
                                      : Icons.person_outline,
                                  color: role == 'admin' ? Colors.amber[800] : Colors.blue[700],
                                ),
                              ),
                              title: Text(
                                username,
                                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text('$email${createdAt == null ? '' : '\n$createdAt'}'),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: role == 'admin'
                                      ? Colors.amber.withAlpha((0.16 * 255).round())
                                      : Colors.grey.withAlpha((0.10 * 255).round()),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(role, style: textTheme.labelMedium),
                              ),
                              isThreeLine: createdAt != null,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


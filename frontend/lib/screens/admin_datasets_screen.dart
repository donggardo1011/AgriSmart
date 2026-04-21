import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/admin_dataset_service.dart';
import '../screens/admin_users_screen.dart';
import '../screens/admin_activities_screen.dart';
import '../core/network.dart';

class AdminDatasetsScreen extends StatefulWidget {
  final String accessToken;

  const AdminDatasetsScreen({super.key, required this.accessToken});

  @override
  State<AdminDatasetsScreen> createState() => _AdminDatasetsScreenState();
}

class _AdminDatasetsScreenState extends State<AdminDatasetsScreen> {
  final _service = AdminDatasetService();
  final _picker = ImagePicker();

  final _searchCtrl = TextEditingController();
  String? _split;
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _stats;

  static const Map<String, String> _labelNames = {
    'bacterial_blight': 'Bacterial Blight',
    'brown_spot': 'Brown Spot',
    'leaf_blast': 'Leaf Blast',
    'sheath_blight': 'Sheath Blight',
    'smut': 'Sheath Blight',
    'tungro': 'Tungro',
  };

  String _displayLabel(String key) => _labelNames[key] ?? key;

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
      final items = await _service.list(
        token: widget.accessToken,
        q: _searchCtrl.text,
        split: _split,
      );
      final stats = await _service.stats(token: widget.accessToken);
      if (!mounted) return;
      setState(() {
        _items = items;
        _stats = stats;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openUpload() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;

    if (!mounted) return;
    final res = await showDialog<_UploadFormResult>(
      context: context,
      builder: (ctx) => _UploadDialog(),
    );
    if (res == null) return;

    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      await _service.upload(
        token: widget.accessToken,
        imagePath: picked.path,
        label: res.label,
        split: res.split,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete dataset item?'),
        content: const Text('This will remove the record and the image file on the server.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      await _service.delete(token: widget.accessToken, id: id);
      await _load();
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
        title: const Text('Admin • Datasets'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'users') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminUsersScreen(accessToken: widget.accessToken),
                  ),
                );
              } else if (value == 'activities') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminActivitiesScreen(accessToken: widget.accessToken),
                  ),
                );
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'users', child: Text('Users')),
              PopupMenuItem(value: 'activities', child: Text('Activities')),
            ],
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _openUpload,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search label',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _load(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      initialValue: _split,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All splits')),
                        DropdownMenuItem(value: 'train', child: Text('train')),
                        DropdownMenuItem(value: 'val', child: Text('val')),
                        DropdownMenuItem(value: 'test', child: Text('test')),
                      ],
                      onChanged: (v) {
                        setState(() => _split = v);
                        _load();
                      },
                      decoration: const InputDecoration(
                        labelText: 'Split',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_stats != null)
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
                    'Total: ${_stats!['total'] ?? 0} • '
                    'Splits: ${(_stats!['by_split'] as Map?)?.toString() ?? '{}'}',
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
                    : _items.isEmpty
                        ? const Center(child: Text('No dataset items yet.'))
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final it = _items[i];
                              final id = (it['id'] as num).toInt();
                              final label = it['label']?.toString() ?? 'Unknown';
                              final split = it['split']?.toString() ?? 'train';
                              final createdAt = it['created_at']?.toString();
                              final rawImageUrl = it['image_url']?.toString();
                              final imageUrl = (rawImageUrl == null || rawImageUrl.isEmpty)
                                  ? null
                                  : normalizeApiUrl(rawImageUrl);

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
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: imageUrl == null
                                        ? Container(
                                            width: 54,
                                            height: 54,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.image_not_supported),
                                          )
                                        : Image.network(
                                            imageUrl,
                                            width: 54,
                                            height: 54,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  title: Text(
                                    _displayLabel(label),
                                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Text('Split: $split${createdAt == null ? '' : ' • $createdAt'}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _delete(id),
                                  ),
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

class _UploadFormResult {
  final String label;
  final String split;

  const _UploadFormResult({required this.label, required this.split});
}

class _UploadDialog extends StatefulWidget {
  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  final _formKey = GlobalKey<FormState>();
  static const _labelOptions = [
    ('bacterial_blight', 'Rice Leaf Blight Disease'),
    ('brown_spot', 'Rice Leaf Brown-Spot Disease'),
    ('leaf_blast', 'Rice Leaf Blast Disease'),
    ('smut', 'Rice Leaf Smut Disease'),
    ('tungro', 'Rice Leaf Tungro Disease'),
  ];

  String _label = 'bacterial_blight';
  String _split = 'train';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload dataset image'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _label,
              items: _labelOptions
                  .map(
                    (option) => DropdownMenuItem(
                      value: option.$1,
                      child: Text(option.$2),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _label = v ?? 'bacterial_blight'),
              decoration: const InputDecoration(
                labelText: 'Disease label',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _split,
              items: const [
                DropdownMenuItem(value: 'train', child: Text('train')),
                DropdownMenuItem(value: 'val', child: Text('val')),
                DropdownMenuItem(value: 'test', child: Text('test')),
              ],
              onChanged: (v) => setState(() => _split = v ?? 'train'),
              decoration: const InputDecoration(
                labelText: 'Split',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _UploadFormResult(label: _label, split: _split),
            );
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}


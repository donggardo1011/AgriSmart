// lib/widgets/recent_scan_card.dart
import 'dart:io';

import 'package:flutter/material.dart';
import '../screens/scan_detail_screen.dart';
import '../services/prediction_service.dart';
import '../services/scan_cache_service.dart';
import '../core/network.dart';

class RecentScanCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final String? accessToken;
  final VoidCallback? onDeleted;

  const RecentScanCard({
    super.key,
    required this.item,
    this.accessToken,
    this.onDeleted,
  });

  @override
  State<RecentScanCard> createState() => _RecentScanCardState();
}

class _RecentScanCardState extends State<RecentScanCard> {
  bool _isDeleting = false;

  String _titleFromKey(String key) {
    final k = key.trim().toLowerCase();
    switch (k) {
      case 'bacterial_blight':
        return 'Bacterial Blight';
      case 'brown_spot':
        return 'Brown Spot';
      case 'leaf_blast':
        return 'Leaf Blast';
      case 'sheath_blight':
      case 'smut':
        return 'Sheath Blight';
      case 'tungro':
        return 'Tungro';
      default:
        return key.replaceAll('_', ' ');
    }
  }

  String _formatDateTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return raw;
    }
  }

  Future<void> _deletePrediction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Scan?'),
        content: const Text('This scan will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      final predictionId = widget.item['id'];
      
      // Always delete from local cache first
      await ScanCacheService.deletePrediction(predictionId);
      
      // Try to delete from backend if token available
      if (predictionId != null && widget.accessToken != null && widget.accessToken!.isNotEmpty) {
        try {
          final service = PredictionService(widget.accessToken!);
          await service.deletePrediction(predictionId);
        } catch (e) {
          // Silently fail for backend deletion - local cache is already deleted
          debugPrint('Backend deletion failed: $e');
        }
      }

      if (mounted) {
        widget.onDeleted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting scan: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = widget.item['label']?.toString() ?? 'Unknown';
    final confidence = (widget.item['confidence'] is num)
        ? (widget.item['confidence'] as num).toDouble()
        : null;
    final createdAt = widget.item['created_at']?.toString();
    final localImagePath = widget.item['local_image_path']?.toString();
    final rawImageUrl = widget.item['image_url']?.toString();
    final imageUrl = (rawImageUrl == null || rawImageUrl.isEmpty)
        ? null
        : normalizeApiUrl(rawImageUrl);
    final hasLocalImage = localImagePath != null && localImagePath.isNotEmpty;
    final title = _titleFromKey(label);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ScanDetailScreen(
                prediction: widget.item,
                accessToken: widget.accessToken,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.black.withAlpha((0.06 * 255).round()),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.03 * 255).round()),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 64,
                  height: 64,
                  color: Colors.grey[100],
                  child: hasLocalImage
                      ? Image.file(
                          File(localImagePath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.broken_image_outlined,
                            color: Colors.grey[400],
                          ),
                        )
                      : imageUrl == null || imageUrl.isEmpty
                      ? Icon(Icons.image_outlined, color: Colors.grey[400])
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.broken_image_outlined,
                            color: Colors.grey[400],
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (confidence != null)
                          _Pill(
                            icon: Icons.bar_chart_rounded,
                            text:
                                '${(confidence * 100).clamp(0, 100).toStringAsFixed(1)}% confidence',
                          ),
                        if (createdAt != null)
                          _Pill(
                            icon: Icons.schedule_rounded,
                            text: _formatDateTime(createdAt),
                          ),
                        if (widget.item['cached_at'] != null)
                          const _Pill(
                            icon: Icons.offline_pin_outlined,
                            text: 'Saved offline',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_isDeleting)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                PopupMenuButton(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deletePrediction();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          const Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  child: Icon(Icons.more_vert, color: Colors.grey[500]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withAlpha((0.06 * 255).round())),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            text,
            style: t.bodySmall?.copyWith(
              color: Colors.grey[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

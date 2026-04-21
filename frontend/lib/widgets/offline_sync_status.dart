import 'package:flutter/material.dart';

import '../services/offline_sync_manager.dart';

class OfflineSyncStatus extends StatelessWidget {
  final OfflineSyncManager syncManager;

  const OfflineSyncStatus({
    super.key,
    required this.syncManager,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: syncManager.syncStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final status = snapshot.data!;
        final textTheme = Theme.of(context).textTheme;

        if (status is _Syncing) {
          return _buildSyncingUI(context, textTheme);
        } else if (status is _SyncingItem) {
          return _buildSyncingItemUI(context, textTheme, status);
        } else if (status is _Completed) {
          return _buildCompletedUI(context, textTheme, status);
        } else if (status is _PartialSync) {
          return _buildPartialSyncUI(context, textTheme, status);
        } else if (status is _Error) {
          return _buildErrorUI(context, textTheme, status);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSyncingUI(BuildContext context, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(
          bottom: BorderSide(color: Colors.blue[200]!),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.blue[700]!),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Syncing with server...',
              style: textTheme.bodySmall?.copyWith(
                color: Colors.blue[900],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncingItemUI(
    BuildContext context,
    TextTheme textTheme,
    _SyncingItem status,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(
          bottom: BorderSide(color: Colors.blue[200]!),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.blue[700]!),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Uploading: ${status.itemName}',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.blue[900],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${status.totalPending} item(s) pending',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedUI(
    BuildContext context,
    TextTheme textTheme,
    _Completed status,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border(
          bottom: BorderSide(color: Colors.green[200]!),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync Complete',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.green[900],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${status.successCount} item(s) synced successfully${status.failureCount > 0 ? ', ${status.failureCount} failed' : ''}',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartialSyncUI(
    BuildContext context,
    TextTheme textTheme,
    _PartialSync status,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border(
          bottom: BorderSide(color: Colors.orange[200]!),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Partial Sync',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.orange[900],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${status.successCount} synced, ${status.failureCount} failed, ${status.remainingCount} pending',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorUI(
    BuildContext context,
    TextTheme textTheme,
    _Error status,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border(
          bottom: BorderSide(color: Colors.red[200]!),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync Error',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.red[900],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  status.message,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.red[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

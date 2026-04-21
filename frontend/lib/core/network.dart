import 'constants.dart';

/// Normalizes backend-provided URLs so they work on real devices.
///
/// Older records may store absolute URLs like `http://localhost:8000/uploads/...`,
/// which only work on the dev machine. This converts them to the configured API host.
String normalizeApiUrl(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return v;

  // If backend returns relative paths, prefix with base URL.
  if (v.startsWith('/')) {
    return '${AppConstants.apiBaseUrl}$v';
  }

  // Rewrite localhost/127.0.0.1 URLs to the configured base URL.
  if (v.startsWith('http://localhost:') || v.startsWith('http://127.0.0.1:')) {
    final idx = v.indexOf('/', 'http://'.length);
    if (idx != -1) {
      return '${AppConstants.apiBaseUrl}${v.substring(idx)}';
    }
    return AppConstants.apiBaseUrl;
  }

  return v;
}


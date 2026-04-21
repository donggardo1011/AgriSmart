// lib/core/constants.dart

import 'config.dart' as cfg;

class AppConstants {
  // Single source of truth for API base URL.
  // Edit `lib/core/config.dart` when switching devices.
  static const String apiBaseUrl = cfg.apiBaseUrl;

  static const String tokenKey = 'access_token';
  static const String rememberedUsernameKey = 'remembered_username';
  static const String rememberMeKey = 'remember_me';
  static const String cachedPredictionsKey = 'cached_predictions_v1';
}

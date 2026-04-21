import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../services/connectivity_service.dart';
import '../services/offline_sync_manager.dart';
import '../services/activity_sync_service.dart';
import '../services/offline_activity_service.dart';
import '../screens/landing_screen.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/reset_password_screen.dart';

class AgrismartechApp extends StatefulWidget {
  const AgrismartechApp({super.key});

  @override
  State<AgrismartechApp> createState() => _AgrismartechAppState();
}

class _AgrismartechAppState extends State<AgrismartechApp> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  String? _accessToken;
  bool _isGuestMode = false;
  bool _initialized = false;
  late final ConnectivityService _connectivityService;
  late final OfflineSyncManager _syncManager;
  late final ActivitySyncService _activitySyncService;

  @override
  void initState() {
    super.initState();
    _connectivityService = ConnectivityService();
    _syncManager = OfflineSyncManager();
    _activitySyncService = ActivitySyncService();
    _loadToken();
    _initLinks();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize connectivity monitoring
      await _connectivityService.initialize();
    } catch (e) {
      debugPrint('Failed to initialize connectivity service: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _connectivityService.dispose();
    _syncManager.dispose();
    _activitySyncService.dispose();
    super.dispose();
  }

  Future<void> _initLinks() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) _handleUri(uri);
    } catch (_) {}

    _sub = _appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri);
    }, onError: (_) {});
  }

  void _handleUri(Uri uri) {
    // agrismartech://reset-password?token=xxxx
    if (uri.scheme == 'agrismartech' && uri.host == 'reset-password') {
      final token = uri.queryParameters['token'];
      if (token == null || token.isEmpty) return;

      _navKey.currentState?.push(
        MaterialPageRoute(builder: (_) => ResetPasswordScreen(token: token)),
      );
    }
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);
    var isGuest = await OfflineActivityService.isGuestMode();
    
    // If we have a valid token, clear guest mode flag
    // (token takes precedence over guest mode)
    if (token != null && token.isNotEmpty) {
      isGuest = false;
      await OfflineActivityService.disableGuestMode();
    }
    
    setState(() {
      _accessToken = token;
      _isGuestMode = isGuest;
      _initialized = true;
    });

    // Initialize sync manager if user is logged in
    if (token != null && token.isNotEmpty) {
      try {
        await _syncManager.initialize(token);
        await _activitySyncService.initialize(token);
      } catch (e) {
        debugPrint('Failed to initialize sync managers: $e');
      }
    }
  }

  Future<void> _handleLoggedIn(String? token) async {
    if (!mounted) return; // Defensive check
    
    final prefs = await SharedPreferences.getInstance();
    
    if (token != null && token.isNotEmpty) {
      // Real login
      try {
        await prefs.setString(tokenKey, token);
        await OfflineActivityService.disableGuestMode();
        
        if (mounted) {
          setState(() {
            _accessToken = token;
            _isGuestMode = false;
          });
        }

        // Initialize sync managers for the new session
        try {
          await _syncManager.initialize(token);
          await _activitySyncService.initialize(token);
          // Sync pending activities after login
          await _activitySyncService.syncPendingActivities(token);
        } catch (e) {
          debugPrint('Failed to initialize sync managers: $e');
        }
      } catch (e) {
        debugPrint('Login error: $e');
        rethrow;
      }
    } else {
      // Guest mode
      try {
        await OfflineActivityService.enableGuestMode();
        
        if (mounted) {
          setState(() {
            _isGuestMode = true;
            _accessToken = null;
          });
        }
      } catch (e) {
        debugPrint('Guest mode error: $e');
        rethrow;
      }
    }
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await OfflineActivityService.disableGuestMode();
    
    // Clear guest mode data
    await OfflineActivityService.clearActivities();
    
    setState(() {
      _accessToken = null;
      _isGuestMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // Show dashboard if user has a token OR is in guest mode
    final isAuthenticated = _accessToken != null && _accessToken!.isNotEmpty;
    final canAccessDashboard = isAuthenticated || _isGuestMode;

    return MaterialApp(
      navigatorKey: _navKey,
      title: 'Agrismart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF22A45D)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),
      home: !canAccessDashboard
          ? LandingScreen(onNavigate: _handleLoggedIn)
          : DashboardScreen(
              accessToken: _accessToken,
              isGuestMode: _isGuestMode,
              onLogout: _handleLogout,
            ),
    );
  }
}

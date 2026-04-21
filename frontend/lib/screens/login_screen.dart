// lib/screens/login_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../core/constants.dart';
import '../services/connectivity_service.dart';
import '../services/offline_activity_service.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final void Function(String? token) onLoggedIn;

  const LoginScreen({super.key, required this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  String? _error;
  bool _isOnline = true;
  late final ConnectivityService _connectivityService;

  @override
  void initState() {
    super.initState();
    _connectivityService = ConnectivityService();
    _loadRememberedLogin();
    _initConnectivityListener();
  }

  Future<void> _initConnectivityListener() async {
    // Check initial connectivity
    final isOnline = await _connectivityService.checkNow();
    setState(() => _isOnline = isOnline);

    // Listen to connectivity changes
    _connectivityService.connectivityStream.listen((isOnline) {
      if (mounted) {
        setState(() => _isOnline = isOnline);
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(AppConstants.rememberMeKey) ?? false;
    final rememberedUsername = prefs.getString(
      AppConstants.rememberedUsernameKey,
    );

    if (!mounted) return;
    setState(() {
      _rememberMe = rememberMe;
      if (rememberMe && rememberedUsername != null) {
        _usernameController.text = rememberedUsername;
      }
    });
  }

  Future<void> _persistRememberedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.rememberMeKey, _rememberMe);

    if (_rememberMe) {
      await prefs.setString(
        AppConstants.rememberedUsernameKey,
        _usernameController.text.trim(),
      );
    } else {
      await prefs.remove(AppConstants.rememberedUsernameKey);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return; // Extra safety check before any state changes
    
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$apiBaseUrl/auth/login');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': _usernameController.text.trim(),
              'password': _passwordController.text,
              'recaptcha_token': 'dev-token',
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final token = data['access_token']?.toString();
        if (token == null) throw Exception('Missing access token');
        await _persistRememberedLogin();
        if (mounted) {
          widget.onLoggedIn(token);
          // Navigate to root and let the app show dashboard automatically
          // by removing all routes from the stack
          Navigator.of(context).popUntil((route) => route.isFirst);
          return;
        }
      } else {
        String message = 'Login failed. Please try again.';
        try {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final detail = data['detail']?.toString().toLowerCase();
          if (detail != null &&
              detail.contains('invalid username or password')) {
            message = 'Incorrect username or password.';
          }
        } catch (_) {
          // Use default message
        }

        if (mounted) {
          setState(() {
            _error = message;
          });
        }
      }
    } on TimeoutException catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Connection timeout. Server is not responding.\n\n'
              'Please check:\n'
              '• Your internet connection\n'
              '• Server IP address: $apiBaseUrl\n'
              '• Try again in a moment';
        });
      }
    } on SocketException catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Network error. Cannot reach the server.\n\n'
              'Please check:\n'
              '• Your internet connection is active\n'
              '• Server IP address is correct: $apiBaseUrl\n'
              '• Mobile device is on the same network as server';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Login failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _goToForgotPassword() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
  }

  void _goToRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  Future<void> _continueAsGuest() async {
    if (_loading) return;
    
    if (!mounted) return;
    
    setState(() => _loading = true);
    
    try {
      // Enable guest mode
      await OfflineActivityService.enableGuestMode();
      // Log this activity
      await OfflineActivityService.logActivity(
        action: 'auth.guest_access',
        description: 'Accessed system as guest (offline mode)',
      );
      
      if (mounted) {
        // Pass null token to indicate guest mode
        widget.onLoggedIn(null);
        // Return immediately - don't execute any more code in this widget
        // The parent will handle the transition and this widget will be disposed
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to access guest mode: $e';
          _loading = false;
        });
      }
    } finally {
      // Additional safety: ensure loading is false if anything goes wrong
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                            'Rice Disease Detector',
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Welcome back',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue monitoring your rice fields.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha((0.06 * 255).round()),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter your username'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          obscureText: _obscurePassword,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Enter your password'
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                            ),
                            const Text('Remember me'),
                            const Spacer(),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _goToForgotPassword,
                            child: const Text('Forgot password?'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  )
                                : const Text('Sign In'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Guest mode button - only shown when offline
                  if (!_isOnline) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _continueAsGuest,
                        child: const Text('Continue as Guest (Offline)'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha((0.06 * 255).round()),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outlined,
                            color: Colors.orange[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You are offline. Guest mode allows viewing and scanning. Activities will sync when you log in.',
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.orange[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Online indicator
                  if (_isOnline)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Connected to server',
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'No internet connection',
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: textTheme.bodySmall,
                      ),
                      TextButton(
                        onPressed: _goToRegister,
                        child: const Text('Create one'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

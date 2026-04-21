// lib/screens/forgot_password_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _loading = false;
  String? _message;
  String? _messageType; // 'success' or 'error'
  bool _showOtpForm = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _message = null;
      _messageType = null;
    });

    try {
      final uri = Uri.parse('$apiBaseUrl/auth/forgot-password');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'recaptcha_token': 'dev-token',
        }),
      );

      if (res.statusCode == 200) {
        setState(() {
          _message = 'A 6-digit reset code has been sent to your email.';
          _messageType = 'success';
          _showOtpForm = true;
        });
      } else {
        setState(() {
          _message = 'Request failed (${res.statusCode}). Please try again.';
          _messageType = 'error';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Request failed: $e';
        _messageType = 'error';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitOtp() async {
    if (!_otpFormKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _message = null;
      _messageType = null;
    });

    try {
      final uri = Uri.parse('$apiBaseUrl/auth/verify-reset-otp');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'otp_code': _otpController.text.trim(),
          'new_password': _passwordController.text,
        }),
      );

      if (res.statusCode == 200) {
        setState(() {
          _message = 'Password reset successful! You can now log in.';
          _messageType = 'success';
        });
        
        // Navigate back to login after 2 seconds
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        final errorBody = jsonDecode(res.body);
        setState(() {
          _message = errorBody['detail'] ?? 'Password reset failed. Please try again.';
          _messageType = 'error';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Request failed: $e';
        _messageType = 'error';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _backToEmail() {
    setState(() {
      _showOtpForm = false;
      _message = null;
      _messageType = null;
      _otpController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot password'),
        leading: _showOtpForm
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _backToEmail,
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _showOtpForm ? 'Enter reset code' : 'Reset your password',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _showOtpForm
                      ? 'Enter the 6-digit code we sent to your email and your new password.'
                      : 'Enter the email linked to your account. We will send a reset code if it exists.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 24),
                if (_message != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_messageType == 'success'
                              ? Colors.green
                              : Colors.red)
                          .withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (_messageType == 'success'
                                ? Colors.green
                                : Colors.red)[200]!,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _message!,
                      style: textTheme.bodySmall?.copyWith(
                        color: (_messageType == 'success'
                                ? Colors.green
                                : Colors.red)[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (!_showOtpForm) ...[
                  Form(
                    key: _emailFormKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Enter an email';
                            }
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submitEmail,
                            child: _loading
                                ? const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  )
                                : const Text('Send reset code'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Form(
                    key: _otpFormKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _otpController,
                          decoration: InputDecoration(
                            labelText: 'Reset code (6 digits)',
                            border: const OutlineInputBorder(),
                            hintText: '000000',
                            counterText: '',
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Enter the code';
                            }
                            if (v.trim().length != 6) {
                              return 'Code must be 6 digits';
                            }
                            if (!RegExp(r'^\d{6}$').hasMatch(v.trim())) {
                              return 'Code must contain only digits';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'New password',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Enter a password';
                            }
                            if (v.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: const InputDecoration(
                            labelText: 'Confirm password',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Confirm your password';
                            }
                            if (v != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submitOtp,
                            child: _loading
                                ? const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  )
                                : const Text('Reset password'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// lib/core/config.dart

/// API Base URL Configuration
/// For Android emulator: http://10.0.2.2:8000
/// For real phone on LAN: http://192.168.x.x:8000 (your PC/server IP)
/// For production: https://yourdomain.com
const String apiBaseUrl = 'http://192.168.100.33:8000';

// TODO: Make this configurable at runtime via environment or settings
// For testing on different networks, you may need to update this IP address
// to match your backend server's actual IP on that network.

const String tokenKey = 'access_token';
// lib/screens/scan_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';

import 'chatbot_screen.dart';
import 'realtime_detection_screen.dart';
import '../services/prediction_service.dart';
import '../services/offline_leaf_diagnosis_service.dart';
import '../services/scan_cache_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';

class ScanScreen extends StatefulWidget {
  final String accessToken;

  const ScanScreen({super.key, required this.accessToken});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _uploading = false;
  String? _error;
  bool _offlineOnly = false;
  bool _isOnline = true;
  bool _offlineModelAvailable = false;
  String? _cachedImagePath;
  int _queuedItemCount = 0;
  double _confidenceThreshold = 0.72; // Default threshold
  late final PredictionService _predictionService;
  late final ConnectivityService _connectivityService;
  List<CameraDescription> _cameras = [];

  @override
  void initState() {
    super.initState();
    _predictionService = PredictionService(widget.accessToken);
    _connectivityService = ConnectivityService();
    _checkOfflineModel();
    _checkConnectivity();
    _initializeCameras();
    _loadQueuedItems();
    _listenToConnectivity();
  }

  void _listenToConnectivity() {
    _connectivityService.connectivityStream.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });
  }

  Future<void> _loadQueuedItems() async {
    final stats = await OfflineQueueService.getQueueStats();
    if (mounted) {
      setState(() {
        _queuedItemCount = stats['pending'] as int;
      });
    }
  }

  Future<void> _initializeCameras() async {
    try {
      final cameras = await availableCameras();
      setState(() {
        _cameras = cameras;
      });
    } catch (e) {
      // Silently fail if cameras aren't available
      if (mounted) {
        setState(() {
          _cameras = [];
        });
      }
    }
  }

  Future<void> _checkOfflineModel() async {
    try {
      final available = await OfflineLeafDiagnosisService.isOfflineModelAvailable();
      setState(() {
        _offlineModelAvailable = available;
      });
    } catch (e) {
      setState(() {
        _offlineModelAvailable = false;
      });
    }
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await _connectivityService.checkNow();
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _error = null;
    });
    try {
      final image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image == null) return;
      final cachedImagePath = await ScanCacheService.cacheCapturedImage(image.path);
      setState(() {
        _selectedImage = image;
        _cachedImagePath = cachedImagePath ?? image.path;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to pick image: $e';
      });
    }
  }

  Future<void> _captureFromCamera() async {
    await _pickImage(ImageSource.camera);
  }

  Future<void> _selectFromGallery() async {
    await _pickImage(ImageSource.gallery);
  }

  Future<void> _openRealtimeDetection() async {
    if (_cameras.isEmpty) {
      setState(() {
        _error = 'No camera available on this device';
      });
      return;
    }

    // Real-time detection now handles navigation to chatbot directly
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RealtimeDetectionScreen(
          accessToken: widget.accessToken,
          cameras: _cameras,
        ),
      ),
    );
  }

  String _getThresholdDescription(double threshold) {
    if (threshold < 0.5) {
      return 'Very Flexible';
    } else if (threshold < 0.65) {
      return 'Flexible';
    } else if (threshold < 0.75) {
      return 'Balanced';
    } else if (threshold < 0.85) {
      return 'Strict';
    } else {
      return 'Very Strict';
    }
  }

  Future<void> _analyze() async {
    final image = _selectedImage;
    if (image == null) return;
    final imagePath = _cachedImagePath ?? image.path;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final prediction = await _predictionService.analyzeLeafImage(
        imagePath,
        image.name,
        forceOffline: _offlineOnly,
        confidenceThreshold: _confidenceThreshold,
      );

      if (!mounted) return;

      // Check if image was valid (contains rice leaf)
      final predictedLabel = prediction['label']?.toString().toLowerCase() ?? '';
      if (predictedLabel == 'invalid_image') {
        setState(() {
          _error = prediction['advice']?.toString() ?? 
              'Invalid image. Please ensure the image contains rice leaves.';
          _uploading = false;
        });
        return;
      }

      // Valid disease detection - navigate to chatbot
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatbotScreen(
            accessToken: widget.accessToken,
            initialDisease: prediction['label']?.toString(),
            prediction: prediction,
            loadOverviewOnStart: true,
          ),
        ),
        result: true,
      );
    } catch (e) {
      final errorMessage = e.toString();
      String displayError = 'An error occurred during analysis.';
      
      if (errorMessage.contains('offline_detection_unavailable')) {
        displayError = '❌ Offline Model Missing\n\n'
            'To analyze images, you need:\n\n'
            '✓ Option 1: Internet Connection\n'
            '  Connect to WiFi or mobile data to use online analysis.\n\n'
            '✓ Option 2: Offline Model\n'
            '  Ask your admin to bundle the offline model file (best.tflite) with the app.\n\n'
            'Status: Currently √ online model, √ offline model support available\n'
            'Your image is saved and ready to analyze once a model is available.';
      } else if (errorMessage.contains('Connection refused') || 
                 errorMessage.contains('Connection reset') ||
                 errorMessage.contains('Unable to reach')) {
        displayError = '🔌 Cannot Connect to Server\n\n'
            'Troubleshooting steps:\n'
            '1. Check your internet connection\n'
            '2. Make sure WiFi/mobile data is enabled\n'
            '3. Try again in a moment\n\n'
            'If the problem persists, try using the offline model instead.';
      } else if (errorMessage.contains('401') || errorMessage.contains('Unauthorized')) {
        displayError = '🔐 Session Expired\n\n'
            'Your login session has ended.\n'
            'Please sign out and sign back in to continue.';
      } else if (errorMessage.contains('SocketException') || 
                 errorMessage.contains('TimeoutException')) {
        displayError = '⏱️ Network Timeout\n\n'
            'The server took too long to respond.\n'
            'Please check your connection and try again.';
      } else {
        displayError = errorMessage.replaceAll('Exception: ', '');
      }
      
      setState(() {
        _error = displayError;
      });
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isAnalyzeDisabled = _uploading || _selectedImage == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan leaf'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Tooltip(
                message: _isOnline ? 'Online mode' : 'Offline mode',
                child: Chip(
                  label: Text(
                    _isOnline ? 'ONLINE' : 'OFFLINE',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: _isOnline ? Colors.green[100] : Colors.orange[100],
                  labelStyle: TextStyle(
                    color: _isOnline ? Colors.green[800] : Colors.orange[800],
                  ),
                  avatar: Icon(
                    _isOnline ? Icons.cloud_done : Icons.cloud_off,
                    size: 16,
                    color: _isOnline ? Colors.green[800] : Colors.orange[800],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scan a rice leaf',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use your phone camera for the fastest scan. Captured photos and detection results are saved locally so farmers can reopen them without internet.',
                style: textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              if (!_isOnline && !_offlineModelAvailable) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange[800], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'The app can still use the local camera and keep scans offline, but true offline disease detection needs the bundled file assets/models/best.tflite.',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.orange[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_offlineModelAvailable) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Offline Detection Available',
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                            Text(
                              'Use device model (no internet needed)',
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _offlineOnly,
                        onChanged: (value) {
                          setState(() {
                            _offlineOnly = value;
                          });
                        },
                        activeThumbColor: Colors.blue[700],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_queuedItemCount > 0) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.amber[800], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pending Upload',
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[900],
                              ),
                            ),
                            Text(
                              '$_queuedItemCount detection(s) waiting to sync with server',
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.amber[800],
                              ),
                            ),
                            if (!_isOnline)
                              Text(
                                'Will sync when connected',
                                style: textTheme.bodySmall?.copyWith(
                                  color: Colors.amber[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red[200]!,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.red[700],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Analysis failed',
                              style: textTheme.titleSmall?.copyWith(
                                color: Colors.red[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.red[800],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _uploading ? null : _captureFromCamera,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Capture'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _uploading ? null : _selectFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _uploading ? null : _openRealtimeDetection,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.teal,
                  ),
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('Real-Time Detection'),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                height: 240,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.withAlpha((0.4 * 255).round()),
                    style: BorderStyle.solid,
                  ),
                ),
                child: _selectedImage == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_enhance_outlined,
                            size: 40,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Capture a clear leaf photo to begin detection',
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(_cachedImagePath ?? _selectedImage!.path),
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              if (_selectedImage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.teal[200]!,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tune_outlined,
                            color: Colors.teal[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Confidence Threshold',
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.teal[900],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: Colors.teal,
                          inactiveTrackColor: Colors.teal[100],
                          thumbColor: Colors.teal,
                          overlayColor: Colors.teal.withAlpha((0.2 * 255).round()),
                          valueIndicatorColor: Colors.teal,
                          valueIndicatorTextStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: Slider(
                          value: _confidenceThreshold,
                          min: 0.0,
                          max: 1.0,
                          divisions: 100,
                          label: '${(_confidenceThreshold * 100).toStringAsFixed(0)}%',
                          onChanged: (value) {
                            setState(() {
                              _confidenceThreshold = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current: ${(_confidenceThreshold * 100).toStringAsFixed(1)}% - ${_getThresholdDescription(_confidenceThreshold)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.teal[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lower thresholds accept images with lower confidence (more flexible), higher thresholds require greater confidence (more strict).',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.teal[600],
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F8F4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detection Methods:',
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isOnline)
                      Text(
                        'Online: Cloud model (most accurate)',
                        style: textTheme.bodySmall?.copyWith(color: Colors.grey[800]),
                      ),
                    if (_offlineModelAvailable)
                      Text(
                        'Offline: Device model (works without internet)',
                        style: textTheme.bodySmall?.copyWith(color: Colors.grey[800]),
                      ),
                    if (!_offlineModelAvailable)
                      Text(
                        'Offline capture and saved results are available on this device.',
                        style: textTheme.bodySmall?.copyWith(color: Colors.grey[800]),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'All results are cached locally for offline viewing.',
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isAnalyzeDisabled ? null : _analyze,
                  icon: _uploading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.search_outlined),
                  label: _uploading
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        )
                      : Text(
                          _offlineOnly ? 'Detect (Offline)' : 'Detect Disease',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

# Rice Leaf Disease Detection - Offline & Caching Implementation

## Overview

This implementation enables the AgriSmart RLDD Flutter app to:
1. **Use device camera** to capture rice leaf images
2. **Detect diseases offline** using on-device TFLite models
3. **Cache all results** for offline viewing
4. **Support both online (cloud) and offline (device) modes**
5. **Work without internet** for farmers in remote areas

---

## Architecture

### 1. Camera Integration ✅
**File**: [lib/screens/scan_screen.dart](lib/screens/scan_screen.dart)

Features:
- Camera capture using `ImagePicker` (already implemented)
- Gallery selection for existing photos
- Real-time image preview
- Online/Offline mode toggle indicator
- Network status detection

**Permissions Added**:
- ✅ Android: `CAMERA`, `READ_EXTERNAL_STORAGE`
- ✅ iOS: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`

### 2. Offline Prediction Service ✅
**File**: [lib/services/offline_leaf_diagnosis_service.dart](lib/services/offline_leaf_diagnosis_service.dart)

**Features**:
- TFLite model loading from assets
- Image preprocessing (resizing, normalization)
- YOLOv8 detection format handling
- Disease classification ([5 classes](bacteri_blight, brown_spot, leaf_blast, smut, tungro))
- Fallback to healthy leaf classification
- Complete disease information (name, description, remedy, severity)

**How it works**:
```dart
// Initialize model once (onasset load)
Interpreter interpreter = await Interpreter.fromAsset('assets/models/rice_disease.tflite');

// Run inference
final output = [List.filled(25200, List.filled(85, 0.0))];
interpreter.run(inputTensor, output);

// Extract best detection
Map<String, dynamic> prediction = _extractDetections(output);
```

**Supported Diseases**:
1. **Bacterial Blight** - Water-soaked lesions, high severity
2. **Brown Spot** - Circular brown lesions, medium severity
3. **Leaf Blast** - Diamond-shaped lesions, high severity
4. **Smut** - Black sooty masses, high severity
5. **Tungro** - Yellowing and stunting, medium severity

### 3. Intelligent Caching ✅
**File**: [lib/services/scan_cache_service.dart](lib/services/scan_cache_service.dart)

**Dual-layer Caching**:

**Layer 1: Metadata Caching** (SharedPreferences)
- JSON serialization of predictions
- Stores: disease label, confidence, advice, timestamps
- Keeps last 100 predictions
- Instant access without file I/O

**Layer 2: Image Caching** (App Documents Directory)
- Stores actual leaf photos
- Organized in `cached_scans/` directory
- Automatic timestamp-based naming
- Accessible even if original photo deleted

**Cache Operations**:
```dart
// Save prediction with image
final cached = await ScanCacheService.cachePrediction(
  prediction,
  sourceImagePath: imagePath,
);

// Load cached predictions
List<Map<String, dynamic>> predictions = await ScanCacheService.loadPredictions();

// Merge remote with cached
List<Map<String, dynamic>> merged = await ScanCacheService.mergeWithRemote(remote);
```

### 4. Smart Online/Offline Fallback ✅
**File**: [lib/services/prediction_service.dart](lib/services/prediction_service.dart)

**Workflow**:
```
User submits image
    ↓
Is network available?
    ├─ YES: Try cloud detection
    │       ├─ Success? → Cache and return cloud result
    │       └─ Failed? → Fallback to offline
    └─ NO: Use offline detection
                └─ Cache and return offline result

Both paths → Results always cached for offline viewing
```

**Features**:
- `forceOffline` parameter for testing offline mode
- Automatic network connectivity detection
- Graceful degradation
- Unified caching for both modes

### 5. Enhanced Scan Screen ✅
**File**: [lib/screens/scan_screen.dart](lib/screens/scan_screen.dart)

**New UI Features**:
- **Network Status Indicator** (AppBar chip): Shows ONLINE/OFFLINE status
- **Offline Mode Toggle**: Switch between cloud and device models
- **Offline Model Detection**: Automatically checks if TFLite model available
- **Improved Help Text**: Explains caching and offline capabilities
- **Better Error Messages**: Clear guidance when features unavailable

---

## Setup & Deployment

### 1. Add TFLite Model (Required for Offline)

**Step 1: Convert Model**
```bash
# Convert backend PyTorch model to TFLite
# Option A: Using ONNX (recommended)
python backend/scripts/convert_to_onnx.py  # Creates rice_disease.onnx
python backend/scripts/onnx_to_tflite.py   # Creates rice_disease.tflite

# Option B: Direct TFLite conversion
python backend/scripts/pytorch_to_tflite.py
```

**Step 2: Place in Assets**
```
frontend/
├── assets/
│   └── models/
│       ├── rice_disease.tflite  ← Place your model here
│       └── README.md
```

**Step 3: Build & Deploy**
```bash
cd frontend
flutter pub get        # Downloads TFLite package
flutter run           # Rebuilds with model assets
```

### 2. Model Specifications

**Input Requirements**:
- Format: RGB image (4D tensor: [1, H, W, 3])
- Size: 416x416 or 640x640 (adjust in [offline_leaf_diagnosis_service.dart#L26](lib/services/offline_leaf_diagnosis_service.dart#L26))
- Normalization: [0, 1] range (divides by 255)

**Output Format**:
- Shape: [1, 25200, 85] for YOLOv8 nano/small
- Each detection: [x, y, w, h, objectness, class_0, class_1, ..., class_4]
- Processing: Finds highest confidence detection > 0.3 threshold

**Supported Classes** (must match model training order):
1. `bacterial_blight`
2. `brown_spot`
3. `leaf_blast`
4. `smut`
5. `tungro`

### 3. Testing Offline Detection

```bash
# Load app
flutter run

# In Scan Screen:
1. Toggle "Offline Detection Available" switch ON
2. Capture or select a leaf image
3. Click "Detect (Offline)"
4. Result processed purely on-device
5. Image + result cached in app documents

# Verify caching:
1. Go to home screen (Recent Scans)
2. Disconnect internet
3. Returns to home
4. Recent scans still visible (from cache)
```

---

## File Structure

```
frontend/
├── pubspec.yaml                           # ✅ Added TFLite, image packages
├── assets/models/
│   ├── rice_disease.tflite               # ⚠️ Add your TFLite model here
│   └── README.md                         # Instructions
├── lib/
│   ├── screens/
│   │   └── scan_screen.dart              # ✅ Enhanced with offline mode UI
│   └── services/
│       ├── offline_leaf_diagnosis_service.dart # ✅ Implemented TFLite inference
│       ├── prediction_service.dart        # ✅ Updated for forceOffline param
│       └── scan_cache_service.dart        # ✅ Caching (unchanged)
├── android/
│   └── app/src/main/AndroidManifest.xml  # ✅ Added camera, storage permissions
└── ios/
    └── Runner/Info.plist                 # ✅ Added camera permission prompts
```

---

## Dependencies Added

```yaml
dependencies:
  tflite_flutter: ^0.10.0  # TFLite model inference
  image: ^4.0.0            # Image processing/preprocessing
```

Existing dependencies used:
- `image_picker`: Camera & gallery access
- `shared_preferences`: Metadata caching
- `path_provider`: App documents directory access

---

## Workflow: Offline Detection End-to-End

### Scenario: Farmer in remote area, no internet

```
1. CAPTURE
   └─ Opens camera in Scan Screen
   └─ Takes photo of diseased leaf
   └─ Preview shown in app

2. ANALYZE OFFLINE
   └─ Tap "Detect (Offline)" button
   └─ Image sent to OfflineLeafDiagnosisService
   └─ TFLite model preprocesses image:
      ├─ Read PNG/JPG bytes
      ├─ Decode image
      ├─ Resize to 416x416
      └─ Normalize to [0, 1]
   └─ Model inference runs on device (no network needed)
   └─ Detection output extracted (best match > 0.3 confidence)
   └─ Disease info populated (name, remedy, severity)

3. CACHE RESULT
   └─ ScanCacheService.cachePrediction() called
   └─ Metadata saved to SharedPreferences
   └─ Image copied to cached_scans/ directory
   └─ Both persisted locally
   └─ Last 100 results maintained

4. DISPLAY RESULT
   └─ Results shown in ChatbotScreen / DetailScreen
   └─ Farmer sees:
      ├─ Disease name & confidence
      ├─ Description of disease
      ├─ Treatment recommendations
      └─ Severity level

5. OFFLINE VIEWING (even later, no internet)
   └─ Open Home Screen
   └─ Recent Scans loads from cache
   └─ Tap scan to see full details
   └─ All data available locally

6. SYNC WHEN ONLINE
   └─ App reconnects to internet
   └─ PredictionService.fetchPredictions() called
   └─ Remote predictions merged with cached
   └─ Local always maintained as backup
```

---

## Customization

### Change Model Input Size
[offline_leaf_diagnosis_service.dart#L26](lib/services/offline_leaf_diagnosis_service.dart#L26):
```dart
static const int inputSize = 640;  // Change from 416 to 640
```

### Add More Disease Classes
[offline_leaf_diagnosis_service.dart#L19-L25](lib/services/offline_leaf_diagnosis_service.dart#L19-L25):
```dart
static const List<String> diseaseClasses = [
  'bacterial_blight',
  'brown_spot',
  'leaf_blast',
  'smut',
  'tungro',
  'your_new_disease',  // Add here
];
```

Then update `_getDiseaseDescription()`, `_getRemedy()`, `_getSeverity()` with info for new disease.

### Change Confidence Threshold
[offline_leaf_diagnosis_service.dart#L151](lib/services/offline_leaf_diagnosis_service.dart#L151):
```dart
if (objectness > bestConfidence && objectness > 0.5) {  // Change 0.3 to 0.5+
```

### Store More/Fewer Predictions
[scan_cache_service.dart#L73](lib/services/scan_cache_service.dart#L73):
```dart
await savePredictions(cached.take(200).toList());  // Change 100 to 200
```

---

## Troubleshooting

### "Offline detection is not configured in this build yet"
**Cause**: TFLite model file missing
**Solution**: 
1. Convert model to `.tflite` format
2. Place in `assets/models/rice_disease.tflite`
3. Run `flutter pub get`
4. Rebuild app

### Camera not accessible
**Cause**: Permissions not granted
**Solution**:
1. iOS: User must approve camera permission in Privacy Settings
2. Android: App requests permissions on first use
3. Check [Info.plist](ios/Runner/Info.plist) and [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml)

### Cached images not showing
**Cause**: Path permissions or cleanup
**Solution**:
1. Check `getApplicationDocumentsDirectory()` has write access
2. Verify `cached_scans/` directory exists: `adb shell` → navigate to app documents
3. Clear cache if needed: Settings → App → Clear Cache

### Slow inference
**Cause**: Large model or slow device
**Solution**:
1. Use quantized TFLite model (smaller, faster)
2Consider model distillation if accuracy allows
3. Show progress indicator during inference (already in UI)

---

## Performance

**Offline Inference Latency** (estimated on mid-range device):
- Image preprocessing: ~50-100ms
- Model inference: ~200-500ms (depends on model size)
- Result processing: ~10-20ms
- **Total**: ~300-600ms (shown as loading indicator)

**Storage**:
- Metadata per prediction: ~200-300 bytes
- Image per prediction: ~300KB-1MB (quality 85)
- Cache limit: Last 100 predictions = ~30-50MB max (configurable)

**Network Fallback**:
- Online detection: ~2-5 seconds depending on network & server
- If fails → Automatic fallback to offline (~300-600ms)
- Result still cached for offline viewing

---

## Future Enhancements

1. **Model Quantization**: Speed up inference
2. **Model Updates**: OTA updates for latest models
3. **Batch Analysis**: Analyze multiple images at once
4. **Model Selection**: Let farmers choose accuracy vs speed
5. **Result Sharing**: Export cached results as PDF
6. **Prediction Analytics**: Show detection trends over time

---

## Support & Debugging

**Logs**: Set `print()` statements in:
- `OfflineLeafDiagnosisService.analyzeImage()` - Inference steps
- `ScanCacheService.cachePrediction()` - Caching operations
- `PredictionService.analyzeLeafImage()` - Online/offline fallback

**Testing**: 
- Force offline: Use "Offline Detection Available" toggle in Scan Screen
- Check cache: View Recent Scans without internet
- Model availability: Logs print success/failure of model load

---

## Summary

✅ **Implemented**:
- Camera capture and gallery selection
- Offline disease detection with TFLite models
- Dual-layer caching (metadata + images)
- Smart online/offline fallback
- Enhanced scan screen with mode toggle
- Android & iOS permissions configured
- Comprehensive error handling

⚠️ **Needs**: 
- TFLite model file (`rice_disease.tflite`) - User must convert from backend PyTorch model
- Model conversion script (Python) - For backend team to create

✨ **Result**:
Farmers in remote areas can now:
1. Capture leaf photos securely
2. Get instant disease detection without internet
3.  View results and recommendations offline
4. Sync results when internet available
5. Build history of scans for future reference

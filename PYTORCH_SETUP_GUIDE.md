# PyTorch to TFLite Conversion & Offline Model Setup Guide

## Overview

This guide explains how to convert your PyTorch rice disease detection model to TFLite format for offline mobile use, while keeping PyTorch for backend (online) predictions.

## Architecture

```
┌─────────────────────────┐
│  Flutter Frontend       │
├─────────────────────────┤
│ Online: Upload to API   │  →  Backend (PyTorch via Ultralytics)
│ Offline: Use TFLite     │     Uses: rice_disease.pt
│ (converted from PyTorch)│
└─────────────────────────┘

Model Flow:
  rice_disease.pt (PyTorch) 
     ↓
  convert_pytorch_to_tflite.py
     ↓
  best.tflite (TFLite) 
     ↓
  frontend/assets/models/best.tflite
```

## Step 1: Verify PyTorch Model

First, ensure your model is properly trained and saved:

```bash
cd backend
python -c "
from ultralytics import YOLO
model = YOLO('models/rice_disease.pt')
print('✓ Model loaded successfully')
print(f'Model type: {type(model)}')
"
```

## Step 2: Convert PyTorch to TFLite

### Option A: Using the provided conversion script

```bash
cd backend

# Activate your Python environment
.\venv\Scripts\activate  # Windows
# or
source venv/bin/activate  # macOS/Linux

# Run conversion
python scripts/convert_pytorch_to_tflite.py \
  --input-model models/rice_disease.pt \
  --output-model ../frontend/assets/models/best.tflite \
  --input-size 640
```

### Option B: Manual conversion using Ultralytics

```python
from ultralytics import YOLO

# Load PyTorch model
model = YOLO('models/rice_disease.pt')

# Export to TFLite
model.export(format='tflite', imgsz=640, half=True)
```

This creates multiple format files. Use the `.tflite` file.

## Step 3: Bundle Model with Frontend

Place the converted model at:
```
frontend/assets/models/best.tflite
```

Create the directory if it doesn't exist:
```bash
mkdir -p frontend/assets/models
```

## Step 4: Verify Frontend Assets

Update `frontend/pubspec.yaml`:
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/
    - assets/models/best.tflite  # Add this line
```

Then rebuild:
```bash
cd frontend
flutter pub get
flutter build apk  # or flutter build ios
```

## Step 5: Test Offline Functionality

1. **Upload to device/emulator**
2. **Enable airplane mode** or disconnect from internet
3. **Try to analyze an image**
4. **You should see offline analysis working!**

## Troubleshooting

### Issue: "Offline model unavailable" error

**Solution**: Check if model file exists:
```bash
ls -la frontend/assets/models/best.tflite  # macOS/Linux
dir frontend\assets\models\best.tflite  # Windows
```

If missing, follow Step 3 again.

### Issue: Model conversion fails with "Missing dependencies"

**Solution**: Install all required packages:
```bash
cd backend
pip install ultralytics torch torchvision tensorflow-lite
```

### Issue: App crashes on offline analysis

**Possible causes**:
1. Model not in assets
2. Wrong input size (use 640 for YOLOv8)
3. Corrupted TFLite file

**Debug**:
```dart
// Check in Flutter console
final isAvailable = await OfflineLeafDiagnosisService.isOfflineModelAvailable();
print('Offline model available: $isAvailable');
```

### Issue: Online mode still fails despite backend running

**Check**:
1. Backend is running: `cd backend && python main.py`
2. Frontend config has correct API URL in `lib/services/api_config.dart`
3. No CORS issues (should be configured in backend)
4. Device/emulator can reach backend server

## Model Specifications

- **Model Type**: YOLOv8 Detection
- **Input Size**: 640×640 pixels
- **Input Format**: RGB
- **Supported Diseases**: 
  - bacterial_blight
  - brown_spot
  - leaf_blast
  - smut
  - tungro
- **Confidence Threshold**: 0.3 (minimum for display)

## Backend Setup (PyTorch Online)

No additional setup needed! Backend already uses PyTorch:

```python
# backend/routes/prediction_routes.py
from ultralytics import YOLO
model = YOLO(model_path)  # Loads .pt (PyTorch) format
results = model(image_path)
```

Just ensure:
1. Model at `backend/models/rice_disease.pt`
2. ultralytics installed: `pip install ultralytics`
3. Backend running: `python main.py` or via Uvicorn

## Performance Notes

- **Online (Backend)**: Full accuracy, slightly slower (network overhead)
- **Offline (Mobile)**: TFLite optimized, slightly faster, ~99% accuracy relative to PyTorch

## Converting Other Models

If you have other PyTorch models:

```python
from ultralytics import YOLO

model = YOLO('path/to/your_model.pt')
model.export(format='tflite', imgsz=640, half=True)
```

For non-YOLO PyTorch models, use:
```python
import torch

# Your PyTorch model
model = torch.load('model.pt')
model.eval()

# Convert example (adjust based on your model)
dummy_input = torch.randn(1, 3, 640, 640)
torch.onnx.export(model, dummy_input, 'model.onnx')
# Then convert ONNX to TFLite
```

## Update Logs

### Version 2.0 (PyTorch + TFLite)
- Backend: PyTorch models for online predictions ✓
- Frontend: TFLite models (converted from PyTorch) for offline ✓
- Error handling: Clear messages for both modes ✓

### Migration from v1.0 (TensorFlow)
1. Convert TensorFlow model to PyTorch (if needed)
2. Follow Steps 1-5 above
3. Delete old `best.tflite` if from TensorFlow
4. Replace with newly converted PyTorch-based TFLite

# PyTorch Model Setup Checklist - Quick Start

## Problem
- Getting "Analysis failed: no internet connection & offline model unavailable" error
- Want to use PyTorch for both online and offline detection

## Solution Overview

✅ **Online (Backend)**: Already uses PyTorch (via Ultralytics YOLO)  
🔄 **Offline (Frontend)**: Need to convert PyTorch → TFLite  

---

## Quick Start (5 Steps)

### Step 1: Prepare Backend 🖥️
- [ ] Ensure `backend/models/rice_disease.pt` exists
  ```bash
  cd backend
  ls models/rice_disease.pt  # or `dir models\rice_disease.pt` on Windows
  ```

### Step 2: Install Conversion Dependencies 📦
- [ ] Activate backend venv
  ```bash
  cd backend
  .\venv\Scripts\activate  # Windows
  # or: source venv/bin/activate  # macOS/Linux
  ```

- [ ] Install/update ultralytics and TensorFlow Lite
  ```bash
  pip install --upgrade ultralytics tensorflow
  ```

### Step 3: Convert Model 🔄
- [ ] Run conversion script (this creates best.tflite)
  ```bash
  python scripts/convert_pytorch_to_tflite.py \
    --input-model models/rice_disease.pt \
    --output-model ../frontend/assets/models/best.tflite \
    --input-size 640
  ```

- [ ] Verify output file was created
  ```bash
  cd ../frontend
  ls assets/models/best.tflite  # or `dir assets\models\best.tflite` on Windows
  ```

### Step 4: Update Frontend Assets 📱
- [ ] Verify `frontend/pubspec.yaml` includes models in assets:
  ```yaml
  flutter:
    uses-material-design: true
    assets:
      - assets/
      - assets/models/best.tflite
  ```

- [ ] Get dependencies and rebuild
  ```bash
  cd frontend
  flutter pub get
  flutter clean
  flutter pub get
  ```

### Step 5: Test Everything ✅
- [ ] Start backend
  ```bash
  cd backend
  python main.py  # or: uvicorn main:app --reload
  ```

- [ ] Try online prediction (with internet)
  - Run app, take photo, analyze → Should work ✓

- [ ] Test offline prediction (enable airplane mode)
  - Take another photo, analyze → Should work offline ✓

---

## Troubleshooting

### ❌ "offline_detection_unavailable" Error
**Cause**: best.tflite file not found in assets  
**Fix**: 
1. Verify file exists: `frontend/assets/models/best.tflite`
2. Rebuild app: `flutter clean && flutter pub get`
3. Make sure pubspec.yaml includes the model file

### ❌ Conversion Script Fails
**Error**: "Module 'ultralytics' not found"  
**Fix**: 
```bash
pip install ultralytics torch torchvision
```

### ❌ Backend Won't Start
**Error**: "Model file not found"  
**Fix**:
```bash
# Check if model exists
ls backend/models/rice_disease.pt

# If missing, ensure you have the trained model
# Or set environment variable:
set AI_MODEL_PATH=path/to/model.pt  # Windows
# or: export AI_MODEL_PATH=path/to/model.pt  # macOS/Linux
```

### ❌ App Crashes When Analyzing
**Cause**: TFLite model corrupted or wrong version  
**Fix**:
1. Delete: `frontend/assets/models/best.tflite`
2. Re-run conversion script
3. Rebuild app

---

## Architecture After Setup

```
┌──────────────────────────────────────────────┐
│           User's Device/Emulator             │
├──────────────────────────────────────────────┤
│                 Flutter App                   │
│  ┌─────────────────────────────────────────┐ │
│  │    Take/Upload Image                    │ │
│  └────────────┬────────────────────────────┘ │
│               │                              │
│         ┌─────▼─────┐                       │
│         │ Connected?│                       │
│         └─────┬─────┘                       │
│          ┌────┴────┐                        │
│       YES│         │NO                      │
│         │          │                        │
│    ┌────▼───┐  ┌──▼────────────┐           │
│    │ Online │  │ Offline (if   │           │
│    │ Mode   │  │ available)    │           │
│    └────┬───┘  └──┬────────────┘           │
│         │         │                        │
└─────────┼─────────┼────────────────────────┘
          │         │
      ┌───▼─┐   ┌───▼─────────┐
      │ Backend (PyTorch)  │  │ Frontend        │
      │ API Analysis       │  │ (TFLite Model)  │
      └────────────────────┘  └─────────────────┘
         rice_disease.pt         best.tflite
         (Ultralytics YOLO)     (Converted PyTorch)
```

---

## File Locations

| File | Purpose | Status |
|------|---------|--------|
| `backend/models/rice_disease.pt` | PyTorch model (online) | ✅ Exists |
| `backend/scripts/convert_pytorch_to_tflite.py` | Conversion script | ✅ Created |
| `frontend/assets/models/best.tflite` | TFLite model (offline) | 🔄 To be created |
| `frontend/lib/services/offline_leaf_diagnosis_service.dart` | Offline detection | ✅ Updated |
| `frontend/lib/services/prediction_service.dart` | Analysis routing | ✅ Updated |
| `frontend/lib/screens/scan_screen.dart` | Error messages | ✅ Updated |

---

## Next Steps

1. ✅ **Completed**: Updated error messages (clearer UI)
2. ✅ **Completed**: Created conversion script
3. 🔄 **Now**: Run conversion script (Step 3 above)
4. 🔄 **Then**: Test online and offline modes
5. ⏳ **Future**: Consider model optimization for smaller file size

---

## Support

If you get stuck:
1. Check the detailed guide: `PYTORCH_SETUP_GUIDE.md`
2. Verify all files exist in the locations listed above
3. Check backend logs: `python main.py` (look for model loading messages)
4. Check Flutter logs: `flutter run -v` (verbose output)

---

## Version Info

- **Backend Framework**: FastAPI
- **ML Library**: Ultralytics (YOLO)
- **Model Format (Online)**: PyTorch (.pt)
- **Model Format (Offline)**: TensorFlow Lite (.tflite)
- **Frontend Framework**: Flutter
- **Flutter SDK**: ^3.11.0

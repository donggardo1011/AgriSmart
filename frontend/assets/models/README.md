# Offline Model Files

Place your TFLite model here for offline rice leaf disease detection.

## Steps to Enable Offline Detection:

1. **Convert your PyTorch model to TFLite**:
   - Use the backend's YOLOv8 model (rice_disease.pt)
   - Convert to ONNX, then to TFLite using `tf2onnx` or similar tools
   - Reference: https://github.com/ultralytics/yolov8

2. **Place the model file**:
   - Save the converted model as `best.tflite`
   - Put it in this directory: `assets/models/best.tflite`

3. **Update pubspec.yaml**:
   - Assets are automatically included if this directory has files

4. **Expected Model Format**:
   - Input: RGB image (416x416 or 640x640 depending on model)
   - Output: Detection results with [x, y, w, h, objectness, class_probs...]
   - Classes: `bacterial_blight`, `brown_spot`, `leaf_blast`, `smut`, `tungro`

## Offline Detection Features:
- ✅ Works without internet connection
- ✅ Detects rice leaf diseases locally on device
- ✅ Results are automatically cached
- ✅ Farmers can use the app in remote areas

## Testing:
Once the model is added:
1. Run: `flutter pub get`
2. Rebuild the app: `flutter run`
3. Use the "Detect (Offline)" button in the Scan screen to test offline detection

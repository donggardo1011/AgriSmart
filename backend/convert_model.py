import os
import shutil
import subprocess
import sys

# First, ensure ultralytics is installed
print("Installing required packages...")
subprocess.check_call([sys.executable, "-m", "pip", "install", "-U", "ultralytics", "torch", "torchvision", "-q"])

print("\nStarting TFLite conversion...")
from ultralytics import YOLO

BASE_DIR = os.path.abspath(os.path.dirname(__file__) + "/..")
model_input = os.path.join(BASE_DIR, "models", "versions", "v1.1.0_best.pt")
tflite_output_dir = os.path.join(BASE_DIR, "..", "frontend", "assets", "models")

print(f"Loading model: {model_input}")
assert os.path.exists(model_input), f"Model not found: {model_input}"

os.makedirs(tflite_output_dir, exist_ok=True)

try:
    model = YOLO(model_input)
    print("Model loaded successfully. Exporting to TFLite...")
    result = model.export(format='tflite', imgsz=640, simplify=True)
    print(f"Export result: {result}")
    
    # Check if file was created
    tflite_file = os.path.join(tflite_output_dir, "best.tflite")
    if os.path.exists(tflite_file):
        size_mb = os.path.getsize(tflite_file) / (1024*1024)
        print(f"✓ SUCCESS: best.tflite created ({size_mb:.1f} MB)")
    else:
        print(f"Warning: File not at expected location: {tflite_file}")
        # Find where it was created
        for root, dirs, files in os.walk(tflite_output_dir):
            for f in files:
                if f.endswith('.tflite'):
                    found_path = os.path.join(root, f)
                    print(f"Found TFLite file at: {found_path}")
                    shutil.copy(found_path, tflite_file)
                    print(f"Copied to: {tflite_file}")
                    break
except Exception as e:
    print(f"Error during conversion: {e}")
    import traceback
    traceback.print_exc()

#!/usr/bin/env python3
"""Simple TFLite conversion script"""
import os
import sys

try:
    from ultralytics import YOLO
    print("✓ ultralytics imported successfully")
except ImportError as e:
    print(f"✗ Failed to import ultralytics: {e}")
    print("Installing ultralytics...")
    os.system(f"{sys.executable} -m pip install ultralytics --quiet")
    from ultralytics import YOLO

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
model_input = os.path.join(BASE_DIR, 'models', 'versions', 'v1.1.0_best.pt')
tflite_output_dir = os.path.join(BASE_DIR, '..', 'frontend', 'assets', 'models')

print(f"Base directory: {BASE_DIR}")
print(f"Model input: {model_input}")
print(f"TFLite output directory: {tflite_output_dir}")

if not os.path.exists(model_input):
    raise FileNotFoundError(f'Model not found at: {model_input}')

os.makedirs(tflite_output_dir, exist_ok=True)

print(f'Loading model from {model_input}...')
model = YOLO(model_input)

print('Exporting to TFLite format...')
try:
    exported = model.export(format='tflite', imgsz=640, project=tflite_output_dir, name='best', simplify=True)
    print(f'✓ Export complete!')
    print(f'✓ TFLite file location: {exported}')
except Exception as e:
    print(f'✗ Export failed: {e}')
    # Try alternative approach
    print('Trying alternative export method...')
    exported = model.export(format='tflite', imgsz=640)
    print(f'Alternative export completed: {exported}')

# Verify the file exists
tflite_path = os.path.join(tflite_output_dir, 'best.tflite')
if os.path.exists(tflite_path):
    file_size = os.path.getsize(tflite_path) / (1024 * 1024)  # Convert to MB
    print(f'\n✓ SUCCESS: best.tflite created ({file_size:.2f} MB)')
    print(f'✓ Location: {tflite_path}')
    print('\nYour Flutter app can now use offline detection!')
else:
    print(f'\n✗ WARNING: best.tflite not found at expected location: {tflite_path}')
    print('Check the output above for the actual file location.')

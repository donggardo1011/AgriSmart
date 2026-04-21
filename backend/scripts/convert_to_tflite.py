import os
from ultralytics import YOLO

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
model_input = os.path.join(BASE_DIR, 'models', 'versions', 'v1.1.0_best.pt')
tflite_output_dir = os.path.join(BASE_DIR, '..', 'frontend', 'assets', 'models')

if not os.path.exists(model_input):
    raise FileNotFoundError(f'Model not found: {model_input}')

os.makedirs(tflite_output_dir, exist_ok=True)

print(f'Loading model from {model_input}')
model = YOLO(model_input)
print('Exporting to TFLite...')
exported = model.export(format='tflite', imgsz=640, project=tflite_output_dir, name='best', simplify=True)
print('Export complete:', exported)
print(f'TFLite file should be in {tflite_output_dir}')

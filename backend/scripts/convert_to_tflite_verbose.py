import os
from ultralytics import YOLO

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
model_input = os.path.join(BASE_DIR, 'models', 'versions', 'v1.1.0_best.pt')
output_dir = os.path.join(BASE_DIR, '..', 'frontend', 'assets', 'models')
log_path = os.path.join(BASE_DIR, 'convert_to_tflite.log')

with open(log_path, 'w', encoding='utf-8') as log:
    try:
        log.write(f'Model input: {model_input}\n')
        log.write(f'Output dir: {output_dir}\n')
        log.write(f'model exists: {os.path.exists(model_input)}\n')
        os.makedirs(output_dir, exist_ok=True)
        log.write('Created output dir if needed\n')

        model = YOLO(model_input)
        log.write('Loaded YOLO model\n')

        result = model.export(
            format='tflite',
            imgsz=640,
            project=output_dir,
            name='best',
            simplify=True,
        )
        log.write(f'Export result: {result}\n')
    except Exception as e:
        import traceback
        log.write('Exception:\n')
        traceback.print_exc(file=log)
        raise
    finally:
        log.write('Finished convert_to_tflite_verbose.py\n')

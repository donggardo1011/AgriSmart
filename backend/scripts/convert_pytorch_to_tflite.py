"""
Convert PyTorch YOLO model to TFLite format for offline mobile detection.

Usage:
  python convert_pytorch_to_tflite.py \
    --input-model backend/models/rice_disease.pt \
    --output-model frontend/assets/models/best.tflite \
    --input-size 640
"""

import argparse
import os
import sys
import tempfile
from pathlib import Path

def convert_pytorch_yolo_to_tflite(
    input_model_path: str,
    output_model_path: str,
    input_size: int = 640,
) -> bool:
    """
    Convert a PyTorch YOLO model to TFLite format.
    
    Args:
        input_model_path: Path to rice_disease.pt
        output_model_path: Where to save the .tflite model
        input_size: Model input size (typically 640 for YOLOv8)
    
    Returns:
        True if conversion successful, False otherwise
    """
    try:
        from ultralytics import YOLO
    except ImportError:
        print("ERROR: ultralytics not installed. Install with: pip install ultralytics")
        return False
    
    if not os.path.exists(input_model_path):
        print(f"ERROR: Input model not found at {input_model_path}")
        return False
    
    # Create output directory
    os.makedirs(os.path.dirname(output_model_path), exist_ok=True)
    
    print(f"Loading PyTorch model from: {input_model_path}")
    try:
        model = YOLO(input_model_path)
    except Exception as e:
        print(f"ERROR: Failed to load model: {e}")
        return False
    
    print(f"Converting to TFLite format (input size: {input_size}x{input_size})...")
    try:
        # Export to TFLite format
        # This creates multiple format files, we'll use the .tflite one
        export_result = model.export(
            format='tflite',
            imgsz=input_size,
            device=0,  # Use GPU if available
            half=True,  # Use FP16 for mobile optimization
        )
        
        # The export returns the path to the saved model
        if export_result:
            # Find the .tflite file
            exported_tflite = None
            for file in Path(export_result).parent.glob('*.tflite'):
                exported_tflite = str(file)
                break
            
            if exported_tflite and os.path.exists(exported_tflite):
                # Move to desired output location
                import shutil
                shutil.move(exported_tflite, output_model_path)
                
                # Get file size
                size_mb = os.path.getsize(output_model_path) / (1024 * 1024)
                print(f"✓ Conversion successful!")
                print(f"  Output: {output_model_path}")
                print(f"  Size: {size_mb:.2f} MB")
                return True
        
        print("ERROR: TFLite export did not produce expected output")
        return False
        
    except Exception as e:
        print(f"ERROR: Conversion failed: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Convert PyTorch YOLO model to TFLite for mobile offline detection"
    )
    parser.add_argument(
        '--input-model',
        required=True,
        help='Path to input PyTorch model (e.g., backend/models/rice_disease.pt)'
    )
    parser.add_argument(
        '--output-model',
        required=True,
        help='Path to output TFLite model (e.g., frontend/assets/models/best.tflite)'
    )
    parser.add_argument(
        '--input-size',
        type=int,
        default=640,
        help='Model input size (default: 640)'
    )
    
    args = parser.parse_args()
    
    success = convert_pytorch_yolo_to_tflite(
        input_model_path=args.input_model,
        output_model_path=args.output_model,
        input_size=args.input_size,
    )
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()

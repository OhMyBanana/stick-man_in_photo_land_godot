
import argparse
import json
from pathlib import Path

import cv2
import numpy as np
from ultralytics import YOLO


def generate_terrain(image_path: Path, output_dir: Path):
    if not image_path.exists():
        raise FileNotFoundError(f"Input image not found: {image_path}")

    output_dir.mkdir(parents=True, exist_ok=True)
    # Remove previous results so an old mask cannot be mistaken
    # for the result of the current generation.
    for filename in (
        "terrain_mask.png",
        "terrain_preview.png",
        "terrain_metadata.json",
    ):
        old_file = output_dir / filename
        if old_file.exists():
            old_file.unlink()
    # Load the original photograph.
    image = cv2.imread(str(image_path), cv2.IMREAD_COLOR)

    if image is None:
        raise ValueError(f"Could not read image: {image_path}")

    height, width = image.shape[:2]
    print(f"Loaded image: {width}x{height}")

    # Load a small pretrained instance-segmentation model.
    # The first run downloads the model automatically.
    print("Loading YOLO segmentation model...")
    model = YOLO("yolo11n-seg.pt")

    print("Running segmentation...")
    results = model.predict(
        source=image,
        conf=0.35,
        imgsz=640,
        verbose=False
    )

    result = results[0]

    if result.masks is None or len(result.masks.xy) == 0:
        raise RuntimeError(
            "No objects were detected in this photograph. "
            "Try another image with clearer, more recognizable objects."
        )

    # Start with an empty terrain mask.
    # Grayscale pixels are non-solid in our Godot collision system.
    terrain_mask = np.full(
        (height, width, 3),
        255,
        dtype=np.uint8
    )

    # A separate binary mask makes it easy to combine detections.
    solid_mask = np.zeros((height, width), dtype=np.uint8)

    detected_objects = []

    if result.masks is not None:
        for index, polygon in enumerate(result.masks.xy):
            if len(polygon) < 3:
                continue

            points = np.round(polygon).astype(np.int32)
            points[:, 0] = np.clip(points[:, 0], 0, width - 1)
            points[:, 1] = np.clip(points[:, 1], 0, height - 1)

            cv2.fillPoly(solid_mask, [points], 255)

            class_id = int(result.boxes.cls[index].item())
            confidence = float(result.boxes.conf[index].item())
            class_name = model.names[class_id]

            detected_objects.append({
                "class": class_name,
                "confidence": round(confidence, 3)
            })

    # Color detected areas red.
    # Our current Godot stage map treats colored pixels as solid.
    terrain_mask[solid_mask > 0] = (0, 0, 255)

    # Create a preview by tinting detected objects green.
    preview = image.copy()
    overlay = image.copy()
    overlay[solid_mask > 0] = (0, 220, 0)

    preview = cv2.addWeighted(image, 0.55, overlay, 0.45, 0)

    # Draw a small label so the preview is easy to identify.
    cv2.putText(
        preview,
        f"Detected objects: {len(detected_objects)}",
        (12, 28),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.7,
        (255, 255, 255),
        2,
        cv2.LINE_AA
    )

    mask_path = output_dir / "terrain_mask.png"
    preview_path = output_dir / "terrain_preview.png"
    metadata_path = output_dir / "terrain_metadata.json"

    if not cv2.imwrite(str(mask_path), terrain_mask):
        raise RuntimeError("Could not save terrain mask.")

    if not cv2.imwrite(str(preview_path), preview):
        raise RuntimeError("Could not save terrain preview.")

    metadata = {
        "source": str(image_path.resolve()),
        "width": width,
        "height": height,
        "detected_object_count": len(detected_objects),
        "objects": detected_objects,
        "terrain_mask": str(mask_path.resolve()),
        "terrain_preview": str(preview_path.resolve())
    }

    metadata_path.write_text(
        json.dumps(metadata, indent=2),
        encoding="utf-8"
    )

    print("\nTerrain generation complete!")
    print(f"Objects detected: {len(detected_objects)}")
    print(f"Terrain mask: {mask_path.resolve()}")
    print(f"Preview: {preview_path.resolve()}")
    print(f"Metadata: {metadata_path.resolve()}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate a terrain mask from a photograph."
    )

    parser.add_argument(
        "image",
        help="Path to the source photograph."
    )

    parser.add_argument(
        "--output",
        default="output",
        help="Directory for generated files."
    )

    args = parser.parse_args()

    try:
        generate_terrain(
            Path(args.image),
            Path(args.output)
        )
    except Exception as error:
        print(f"\nERROR: {error}")
        raise

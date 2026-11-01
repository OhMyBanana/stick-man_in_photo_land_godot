
import argparse
import os
import sys
import time
from pathlib import Path

import cv2


def write_error(error_path: Path, message: str):
    try:
        error_path.write_text(message, encoding="utf-8")
    except Exception:
        pass


def replace_with_retry(source: Path, destination: Path) -> bool:
    # Windows may temporarily lock a JPEG while Godot reads it.
    # Retry rather than terminating the camera service.
    for _ in range(20):
        try:
            os.replace(source, destination)
            return True
        except PermissionError:
            time.sleep(0.05)
        except OSError:
            time.sleep(0.05)

    return False


def run_camera(output_dir: Path, device: int):
    output_dir.mkdir(parents=True, exist_ok=True)

    frame_path = output_dir / "camera_frame.jpg"
    temporary_frame_path = output_dir / "camera_frame.tmp"
    stop_path = output_dir / "camera_stop.flag"
    error_path = output_dir / "camera_error.txt"

    for path in (error_path, frame_path, temporary_frame_path):
        if path.exists():
            path.unlink()

    camera = cv2.VideoCapture(device, cv2.CAP_DSHOW)

    if not camera.isOpened():
        message = (
            f"Could not open webcam device {device}. "
            "Check Windows camera permissions and close other apps using the camera."
        )
        write_error(error_path, message)
        return 1

    camera.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
    camera.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

    try:
        while not stop_path.exists():
            success, frame = camera.read()

            if not success:
                write_error(error_path, "The webcam stopped providing frames.")
                return 1

            success, encoded = cv2.imencode(
                ".jpg",
                frame,
                [cv2.IMWRITE_JPEG_QUALITY, 85]
            )

            if not success:
                write_error(error_path, "Could not encode the webcam frame.")
                return 1

            temporary_frame_path.write_bytes(encoded.tobytes())

            if not replace_with_retry(temporary_frame_path, frame_path):
                # Skip this frame; don't terminate the webcam.
                if temporary_frame_path.exists():
                    temporary_frame_path.unlink()

            time.sleep(0.04)

    except Exception as error:
        write_error(error_path, f"{type(error).__name__}: {error}")
        return 1

    finally:
        camera.release()

        if temporary_frame_path.exists():
            temporary_frame_path.unlink()

    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--device", type=int, default=0)
    args = parser.parse_args()

    try:
        sys.exit(run_camera(Path(args.output), args.device))
    except Exception as error:
        error_message = f"{type(error).__name__}: {error}"
        print(error_message, file=sys.stderr)

        output_dir = Path(args.output)
        write_error(output_dir / "camera_error.txt", error_message)

        sys.exit(1)

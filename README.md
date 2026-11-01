# Stick-Man in Photo Land

A Godot 4.7 game where a photograph can become a playable level. Choose an image or capture one with a webcam, generate terrain from detected objects, review the result, and then explore it as the stick figure.

This is a Godot port of a project submitted to the 2020 Hack the Northeast hackathon, originally developed alongside Alex Sananes and Devin Gulati.

## Requirements

- Godot 4.7
- Windows for the integrated Python and webcam workflow
- Python 3.10 (recommended; the setup below uses the Windows Python launcher)

The demo level can be opened in Godot without Python. Photo-to-terrain generation and webcam capture require the Python environment described below.

## Set up the Python environment

Run these commands in PowerShell from the repository root. The environment is created at `terrain_service\.venv`, which is the location the game expects.

```powershell
py -3.10 -m venv .\terrain_service\.venv
& .\terrain_service\.venv\Scripts\python.exe -m pip install --upgrade pip
& .\terrain_service\.venv\Scripts\python.exe -m pip install opencv-python numpy ultralytics
```

`ultralytics` installs PyTorch, which runs the segmentation model. The project includes the `yolo11n-seg.pt` model weights in both the repository root and `terrain_service` directory.

To check the environment:

```powershell
& .\terrain_service\.venv\Scripts\python.exe -c "import cv2, numpy, ultralytics, torch; print('OpenCV', cv2.__version__); print('NumPy', numpy.__version__); print('Ultralytics', ultralytics.__version__); print('PyTorch', torch.__version__)"
```

## Run the game

Open `project.godot` in Godot 4.7 and run the project (F5). On the photo import screen:

1. Choose a PNG, JPEG, WebP, or BMP image, or use the camera.
2. Select **Generate Terrain** and review the generated preview.
3. Accept the terrain to use it in the level, or choose **Play Demo Level** to skip photo generation.

Camera use may require allowing the app through Windows camera privacy settings. The current camera service opens the default Windows camera device (device 0).

## Tools and how they fit together

- **Godot Engine 4.7 and GDScript** provide the game, UI, photo import screen, level editor, and gameplay. The project uses Godot scenes (`.tscn`) and scripts (`.gd`).
- **Godot's GL Compatibility renderer** is configured for rendering. The project selects **Jolt Physics** as its 3D physics engine; the photo-derived 2D terrain is handled through the game's terrain-mask/stage-map system.
- **Python** runs the computer-vision helper scripts. Godot launches the Python interpreter in `terrain_service\.venv` directly; this is a local process-and-files integration, not a web server.
- **OpenCV (`opencv-python`)** reads and writes images and captures webcam frames using Windows DirectShow. The camera helper saves frames under `terrain_service\output`, and the game displays them in its camera preview.
- **NumPy** builds and combines the pixel masks produced from the image segmentation polygons.
- **Ultralytics YOLO11n segmentation** (`yolo11n-seg.pt`) detects and segments recognizable objects in the selected or captured photograph. **PyTorch**, installed as an Ultralytics dependency, runs the model inference.
- **Generated files** connect the Python and Godot sides: `terrain_mask.png` supplies the terrain mask, `terrain_preview.png` is shown for review, and `terrain_metadata.json` records image dimensions and detected objects. When accepted, Godot loads the photograph and mask into the level.

The segmentation script can also be run manually from `terrain_service`:

```powershell
Set-Location .\terrain_service
& .\.venv\Scripts\python.exe .\generate_terrain.py ..\path\to\photo.jpg --output .\output
```

## Gameplay controls

- **A/D** or **Left/Right**: move
- **W**, **Space**, or **Up**: jump
- **R**: restart at the spawn marker
- **T**: toggle the terrain mask
- **Escape**: return to editing

In the editor, choose **Spawn**, **Star**, or **Hazard** and click the level to place a marker. Use **Select / Move** to reposition markers. Place a spawn and star before starting; touching a hazard or falling below the level respawns the player, and touching the star wins.

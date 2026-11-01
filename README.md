# Stick-Man in Photo Land

**Turn photographs into playable worlds.**

Stick-Man in Photo Land is a 2D platforming game built with Godot 4.7. It takes an ordinary photograph, uses computer vision to identify and segment objects within it, and transforms those objects into interactive terrain.

Choose a photograph from your computer or capture one with a webcam. Generate a terrain mask, review the result, and jump into your new environment as a little stick figure.

What started as a project for the 2020 Hack the Northeast hackathon has been revisited and rebuilt in Godot, bringing the original idea into a new game-development environment.

Originally developed alongside **Alex Sananes and Devin Gulati**.

## The Idea

The central mechanic is simple: **your surroundings become the level.**

A photograph is passed through an object-segmentation model. The detected objects become solid terrain, while the original photograph remains visible as the game's background. A custom pixel-based collision system allows the player to interact with the generated environment.

The result is a small experiment in combining game development and computer vision: turning everyday images into spaces to explore.

## Features

- **Photo-to-terrain generation:** Transform existing photographs into playable environments.
- **Live webcam capture:** Take photographs directly from within the game.
- **Computer vision:** Use YOLO11 instance segmentation to identify objects in photographs.
- **Terrain preview:** Review generated terrain before loading it into the level.
- **Custom pixel-mask collision:** Use generated image masks to determine which parts of the world are solid.
- **Level editor:** Place, move, and remove spawn points, goals, and hazards.
- **Demo level:** Explore the game's mechanics without needing to generate terrain.

## Technology

| Component | Technology |
| --- | --- |
| Game engine | Godot 4.7 |
| Game scripting | GDScript |
| Computer vision | Ultralytics YOLO11n-seg |
| Machine learning inference | PyTorch |
| Image processing | OpenCV |
| Numerical processing | NumPy |
| Camera capture | OpenCV / Windows DirectShow |
| Integration | Local Python subprocesses and generated files |

### How It Works

The project uses Godot for the game itself and a separate Python environment for computer vision.

1. **Image acquisition:** The player selects an image or captures one using the webcam.
2. **Object segmentation:** Godot launches a Python process that runs YOLO11n-seg against the photograph.
3. **Mask generation:** OpenCV and NumPy convert the detected segmentation polygons into a terrain mask.
4. **Preview:** A separate visualization shows the detected regions overlaid on the original photograph.
5. **Terrain loading:** Once accepted, Godot loads the original photograph as the background and the generated mask as the collision layer.
6. **Gameplay:** The player interacts with the resulting world using a custom pixel-based collision system.

The Python service runs locally in the background. It is not a web service and does not require an external API.

**A note on segmentation:** YOLO11n-seg is trained to recognize objects from the COCO dataset. It does not inherently understand platforming geometry or distinguish good platforms from obstacles. The generated terrain is therefore an experimental interpretation of the photograph rather than a guaranteed playable level.

## Requirements

- Godot 4.7
- Windows for the integrated Python and webcam workflow
- Python 3.10
- A webcam for live capture (optional)

The demo level can be played without installing Python. Photo-based terrain generation and webcam capture require the Python environment below.

## Setup

### 1. Clone the repository

```powershell
git clone https://github.com/OhMyBanana/stick-man_in_photo_land_godot.git
Set-Location .\stick-man_in_photo_land_godot
```

### 2. Create the Python environment

Run the following commands in PowerShell from the repository root:

```powershell
py -3.10 -m venv .\terrain_service\.venv

.\terrain_service\.venv\Scripts\python.exe -m pip install --upgrade pip

.\terrain_service\.venv\Scripts\python.exe -m pip install opencv-python numpy ultralytics
```

Ultralytics installs PyTorch as a dependency.

The game expects the virtual environment at `terrain_service\.venv`.

### 3. Verify the installation

```powershell
.\terrain_service\.venv\Scripts\python.exe -c "import cv2, numpy, ultralytics, torch; print('OpenCV:', cv2.__version__); print('NumPy:', numpy.__version__); print('Ultralytics:', ultralytics.__version__); print('PyTorch:', torch.__version__)"
```

### 4. Open the project

Open `project.godot` in Godot 4.7 and run the project with **F5** (or run the current scene with **F6**).

On the photo import screen, you can:

- Choose an existing PNG, JPEG, WebP, or BMP image.
- Open the webcam and capture a photograph.
- Generate and review terrain.
- Accept the generated terrain and start playing.
- Skip image generation and play the demo level.

Windows camera privacy settings may need to permit webcam access. The current implementation uses the default camera device (device 0).

## Running Terrain Generation Manually

The Python segmentation script can also be run independently of Godot. From the repository root:

```powershell
.\terrain_service\.venv\Scripts\python.exe `
    .\terrain_service\generate_terrain.py `
    .\path\to\photo.jpg `
    --output .\terrain_service\output
```

The generator produces:

| File | Description |
| --- | --- |
| `terrain_mask.png` | Generated solid-terrain mask |
| `terrain_preview.png` | Original photograph with detected regions highlighted |
| `terrain_metadata.json` | Image dimensions and detected object information |

## Gameplay

### Controls

| Input | Action |
| --- | --- |
| A / D or Left / Right | Move |
| W / Space / Up | Jump |
| R | Respawn at the spawn marker |
| T | Toggle terrain mask visibility |
| Escape | Return to the level editor |

### Level Editor

The built-in editor allows you to place and reposition three types of objects:

- **Spawn:** Where the player starts.
- **Star:** The level's goal.
- **Hazard:** An obstacle that resets the player on contact.

Select an object type and click the level to place it. Use **Select / Move** to reposition existing objects.

Touching a hazard or falling below the level resets the player to the spawn point. Reach the star to complete the level.

## Project Background

This project began as a hackathon experiment for **Hack the Northeast 2020**, developed with Alex Sananes and Devin Gulati.

The current version is a Godot-based continuation of that original idea, rebuilding the game and its photo-to-terrain pipeline while exploring how computer vision can be used as a game mechanic.

It's a small project, but one built around an idea I've wanted to revisit: what if the world around you could become your game?

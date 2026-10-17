"""Convert the artist's rigged FBX clips to Pip's compact, textured GLB.

Run from the repository root: python3 tools/build_yellow_chick.py
The owner-supplied source archive stays in .local/archive/bird-authoring/Yellow_Chick,
outside Git and Godot's runtime project. No model geometry is created by this converter.
"""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / ".local/archive/bird-authoring/Yellow_Chick"
GODOT = ROOT / "builds/linux/Godot"
OUTPUT = ROOT / "vocab-box/models/YellowChick_animated.glb"
FBX = SOURCE / "Animation_files/Chick_animations_FBX"
TEXTURE = SOURCE / "Textures/Yellow_Chick/lambert7_Base_color.png"


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="yellow-chick-") as temporary:
        project = Path(temporary)
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Yellow Chick Converter"\n')
        for clip in ("Chick_idle", "Chick_flying", "Chick_feeding"):
            shutil.copy2(FBX / f"{clip}.fbx", project / f"{clip}.fbx")
        shutil.copy2(TEXTURE, project / TEXTURE.name)
        shutil.copy2(ROOT / "tools/build_yellow_chick.gd", project / "build.gd")

        # Isolate Godot's editor cache and preferences from the game project.
        environment = os.environ.copy()
        environment["XDG_DATA_HOME"] = str(project / "data")
        environment["XDG_CONFIG_HOME"] = str(project / "config")
        subprocess.run([str(GODOT), "--headless", "--editor", "--path", str(project), "--import"], check=True, env=environment)
        subprocess.run(
            [str(GODOT), "--headless", "--path", str(project), "--script", "res://build.gd", "--", str(OUTPUT)],
            check=True,
            env=environment,
        )
    print(f"Pip model ready: {OUTPUT}")


if __name__ == "__main__":
    main()

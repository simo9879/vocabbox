VOCAB BOX — Windows x86_64 prototype
Run vocab-box.exe (double-click it, or start it from a command prompt).
WASD/arrows move; mouse looks; E interacts; Escape pauses; H asks Pip; R replays Pip.
Choose answers with the mouse. Triangle buttons read choices aloud.

Keep vocab-box.exe and vocab-box.pck in the same folder. The game reads its data
from the .pck file and will not start if the two are separated.

For spoken answers, run run-with-speech.cmd (double-click it), or run-with-speech.ps1
from a PowerShell window. Either one sets ELEVENLABS_API_KEY and AI_API_KEY for that
one run only, then writes vocab-speech.log next to the game so the speech setup and
any failure can be read afterwards. From PowerShell directly:
    powershell -ExecutionPolicy Bypass -File .\run-with-speech.ps1
Keys pasted into a shared copy of this bundle can be read by anyone who has it.

No Godot installation, microphone or speech engine is needed. This build uses the
authored answer choices: spoken-answer mode stays off until API keys are configured.
It was exported from Godot 4.7.2 with the official release templates and needs a
Windows desktop with working OpenGL 3.3 graphics and audio.

Windows SmartScreen may warn because the executable is not code-signed. If you trust
the source, choose "More info" and then "Run anyway".

See GODOT-LICENSES.txt for engine and bundled third-party notices, and
ASSET-CREDITS.md for art licensing. Best stars and preferences are saved under
%APPDATA%\Godot\app_userdata\Vocab Box — A little adventure in English

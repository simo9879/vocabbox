# Vocab Box — Godot prototype specification

## Product and scope
A cozy, colorful, fully playable 3D English-learning adventure for children aged 8–12. A first visit should take approximately 5–10 minutes. Desktop keyboard/mouse is the first target; mobile, AI, speech recognition, free text, additional missions, accounts, cloud saves, multiplayer, currency, general inventory and customization are excluded.

Use Godot 4/GDScript in `vocab-box/`. Reusable player, orbit camera, companion, dialogue UI, interactable, city and supermarket scenes must remain separate. Editable Godot lesson resources hold lesson wording, feedback, objectives and voice references. Authored response evaluation takes encounter ID and response ID and returns quality, feedback, suggested wording and progression permission. It is independent of presentation and mission state and must not imply arbitrary language understanding.

## World and controls
One compact bounded city block, sidewalks, clear supermarket signage and decorative future destinations with visibly unavailable doors. Only the supermarket can be entered. A separate supermarket scene contains a worker, produce, customer, checkout, entrance and readable routes between stocked shelves. Use cohesive stylized materials, soft lighting and interaction cues. Existing assets may be reused only when redistribution rights and style are suitable; replace unclear assets before distributing.

The player has grounded collision, smooth camera-relative movement and idle/walk animation. WASD/arrows move, mouse orbits, E interacts, Escape pauses or closes dialogue. No jumping, combat, vehicles or platforming. Dialogue stops movement and releases the cursor; closing restores controls. Use named Input Map actions for future touch/controller reuse. The elevated smooth-follow camera limits pitch and avoids walls.

Pip is a small colorful nonblocking bird that hovers near the player's shoulder, including during conversations. Its wings keep flapping while the player stands still, moves, talks, or celebrates. UI includes objectives, interaction prompts, dialogue, feedback, pause/settings and results; readable large type and symbols supplement colors. Layout must work at 1280×720 and 1920×1080 and resize gracefully.

## Mission: Let’s buy some bananas!
| Stage | Activity | Completion |
|---|---|---|
| City | Explore and approach the market | Interact with entrance |
| Introduction | Receive checklist and Pip’s suggestion | Dismiss introduction |
| Worker | Ask for directions | Understandable or strong response |
| Produce | Collect bananas | One bunch |
| Customer | Have a short conversation | Relevant response |
| Checkout | Request purchase | Understandable or strong response |
| Results | Review stars and practiced phrases | Return to city or replay |

The four-item checklist is ask worker, collect bananas, talk to customer, check out. Exploration is free; completion order is guarded explicitly. Prevent duplicate collection, early checkout and repeated completion. Conversations can close/reopen without losing progress. Show a brief fade and use explicit entry/exit markers for transitions. Leaving an unfinished shop attempt requires confirmation and resets that attempt. Restart/replay must reset objectives and inventory consistently.

## Teaching and feedback
Each scored encounter presents three shuffled authored choices:
- Needs practice: unclear, unrelated or meaning-obstructing grammar. Brief specific explanation, then retry.
- Understandable: successful communication. Allow progression and optionally try a stronger answer.
- Strong: clear, appropriate, polite where relevant. Brief encouragement.

Worker examples: “Where bananas is?”, “Where are the bananas?”, “Excuse me, could you tell me where the bananas are?” Explicitly acknowledge the middle response is correct English. Teach politeness without marking valid language wrong. Author equivalent beginner-level customer and checkout choices, NPC replies and contextual feedback.

After two unsuccessful attempts, highlight a suitable answer and read it on request; the child still selects it. No timers, lives, shame or permanent penalties. After about 20 seconds without objective progress, give one automatic hint per stage. Keep bird help available.

Track the best quality reached in each encounter. One star for completion, two for at least two strong conversations, three for all three. Retries and hints never reduce scores. Results explain scoring and show the three strongest practiced phrases. Never score speed, pronunciation or spelling.

## Audio and persistence
Bundle temporary system-generated English speech during development; do not require a speech engine at runtime. Missing clips must not block play, but voiced content is required for acceptance. Every spoken line has matching subtitles and replay. Read choices only on demand; serialize speech playback. Include ambient city/shop audio, footsteps and interaction sounds. Separate voice, music and effects volume controls.

Persist best stars and preferences locally. Best stars never decrease. Unfinished missions restart after application closure. Title: Play, Settings, Quit. Pause: Resume, Restart Mission when applicable, Settings, Quit to Title.

## Acceptance and delivery
Verify the full city → shop → results → city loop; each quality, optional retry, assistance and star outcome; duplicate/order guards; leaving, restarting, reopening and replaying; persistent best scores; camera, entrances, aisles and bird behavior; subtitles, replay, mixing and volume controls; 720p/1080p UI and resizing. Run automated model/evaluation/star/save tests and an actual desktop playthrough. Record host hardware and measured frame rate; target stable 60 FPS at 1080p, without claiming mobile verification.

Deliver this spec, editable source/assets, asset credits, offline audio-generation instructions and a tested desktop bundle. Record actual verification and remaining limitations separately in `verification.md` rather than implying every target is achieved.

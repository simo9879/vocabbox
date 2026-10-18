# UI migration checklist

Checked means the screen is laid out with authored Godot controls, with its presentation stored in a scene and shared resources. The game still supplies text, values, and actions at runtime. This checklist tracks the goal of removing code-built game UI; it does not certify a rendered visual review.

## Menus and screens

- [x] Start menu — `scenes/ui/title_menu.tscn`
- [x] Pause menu — `scenes/ui/pause_menu.tscn`
- [x] Settings menu — `scenes/ui/settings_menu.tscn`; chalk slider tracks and handles are authored assets
- [ ] Market introduction — currently built in `scripts/main.gd` using the shared dialogue panel
- [ ] Leave confirmation — currently built in `scripts/main.gd` using the shared dialogue panel
- [ ] Conversation — worker, customer, and cashier currently share code-built dialogue controls
- [ ] Answer feedback — retry, stronger answer, and continue states currently use code-built controls
- [ ] Results — stars, scoring explanation, practiced phrases, and actions currently use code-built controls

## Other game UI

- [ ] Objective HUD and four-item checklist
- [ ] Nearby interaction prompt and Pip help button
- [ ] Subtitles and replay cue
- [ ] Travel fade overlay
- [ ] Floating interaction labels in the world
- [ ] Supermarket signs created through `Art.sign_text()`

Dialogue and subtitles were deferred by the owner during the blackboard menu work. The existing city storefront signs are already authored in `city_shops.tscn`.

## Review still needed

- [ ] Rendered check of the final chalk slider track correction. The owner saw the preceding Settings version with visible handles but missing tracks; a headless check confirmed the corrected track height.
- [ ] Visual check of the centered boards at 1280×720 and 1920×1080. Headless content-fit and focus checks passed.

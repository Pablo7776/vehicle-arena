# Settings + Menus

Free, polished main menu / pause / options / credits template for Godot 4.5+. Persistent settings, audio buses, resolution + window mode, key rebinding, accessibility (font scale, colorblind filter, reduce motion, per-effect toggles).

It's free to use in any project, and it pairs with the selodev RPG Toolkit. Settings live in their own file (`user://settings.json`), apart from any save slot, so deleting a save never loses them.

## What's inside

```
addons/settings_menus/    ← copy this folder into your project
demo/                     ← runnable main-menu → game → pause loop
docs/                     ← quick start + theming + cross-promo
LICENSE
CHANGELOG.md
```

## 5-minute install

1. Copy `addons/settings_menus/` into your project's `addons/` folder.
2. Project → Project Settings → Plugins → enable **Settings + Menus**.
3. Set your main scene to a script that instantiates `MainMenuUI` (or use a packed scene with one as the root, see `demo/main_menu_scene.tscn`).
4. Set `play_scene_path` to your gameplay scene.
5. Drop a `PauseMenuUI` into your gameplay scene root.
6. Press Play.

See [docs/quick-start.md](docs/quick-start.md) for the worked example.

## Features

- `MainMenuUI`: Play / Options / Credits / Quit, configurable scene path.
- `PauseMenuUI`: listens for the `pause` action and pauses the tree. Resume / Options / Main Menu / Quit.
- `OptionsMenuUI`: tabbed. Audio (master / music / sfx buses), Display (window mode + resolution + vsync + fps counter), Controls (one-click key rebind for any project action), Accessibility (font scale, colorblind filter, reduce motion, and a toggle each for camera shake, motion blur, chromatic aberration, film grain and depth of field).
- `CreditsUI`: scrolling credits authored as a single multiline string with `#` headings.
- `KeyRebindRow`: drop-in row for one rebindable action, with its keyboard and mouse binding and its gamepad binding rebound separately. Used by the Controls tab, and reusable in your own UIs.
- `MenuTheme` Resource: recolor every menu in one swap. Brand title + subtitle + background.
- `Settings` autoload: settings dict with `get_value` / `set_value` / `reset_to_defaults`, persisted to `user://settings.json` in its own file so it survives deleting every save slot. Redirect it with `Settings.save_file`.
- Per-feature quality: a Graphics tab with shadows, textures, effects, view distance and post processing set separately, not one preset slider. Appears only when something is installed that can act on it.
- Effect toggles: `Settings.is_effect_enabled("film_grain")` and the `effects_changed` signal. Reduce Motion switches camera shake and motion blur off without forgetting how the player had them set. This pack decides, your game applies.
- Key rebinding persisted as serialized events. Keys, mouse buttons, and gamepad buttons, triggers and sticks supported.

## Status

v1.8.1. Tested against Godot 4.5+ (verified on 4.5 and 4.7). Pure GDScript. MIT licensed.

## License

MIT. See `LICENSE`.

## Want more?

If you want the rest of the systems (Save, Inventory, Equipment, Loot, Crafting, Vendor, Quests, Stats / Skill Trees), see [docs/cross-promo.md](docs/cross-promo.md).

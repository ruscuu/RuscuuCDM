# Changelog

## v0.4.0

**New**
- **Golden border when a cooldown is ending**, on action buttons and Cooldown Manager icons. Uses Blizzard's color curve API, so the addon never reads the remaining time. Customizable: last seconds (0.5–30 s), color with opacity, thickness, soft glow and its size, blink style (none / smooth pulse / flash), speed and depth. All borders blink in sync.
- **Choose which spells get the golden border** (per profile).
- **Choose which cooldowns are shown**: a button (and `/rcm cooldowns`, or Shift + click on the minimap button) opens Blizzard's Advanced Cooldown Settings, where you drag spells to "Not Displayed".
- **Enable Blizzard's Cooldown Manager on install** (only once — if you turn it off later, the addon respects it).
- New options for everything the addon changes: square icons, icon crop, class color border, swipe (show, color, edge, finish flash), bar texture (SharedMedia supported), bar color and background, font and outline for every text, charges and stacks size/color, buff bar text size, action bar number color/size/outline, which action bars are styled, minimap lock, chat messages and language.
- **Live preview** in the options, a **Test for 5 seconds** button for the golden border, a **Defaults** button on every page, and help on every control.
- New themes: **Class color** and **Blizzard style**. The current theme is highlighted.
- Profiles: **Rename**, **Duplicate**, and a profile for characters without a specialization.
- Slash commands are now **`/rcm`** and **`/rcmf`** (they replace `/ruscuu` and `/rcdm`).

**Fixed**
- At login the Default profile was applied before your specialization's profile.
- The golden border could become invisible (the extra GCD filter is gone: the game already ignores the global cooldown).
- Blizzard's round frame was still drawn over square icons.
- Turning an option off needed a reload; now everything goes back to Blizzard's look immediately.
- The game's "Show numbers for cooldowns" setting was overwritten at every login; now you choose: always / never / leave the game setting.
- Works on clients without the global `GetSpecialization` (uses `C_SpecializationInfo`).
- "Reset" always resets the profile named in the dialog; `/rcm reset` asks for confirmation.
- Imports with unknown fonts are rejected; a missing font falls back to the game font.

## v0.3.0

- **English and Spanish** — the addon follows the game language (esES/esMX → Spanish, everything else → English).
- **Themes** — Ruscuu Neon, Minimal, Dark and Classic, applied with one click.
- **Profiles** — create, copy, delete and reset profiles; assign a profile to each specialization and it switches automatically.
- **Import / Export** — share your style as a `!RUSCUU:1!` text string.
- Settings from previous versions are moved to the `Default` profile automatically.

## v0.2.0

- Cooldown numbers on the Cooldown Manager and on action bars, with custom color and size.
- Minimap button with the Ruscuu bear and addon compartment entry.

## v0.1.0

- First version: Ruscuu style (square icons, purple borders and bars) for Blizzard's Cooldown Manager.

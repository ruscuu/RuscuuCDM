# Changelog

## v0.7.1

**Fixed**
- Threat meter: in combat the bar stayed purple ("hidden by the game") even when the enemy was attacking you. The game hides the threat level in combat, but the addon now passes it to a color curve, so the bar shows the right color (green, yellow, orange or red) without reading the value.
- Threat meter: changing the width (and the other size, position and color options) now updates the meters already on screen right away.

## v0.7.0

**New**
- **Threat meter on enemy nameplates**: above each enemy you are fighting, your threat as a bar, a percentage or both (100% means you would pull it), colored by the danger: low, about to pull it, pulled but barely, and attacking you. New **Threat** options page: what to show, width, height, position, every color, the number's size, color and place, and a 10-second test to adjust it out of combat. Needs enemy nameplates turned on (V key).

**Fixed**
- Shooting with a wand no longer makes every cooldown light up: the golden border on the Cooldown Manager and action buttons, and the active cooldowns bar, now ignore the short lock each wand shot puts on all spells (the game doesn't report it as the global cooldown). Real cooldowns keep showing while you shoot.
- `/rcm debug` shows which spell is used to recognize that lock.

## v0.6.2

**Fixed**
- Characters of different classes no longer mix their spells and icons. Each class now gets its **own profile** the first time you log in with it (a copy of Default's look, without spells from other classes), used by every specialization until you pick another one.
- Even when a profile is shared on purpose, a spell your character doesn't know never shows up in the active cooldowns bar.

## v0.6.1

**Changed**
- The addon now appears under the **Combat** category in the game's addon list.

## v0.6.0

**New** (Active cooldowns bar)
- **Test for 10 seconds**: fills the bar with your chosen spells so you can see its size, spacing and position.
- **Move the bar freely**: on the essential cooldowns (as before) or free on the screen, with horizontal and vertical position. **Unlock to drag** it with the mouse.
- **Order**: new "Active cooldowns: order and sound" page to move each icon left or right.
- **Sound when ready**: mark the spells that should play a sound when their cooldown ends, and choose the sound.
- **Items**: add potions, healthstones or any item by ID or name; the icon shows how many you have.
- **Buff bars too**: buffs that the Cooldown Manager shows as bars go into the line as an icon, with their time left on it.
- **Hide when mounted** (or in a vehicle) and **hide while resting**.

**Other**
- The addon is now also published on Wago Addons.

## v0.5.2

**Fixed**
- Active cooldowns bar: when casting a spell with nothing on cooldown, every spell could pop up for a moment (the global cooldown) and then disappear with a flash. Now a spell only appears once the game confirms its cooldown is real, and short cooldowns leave without a flash.

## v0.5.1

**New**
- **Show the active cooldowns bar**: always, only in combat, hidden, or like the essential cooldowns (as before, the default).
- **- and + buttons** next to every slider value, to adjust one step at a time.

**Changed**
- The mouse wheel no longer changes slider values, so scrolling the options page never changes a setting by accident.

## v0.5.0

**New**
- **Active cooldowns bar**: a bar of the addon's own that shows only the cooldowns that are running, in one line centered where the essential cooldowns are, with the active buffs of the Cooldown Manager next to them. Blizzard's essential and utility icons are hidden while it is on (off by default).
  - **Choose any spell**: the Cooldown Manager's spells come checked; uncheck any of them or add any spell of your spellbook (pet spells and flyouts too), any other spell by its ID or name, and your trinkets. New "Active cooldowns" options page with a search box.
  - **Icon size and spacing** of your own, and the buffs are resized to match.
  - Spells with charges show while a charge is recharging, with the number of charges. The global cooldown doesn't count, and when a cooldown ends its icon stays one second with a flash.
  - Spells with several ranks show once in the list, and their icon shows whichever rank you cast.
  - Keybinds, golden border, swipe, numbers and borders follow your style. Everything goes back to normal while Edit Mode or Blizzard's cooldown settings are open.
- **Keybinds on Cooldown Manager icons**: each cooldown shows the key that casts it, taken from your action bars (also from form, stance and stealth bars). Customizable size, color, outline and corner. On by default.
- **Border when a buff is about to end**, on the Cooldown Manager's buff icons and bars, with its own color and seconds (off by default). Like the golden border, the game decides when it shows: the addon never reads the remaining time.
- **Bartender4, Dominos and ElvUI**: their action buttons get the styled numbers, the golden border and keybinds too (new "Bars from other addons" checkbox).
- **Class color bars** option for the buff bars (the Class color theme turns it on).
- **Type exact values** in the sliders.
- **Square minimaps** (Leatrix Plus, SexyMap…): the minimap button follows the square edge.
- **New languages**: German, French, Portuguese and Russian.
- **Reload UI** button on every options page.

**Fixed**
- The first time you opened an options page after logging in or `/reload`, it was blank until you went to another page and came back.
- The global cooldown no longer lights up the golden border on every button when you cast a spell.
- The color picker could stay open after Accept or Cancel. Now it always closes, and if something fails the error is shown in the chat.

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

# Ruscuu Cooldown Manager Forever

*[Español abajo](#español)*

Ruscuu visual style for Blizzard's **Cooldown Manager** in **World of Warcraft: Forever**: square icons with neon purple borders, purple bars, styled cooldown numbers, a pulsing golden border when a cooldown is about to end, and one-click themes.

It only changes how things look — it never reads combat data, so it follows Forever's addon restrictions. Everything it changes can be customized and goes back to Blizzard's look instantly when you turn it off.

## Features

- Ruscuu style for the four Cooldown Manager viewers (essential, utility, buff icons, buff bars): square icons, icon crop, borders (custom or class color), swipe color, swipe edge, finish flash, bar texture and colors (custom or class color).
- **Keybinds on Cooldown Manager icons**: the key that casts each spell, taken from your action bars.
- **Golden border** during the last seconds of a cooldown, on action buttons and Cooldown Manager icons: seconds, color, thickness, glow and blink style/speed — and you choose which spells get it.
- **Border when a buff is about to end**, on the Cooldown Manager's buff icons and bars.
- **Choose which cooldowns are shown** through Blizzard's own Advanced Cooldown Settings, one click away.
- **Cooldown numbers** on the Cooldown Manager and action bars: font, size, outline and color for every text.
- Works with **Bartender4, Dominos and ElvUI** action bars.
- **Themes:** Ruscuu Neon, Minimal, Dark, Class color and Blizzard style.
- **Profiles per specialization** that switch automatically, plus rename, duplicate and reset.
- **Import / Export** your style as a text string to share it.
- Options with live preview, help on every control, values you can type and a Defaults button on each page.
- Minimap button with the Ruscuu bear (round or square minimaps).
- English, Spanish, German, French, Portuguese and Russian.

## Commands

| Command | Description |
|---|---|
| `/rcm` or `/rcmf` | Open options |
| `/rcm cooldowns` | Choose which cooldowns are shown (Blizzard's panel) |
| `/rcm test` | Preview the golden border for 5 seconds |
| `/rcm skin` | Reapply the style |
| `/rcm minimap` | Show or hide the minimap button |
| `/rcm debug` | Diagnostic information |
| `/rcm reset` | Reset all settings (asks first) |

---

## Español

Estilo visual Ruscuu para el **Cooldown Manager** de Blizzard en **World of Warcraft: Forever**: iconos cuadrados con borde morado neón, barras moradas, números de cooldown con estilo, un borde dorado que parpadea cuando un cooldown está a punto de terminar y temas con un clic.

Solo cambia la apariencia; no lee datos de combate, así que respeta las restricciones de addons de Forever. Todo lo que cambia se puede personalizar y vuelve al aspecto de Blizzard al momento si lo desactivas.

### Funciones

- Estilo Ruscuu para los cuatro visores del Cooldown Manager (esenciales, utilidad, buffs en iconos y en barras): iconos cuadrados, recorte, bordes (color propio o de clase), color del barrido, línea del barrido, destello al terminar, textura y colores de las barras (color propio o de clase).
- **Atajos de teclado en los iconos del Cooldown Manager**: la tecla que lanza cada hechizo, según tus barras de acción.
- **Borde dorado** en los últimos segundos de un cooldown, en los botones de acción y en los iconos del Cooldown Manager: segundos, color, grosor, resplandor y tipo/velocidad de parpadeo; y eliges a qué hechizos se aplica.
- **Borde cuando un buff va a terminar**, en los iconos y barras de buffs del Cooldown Manager.
- **Elige qué cooldowns se muestran** desde el panel de Ajustes avanzados de habilidades de Blizzard, a un clic.
- **Números de cooldown** en el Cooldown Manager y en las barras de acción: fuente, tamaño, contorno y color de cada texto.
- Funciona con las barras de **Bartender4, Dominos y ElvUI**.
- **Temas:** Ruscuu Neón, Minimalista, Oscuro, Color de clase y Estilo Blizzard.
- **Perfiles por especialización** que cambian solos, además de renombrar, duplicar y restablecer.
- **Importar / Exportar** tu estilo como texto para compartirlo.
- Opciones con vista previa en vivo, ayuda en cada control, valores que se pueden escribir y botón de valores por defecto en cada página.
- Botón en el minimapa con el oso Ruscuu (minimapa redondo o cuadrado).
- Inglés, español, alemán, francés, portugués y ruso.

### Comandos

| Comando | Qué hace |
|---|---|
| `/rcm` o `/rcmf` | Abre las opciones |
| `/rcm cooldowns` | Elige qué cooldowns se muestran (panel de Blizzard) |
| `/rcm test` | Muestra el borde dorado durante 5 segundos |
| `/rcm skin` | Reaplica el estilo |
| `/rcm minimap` | Muestra u oculta el botón del minimapa |
| `/rcm debug` | Información de diagnóstico |
| `/rcm reset` | Borra toda la configuración (pide confirmación) |

## Publishing / Publicación

Every push and pull request runs the **Check** workflow: Lua syntax, `luacheck` and `tools/check_locales.py` (every text translated in every language). Run them locally with `luacheck .` and `python3 tools/check_locales.py`.

Pushing a tag like `v0.5.0` runs the GitHub Action that packages the addon and uploads it to CurseForge and GitHub Releases (and Wago if configured). Required repository secret: `CF_API_KEY` (and `WAGO_API_TOKEN` plus `## X-Wago-ID` in `RuscuuCDM.toc` for Wago).

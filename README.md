# Ruscuu Cooldown Manager Forever

*[Español abajo](#español)*

Ruscuu visual style for Blizzard's **Cooldown Manager** in **World of Warcraft: Forever**: square icons with neon purple borders, purple bars, styled cooldown numbers, a pulsing golden border when a cooldown is about to end, and one-click themes.

It only changes how things look — it never reads combat data, so it follows Forever's addon restrictions. Everything it changes can be customized and goes back to Blizzard's look instantly when you turn it off.

## Features

- Ruscuu style for the four Cooldown Manager viewers (essential, utility, buff icons, buff bars): square icons, icon crop, borders (custom or class color), swipe color, swipe edge, finish flash, bar texture and colors.
- **Golden border** during the last seconds of a cooldown, on action buttons and Cooldown Manager icons: seconds, color, thickness, glow and blink style/speed — and you choose which spells get it.
- **Choose which cooldowns are shown** through Blizzard's own Advanced Cooldown Settings, one click away.
- **Cooldown numbers** on the Cooldown Manager and action bars: font, size, outline and color for every text.
- **Themes:** Ruscuu Neon, Minimal, Dark, Class color and Blizzard style.
- **Profiles per specialization** that switch automatically, plus rename, duplicate and reset.
- **Import / Export** your style as a text string to share it.
- Options with live preview, help on every control and a Defaults button on each page.
- Minimap button with the Ruscuu bear. English and Spanish.

## Commands

| Command | Description |
|---|---|
| `/ruscuu` or `/rcdm` | Open options |
| `/ruscuu cooldowns` | Choose which cooldowns are shown (Blizzard's panel) |
| `/ruscuu test` | Preview the golden border for 5 seconds |
| `/ruscuu skin` | Reapply the style |
| `/ruscuu minimap` | Show or hide the minimap button |
| `/ruscuu debug` | Diagnostic information |
| `/ruscuu reset` | Reset all settings (asks first) |

---

## Español

Estilo visual Ruscuu para el **Cooldown Manager** de Blizzard en **World of Warcraft: Forever**: iconos cuadrados con borde morado neón, barras moradas, números de cooldown con estilo, un borde dorado que parpadea cuando un cooldown está a punto de terminar y temas con un clic.

Solo cambia la apariencia; no lee datos de combate, así que respeta las restricciones de addons de Forever. Todo lo que cambia se puede personalizar y vuelve al aspecto de Blizzard al momento si lo desactivas.

### Funciones

- Estilo Ruscuu para los cuatro visores del Cooldown Manager (esenciales, utilidad, buffs en iconos y en barras): iconos cuadrados, recorte, bordes (color propio o de clase), color del barrido, línea del barrido, destello al terminar, textura y colores de las barras.
- **Borde dorado** en los últimos segundos de un cooldown, en los botones de acción y en los iconos del Cooldown Manager: segundos, color, grosor, resplandor y tipo/velocidad de parpadeo; y eliges a qué hechizos se aplica.
- **Elige qué cooldowns se muestran** desde el panel de Ajustes avanzados de habilidades de Blizzard, a un clic.
- **Números de cooldown** en el Cooldown Manager y en las barras de acción: fuente, tamaño, contorno y color de cada texto.
- **Temas:** Ruscuu Neón, Minimalista, Oscuro, Color de clase y Estilo Blizzard.
- **Perfiles por especialización** que cambian solos, además de renombrar, duplicar y restablecer.
- **Importar / Exportar** tu estilo como texto para compartirlo.
- Opciones con vista previa en vivo, ayuda en cada control y botón de valores por defecto en cada página.
- Botón en el minimapa con el oso Ruscuu. Inglés y español.

### Comandos

| Comando | Qué hace |
|---|---|
| `/ruscuu` o `/rcdm` | Abre las opciones |
| `/ruscuu cooldowns` | Elige qué cooldowns se muestran (panel de Blizzard) |
| `/ruscuu test` | Muestra el borde dorado durante 5 segundos |
| `/ruscuu skin` | Reaplica el estilo |
| `/ruscuu minimap` | Muestra u oculta el botón del minimapa |
| `/ruscuu debug` | Información de diagnóstico |
| `/ruscuu reset` | Borra toda la configuración (pide confirmación) |

## Publishing / Publicación

Pushing a tag like `v0.4.0` runs the GitHub Action that packages the addon and uploads it to CurseForge and GitHub Releases (and Wago if configured). Required repository secret: `CF_API_KEY` (and `WAGO_API_TOKEN` plus `## X-Wago-ID` in `RuscuuCDM.toc` for Wago).

# Ruscuu Cooldown Manager Forever

*[Español abajo](#español)*

Ruscuu visual style for Blizzard's **Cooldown Manager** in **World of Warcraft: Forever**: square icons with neon purple borders, purple bars, cooldown numbers and one-click themes.

It only changes how things look — it never reads combat data, so it follows Forever's addon restrictions.

## Features

- Ruscuu style for the four Cooldown Manager viewers (essential, utility, buff icons, buff bars).
- **Themes:** Ruscuu Neon, Minimal, Dark and Classic.
- **Profiles per specialization** that switch automatically.
- **Import / Export** your style as a text string to share it.
- **Cooldown numbers** on the Cooldown Manager and action bars, with custom color and size.
- Minimap button with the Ruscuu bear.
- English and Spanish.

## Commands

| Command | Description |
|---|---|
| `/ruscuu` or `/rcdm` | Open options |
| `/ruscuu skin` | Reapply the style |
| `/ruscuu debug` | Show which Blizzard viewers were found and the active profile |
| `/ruscuu minimap` | Show or hide the minimap button |
| `/ruscuu reset` | Reset all settings |

---

## Español

Estilo visual Ruscuu para el **Cooldown Manager** de Blizzard en **World of Warcraft: Forever**: iconos cuadrados con borde morado neón, barras moradas, números de cooldown y temas con un clic.

Solo cambia la apariencia; no lee datos de combate, así que respeta las restricciones de addons de Forever.

### Funciones

- Estilo Ruscuu para los cuatro visores del Cooldown Manager (esenciales, utilidad, buffs en iconos y en barras).
- **Temas:** Ruscuu Neón, Minimalista, Oscuro y Clásico.
- **Perfiles por especialización** que cambian solos.
- **Importar / Exportar** tu estilo como texto para compartirlo.
- **Números de cooldown** en el Cooldown Manager y en las barras de acción, con color y tamaño a elegir.
- Botón en el minimapa con el oso Ruscuu.
- Inglés y español.

### Comandos

| Comando | Qué hace |
|---|---|
| `/ruscuu` o `/rcdm` | Abre las opciones |
| `/ruscuu skin` | Reaplica el estilo |
| `/ruscuu debug` | Muestra qué visores de Blizzard se encontraron y el perfil activo |
| `/ruscuu minimap` | Muestra u oculta el botón del minimapa |
| `/ruscuu reset` | Restaura toda la configuración |

## Publishing / Publicación

Pushing a tag like `v0.3.0` runs the GitHub Action that packages the addon and uploads it to CurseForge, Wago and GitHub Releases. Required repository secrets: `CF_API_KEY` and `WAGO_API_TOKEN`, plus `## X-Curse-Project-ID` and `## X-Wago-ID` in `RuscuuCDM.toc`.

-- Ruscuu Cooldown Manager Forever: traducciones.
-- Las claves están en inglés (idioma por defecto); si falta una traducción se muestra la clave.
-- El idioma se decide en cada consulta, así se puede elegir en las opciones (Automático/English/Español).
local _, ns = ...

local ES = {}
local spanishClient = (GetLocale() == "esES" or GetLocale() == "esMX")
local useSpanish = spanishClient

function ns.SetLanguage(lang)
    if lang == "en" then
        useSpanish = false
    elseif lang == "es" then
        useSpanish = true
    else
        useSpanish = spanishClient
    end
end

ns.L = setmetatable({}, {
    __index = function(_, key)
        if useSpanish then return ES[key] or key end
        return key
    end,
})

------------------------------------------------------------------------
-- Español (esES / esMX)
------------------------------------------------------------------------

-- Visores, barras y catálogos
ES["Essential cooldowns"] = "Cooldowns esenciales"
ES["Utility cooldowns"] = "Cooldowns de utilidad"
ES["Buffs (icons)"] = "Buffs (iconos)"
ES["Buffs (bars)"] = "Buffs (barras)"
ES["Buff"] = "Buff"
ES["Main action bar"] = "Barra de acción principal"
ES["Action bar 2"] = "Barra de acción 2"
ES["Action bar 3"] = "Barra de acción 3"
ES["Action bar 4"] = "Barra de acción 4"
ES["Action bar 5"] = "Barra de acción 5"
ES["Action bar 6"] = "Barra de acción 6"
ES["Action bar 7"] = "Barra de acción 7"
ES["Action bar 8"] = "Barra de acción 8"
ES["Pet bar"] = "Barra de mascota"
ES["Stance bar"] = "Barra de posturas"
ES["Flat"] = "Plana"
ES["Classic"] = "Clásica"
ES["Smooth"] = "Suave"
ES["Blizzard (no change)"] = "Blizzard (sin cambios)"
ES["None"] = "Ninguno"
ES["Outline"] = "Contorno"
ES["Thick outline"] = "Contorno grueso"
ES["Pixel (monochrome)"] = "Píxel (monocromo)"
ES["Specialization %d"] = "Especialización %d"

-- Temas
ES["Ruscuu Neon"] = "Ruscuu Neón"
ES["Minimal"] = "Minimalista"
ES["Dark"] = "Oscuro"
ES["Class color"] = "Color de clase"
ES["Blizzard style"] = "Estilo Blizzard"

-- Mensajes en el chat
ES["Could not enable the Cooldown Manager automatically: enable it in Options > Advanced Options."] = "No se pudo activar el Cooldown Manager automáticamente: actívalo en Opciones > Opciones avanzadas."
ES["Blizzard's Cooldown Manager has been enabled."] = "Se ha activado el Cooldown Manager de Blizzard."
ES["Not available in combat."] = "No disponible en combate."
ES["Blizzard's Cooldown Manager is not loaded."] = "El Cooldown Manager de Blizzard no está cargado."
ES["Blizzard's Cooldown Manager is not available."] = "El Cooldown Manager de Blizzard no está disponible."
ES["Style reapplied."] = "Estilo reaplicado."
ES["Minimap button hidden."] = "Botón del minimapa oculto."
ES["Minimap button shown."] = "Botón del minimapa visible."
ES["Reset ALL Ruscuu CDM settings and profiles? The interface will reload."] = "¿Borrar TODOS los ajustes y perfiles de Ruscuu CDM? La interfaz se recargará."
ES["A profile with that name already exists."] = "Ya existe un perfil con ese nombre."
ES["The Default profile cannot be renamed."] = "El perfil Default no se puede renombrar."
ES["The Default profile cannot be deleted."] = "El perfil Default no se puede borrar."
ES["Theme applied: %s"] = "Tema aplicado: %s"
ES["Invalid import string."] = "Texto de importación no válido."
ES["Profile imported (%d settings)."] = "Perfil importado (%d ajustes)."
ES["Golden border preview for %d seconds."] = "Vista previa del borde dorado durante %d segundos."
ES["The language will change when you reload the interface."] = "El idioma cambiará al recargar la interfaz."

-- Comandos y diagnóstico
ES["Commands"] = "Comandos"
ES["open options"] = "abre las opciones"
ES["choose which cooldowns are shown"] = "elige qué cooldowns se muestran"
ES["preview the golden border for 5 seconds"] = "muestra el borde dorado durante 5 segundos"
ES["reapply the style"] = "reaplica el estilo"
ES["show or hide the minimap button"] = "muestra u oculta el botón del minimapa"
ES["diagnostic information"] = "información de diagnóstico"
ES["reset all settings"] = "borra toda la configuración"
ES["yes"] = "sí"
ES["no"] = "no"
ES["disabled"] = "desactivado"
ES["does not exist"] = "no existe"
ES["%d icons"] = "%d iconos"
ES["Viewers found: %d/%d"] = "Visores encontrados: %d/%d"
ES["Action bar cooldowns hooked: %d"] = "Contadores de barras de acción enganchados: %d"
ES["Cooldown Manager enabled: %s"] = "Cooldown Manager activado: %s"
ES["Golden border: curve API %s, buttons %d, cooldowns read %d"] = "Borde dorado: API de curvas %s, botones %d, cooldowns leídos %d"
ES["Active profile: %s"] = "Perfil activo: %s"

-- Botón del minimapa
ES["Left-click: open options"] = "Clic izquierdo: abrir opciones"
ES["Shift + left-click: choose which cooldowns are shown"] = "Mayús + clic izquierdo: elegir qué cooldowns se muestran"
ES["Right-click: preview the golden border"] = "Clic derecho: ver el borde dorado"
ES["Drag: move button"] = "Arrastrar: mover el botón"

-- Panel: elementos comunes
ES["Profile: %s"] = "Perfil: %s"
ES["Defaults"] = "Valores por defecto"
ES["Restores the default values of this page in the active profile."] = "Restaura los valores por defecto de esta página en el perfil activo."
ES["Restore the default values of \"%s\" in the active profile?"] = "¿Restaurar los valores por defecto de \"%s\" en el perfil activo?"
ES["%.1f per second"] = "%.1f por segundo"
ES["Blizzard"] = "Blizzard"
ES["Blizzard default"] = "Como Blizzard"
ES["Show"] = "Mostrar"
ES["Hide"] = "Ocultar"
ES["No blinking"] = "Sin parpadeo"
ES["Smooth pulse"] = "Pulso suave"
ES["Flash"] = "Destello"

-- Panel: títulos de las páginas
ES["General"] = "General"
ES["Status, Blizzard's Cooldown Manager and addon settings."] = "Estado, Cooldown Manager de Blizzard y ajustes del addon."
ES["Cooldown Manager"] = "Cooldown Manager"
ES["Icons, borders, swipe and buff bars."] = "Iconos, bordes, barrido y barras de buffs."
ES["Texts and numbers"] = "Textos y números"
ES["Font, countdown numbers, charges and bar texts."] = "Fuente, números de cuenta atrás, cargas y textos de las barras."
ES["Action bars"] = "Barras de acción"
ES["Cooldown numbers on your action buttons."] = "Números de cooldown en tus botones de acción."
ES["Golden border"] = "Borde dorado"
ES["A pulsing border during the last seconds of a cooldown."] = "Un borde que parpadea durante los últimos segundos de un cooldown."
ES["Golden border: spells"] = "Borde dorado: hechizos"
ES["Choose which spells get the golden border."] = "Elige a qué hechizos se aplica el borde dorado."
ES["Profiles & Themes"] = "Perfiles y temas"
ES["Themes, profiles per specialization and import/export."] = "Temas, perfiles por especialización e importar/exportar."

-- Página General
ES["Blizzard's Cooldown Manager"] = "Cooldown Manager de Blizzard"
ES["Choose which cooldowns appear, and in which bar, from Blizzard's own panel: drag a spell to \"Not Displayed\" to hide it. Your choice is saved for each specialization."] = "Elige qué cooldowns aparecen, y en qué barra, desde el panel de Blizzard: arrastra un hechizo a \"No mostradas\" para ocultarlo. Tu elección se guarda para cada especialización."
ES["Choose visible cooldowns"] = "Elegir cooldowns visibles"
ES["Opens Blizzard's Advanced Cooldown Settings. Also: /ruscuu cooldowns, or Shift + click on the minimap button."] = "Abre los Ajustes avanzados de habilidades de Blizzard. También: /ruscuu cooldowns, o Mayús + clic en el botón del minimapa."
ES["Enable the Cooldown Manager on install"] = "Activar el Cooldown Manager al instalar"
ES["Turns on Blizzard's Cooldown Manager the first time the addon loads. If you turn it off later in Blizzard's options, the addon respects your choice."] = "Activa el Cooldown Manager de Blizzard la primera vez que se carga el addon. Si después lo apagas en las opciones de Blizzard, el addon respeta tu elección."
ES["Status"] = "Estado"
ES["Addon"] = "Addon"
ES["Show minimap button"] = "Mostrar botón en el minimapa"
ES["Lock minimap button"] = "Bloquear el botón del minimapa"
ES["Prevents moving the minimap button by dragging it."] = "Impide mover el botón del minimapa al arrastrarlo."
ES["Chat messages"] = "Mensajes en el chat"
ES["Informative messages such as profile switches or applied themes. Warnings are always shown."] = "Mensajes informativos como cambios de perfil o temas aplicados. Los avisos se muestran siempre."
ES["Language"] = "Idioma"
ES["Automatic (game language)"] = "Automático (idioma del juego)"
ES["The addon follows the game language by default. Changing it requires reloading the interface."] = "El addon usa el idioma del juego por defecto. Para cambiarlo hay que recargar la interfaz."
ES["Reload interface"] = "Recargar interfaz"
ES["Reset everything"] = "Restablecer todo"
ES["Deletes all profiles and settings of the addon and reloads the interface."] = "Borra todos los perfiles y ajustes del addon y recarga la interfaz."

-- Página Cooldown Manager
ES["Apply style to"] = "Aplicar estilo a"
ES["When unchecked, this viewer goes back to Blizzard's look immediately."] = "Al desmarcarlo, este visor vuelve al aspecto de Blizzard al momento."
ES["Icons"] = "Iconos"
ES["Square icons"] = "Iconos cuadrados"
ES["Removes Blizzard's round mask and frame so icons are square."] = "Quita la máscara y el marco redondos de Blizzard para que los iconos sean cuadrados."
ES["Class color border"] = "Borde del color de tu clase"
ES["Uses your class color for the borders instead of the chosen color."] = "Usa el color de tu clase para los bordes en vez del color elegido."
ES["Icon crop"] = "Recorte del icono"
ES["Trims the edges of the icon artwork. 0% shows the full icon."] = "Recorta los bordes del dibujo del icono. 0% muestra el icono completo."
ES["Border size"] = "Grosor del borde"
ES["Thickness of the border around icons and bars. 0 hides it."] = "Grosor del borde de iconos y barras. 0 lo oculta."
ES["Border color"] = "Color del borde"
ES["Cooldown swipe"] = "Barrido del cooldown"
ES["Show swipe"] = "Mostrar barrido"
ES["The shadow that sweeps over the icon while the cooldown runs."] = "La sombra que recorre el icono mientras dura el cooldown."
ES["Swipe color"] = "Color del barrido"
ES["Swipe edge"] = "Línea del barrido"
ES["The bright line at the edge of the swipe."] = "La línea brillante en el borde del barrido."
ES["Finish flash"] = "Destello al terminar"
ES["The flash Blizzard plays when a cooldown finishes."] = "El destello que muestra Blizzard cuando termina un cooldown."
ES["Buff bars"] = "Barras de buffs"
ES["Bar texture"] = "Textura de la barra"
ES["Bar color"] = "Color de la barra"
ES["Bar background"] = "Fondo de la barra"

-- Página Textos y números
ES["Font"] = "Fuente"
ES["Typeface"] = "Tipo de letra"
ES["Used by every text the addon styles. Fonts from SharedMedia appear here too."] = "La usan todos los textos que estiliza el addon. Aquí también aparecen las fuentes de SharedMedia."
ES["Cooldown Manager countdown"] = "Cuenta atrás del Cooldown Manager"
ES["Show countdown numbers"] = "Mostrar números de cuenta atrás"
ES["Number color"] = "Color de los números"
ES["Number size"] = "Tamaño de los números"
ES["Charges and stacks"] = "Cargas y acumulaciones"
ES["Size"] = "Tamaño"
ES["0 keeps Blizzard's size."] = "0 mantiene el tamaño de Blizzard."
ES["Also used by the name and duration of the buff bars."] = "También se usa en el nombre y la duración de las barras de buffs."
ES["Custom color"] = "Color propio"
ES["Charges color"] = "Color de las cargas"
ES["Buff bar texts"] = "Textos de las barras de buffs"
ES["Name and duration size"] = "Tamaño del nombre y la duración"

-- Página Barras de acción
ES["Cooldown numbers on action buttons"] = "Números de cooldown en los botones de acción"
ES["Blizzard's countdown numbers"] = "Números de cuenta atrás de Blizzard"
ES["Always show"] = "Mostrar siempre"
ES["Never show"] = "No mostrar nunca"
ES["Leave the game setting"] = "No tocar el ajuste del juego"
ES["Controls the game's own \"Show numbers for cooldowns\" setting (shared by all profiles)."] = "Controla el ajuste del juego \"Mostrar números en los tiempos de reutilización\" (común a todos los perfiles)."
ES["Ruscuu style for the numbers"] = "Estilo Ruscuu en los números"
ES["When unchecked, Blizzard's font returns immediately."] = "Al desmarcarlo, vuelve al momento la fuente de Blizzard."
ES["Bars included"] = "Barras incluidas"
ES["The number style and the golden border are applied only to the checked bars."] = "El estilo de los números y el borde dorado solo se aplican a las barras marcadas."

-- Página Borde dorado
ES["Test for 5 seconds"] = "Probar 5 segundos"
ES["Shows the golden border on every button for 5 seconds so you can see how it looks."] = "Muestra el borde dorado en todos los botones durante 5 segundos para que veas cómo queda."
ES["The game decides when the border appears: the addon never reads the remaining time, so it follows Forever's rules."] = "El juego decide cuándo aparece el borde: el addon nunca lee el tiempo restante, así que cumple las reglas de Forever."
ES["Golden border when a cooldown is ending"] = "Borde dorado cuando un cooldown está terminando"
ES["Ending border color"] = "Color del borde al terminar"
ES["On Cooldown Manager icons"] = "En los iconos del Cooldown Manager"
ES["On action buttons"] = "En los botones de acción"
ES["Last seconds"] = "Últimos segundos"
ES["The border appears when this many seconds (or fewer) remain."] = "El borde aparece cuando quedan estos segundos o menos."
ES["Thickness"] = "Grosor"
ES["Glow"] = "Resplandor"
ES["Soft glow around the button"] = "Resplandor suave alrededor del botón"
ES["Glow size"] = "Tamaño del resplandor"
ES["100% is the size of Blizzard's own button glow."] = "100% es el tamaño del brillo de los botones de Blizzard."
ES["Blinking"] = "Parpadeo"
ES["Blink style"] = "Tipo de parpadeo"
ES["Speed"] = "Velocidad"
ES["Minimum opacity"] = "Opacidad mínima"
ES["How much the border fades between blinks."] = "Cuánto se desvanece el borde entre parpadeos."

-- Página Borde dorado: hechizos
ES["Uncheck the spells that should never get the golden border. The list shows the spells on your action bars and in the Cooldown Manager; the choice is saved in the active profile."] = "Desmarca los hechizos que nunca deben llevar el borde dorado. La lista muestra los hechizos de tus barras de acción y del Cooldown Manager; la elección se guarda en el perfil activo."
ES["Refresh list"] = "Actualizar lista"
ES["Include all"] = "Incluir todos"
ES["No spells found. Put spells on your action bars or enable the Cooldown Manager, then press \"Refresh list\"."] = "No se encontraron hechizos. Pon hechizos en tus barras de acción o activa el Cooldown Manager y pulsa \"Actualizar lista\"."

-- Página Perfiles y temas
ES["Themes"] = "Temas"
ES["Themes change the colors and borders of the active profile. The highlighted theme is the one you are using."] = "Los temas cambian los colores y bordes del perfil activo. El tema resaltado es el que estás usando."
ES["Profiles"] = "Perfiles"
ES["Active profile"] = "Perfil activo"
ES["The profile you choose here is also assigned to your current specialization."] = "El perfil que elijas aquí también se asigna a tu especialización actual."
ES["New"] = "Nuevo"
ES["Duplicate"] = "Duplicar"
ES["Creates a new profile with a copy of the active one."] = "Crea un perfil nuevo con una copia del activo."
ES["Rename"] = "Renombrar"
ES["Delete"] = "Borrar"
ES["Reset"] = "Restablecer"
ES["Profile per specialization"] = "Perfil por especialización"
ES["The profile changes automatically when you switch specialization."] = "El perfil cambia solo al cambiar de especialización."
ES["This character has no specializations yet: the active profile is used."] = "Este personaje aún no tiene especializaciones: se usa el perfil activo."
ES["Import / Export"] = "Importar / Exportar"
ES["Share your style by copying the text, or paste one to import it into the active profile."] = "Comparte tu estilo copiando el texto, o pega uno para importarlo en el perfil activo."
ES["Export"] = "Exportar"
ES["Import"] = "Importar"
ES["Export profile"] = "Exportar perfil"
ES["Import profile"] = "Importar perfil"
ES["Press Ctrl+C to copy."] = "Pulsa Ctrl+C para copiar."
ES["Paste the text with Ctrl+V and press Import."] = "Pega el texto con Ctrl+V y pulsa Importar."
ES["Close"] = "Cerrar"
ES["New profile name:"] = "Nombre del nuevo perfil:"
ES["New name for profile \"%s\":"] = "Nuevo nombre para el perfil \"%s\":"
ES["Delete profile \"%s\"?"] = "¿Borrar el perfil \"%s\"?"
ES["Reset profile \"%s\" to default values?"] = "¿Restablecer el perfil \"%s\" a los valores por defecto?"

-- Ruscuu Cooldown Manager Forever: traducciones.
-- Las claves están en inglés (idioma por defecto); si falta una traducción se muestra la clave.
local _, ns = ...

local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

local locale = GetLocale()
if locale == "esES" or locale == "esMX" then
    -- Visores
    L["Essential cooldowns"] = "Cooldowns esenciales"
    L["Utility cooldowns"] = "Cooldowns de utilidad"
    L["Buffs (icons)"] = "Buffs (iconos)"
    L["Buffs (bars)"] = "Buffs (barras)"

    -- Mensajes en el chat
    L["Style reapplied."] = "Estilo reaplicado."
    L["Minimap button hidden."] = "Botón del minimapa oculto."
    L["Minimap button shown."] = "Botón del minimapa visible."
    L["%s: found, %d icons, hooked=%s"] = "%s: encontrado, %d iconos, enganchado=%s"
    L["does not exist"] = "no existe"
    L["Type /reload to restore Blizzard's style on that viewer."] = "Escribe /reload para volver al estilo de Blizzard en ese visor."
    L["Type /reload to restore Blizzard's numbers."] = "Escribe /reload para volver a los números de Blizzard."
    L["Active profile: %s"] = "Perfil activo: %s"
    L["Action bar cooldowns hooked: %d"] = "Contadores de barras de acción enganchados: %d"
    L["Enable Blizzard's Cooldown Manager automatically"] = "Activar automáticamente el Cooldown Manager de Blizzard"
    L["Blizzard's Cooldown Manager has been enabled."] = "Se ha activado el Cooldown Manager de Blizzard."
    L["Could not enable the Cooldown Manager automatically: enable it in Options > Advanced Options."] = "No se pudo activar el Cooldown Manager automáticamente: actívalo en Opciones > Opciones avanzadas."
    L["Cooldown Manager setting (%s): %s"] = "Ajuste del Cooldown Manager (%s): %s"
    L["Golden border when a cooldown is ending"] = "Borde dorado cuando un cooldown está terminando"
    L["Golden border time"] = "Segundos del borde dorado"
    L["Ending border color"] = "Color del borde al terminar"
    L["The golden border is not available in this game version."] = "El borde dorado no está disponible en esta versión del juego."
    L["Golden border: curve API %s, buttons %d, cooldowns read %d"] = "Borde dorado: API de curvas %s, botones %d, cooldowns leídos %d"
    L["yes"] = "sí"
    L["no"] = "no"
    L["disabled"] = "desactivado"
    L["Theme applied: %s"] = "Tema aplicado: %s"
    L["Profile imported."] = "Perfil importado."
    L["Invalid import string."] = "Texto de importación no válido."
    L["A profile with that name already exists."] = "Ya existe un perfil con ese nombre."
    L["The Default profile cannot be deleted."] = "El perfil Default no se puede borrar."

    -- Tooltip del minimapa
    L["Left-click: open options"] = "Clic izquierdo: abrir opciones"
    L["Right-click: reapply style"] = "Clic derecho: reaplicar estilo"
    L["Drag: move button"] = "Arrastrar: mover el botón"

    -- Panel de opciones
    L["Style for Blizzard's Cooldown Manager."] = "Estilo para el Cooldown Manager de Blizzard."
    L["Commands"] = "Comandos"
    L["Apply style to"] = "Aplicar estilo a"
    L["Border size"] = "Grosor del borde"
    L["Icon crop"] = "Recorte del icono"
    L["Cooldown text size"] = "Tamaño del texto de cooldown"
    L["Border color"] = "Color del borde"
    L["Bar color"] = "Color de las barras"
    L["Show minimap button"] = "Mostrar botón en el minimapa"
    L["Cooldown numbers"] = "Números de cooldown"
    L["Show numbers on the Cooldown Manager"] = "Mostrar números en el Cooldown Manager"
    L["Number color"] = "Color de los números"
    L["Show numbers on action bars"] = "Mostrar números en las barras de acción"
    L["Action bar number size"] = "Tamaño de los números en barras de acción"
    L["Ruscuu style for action bar numbers"] = "Estilo Ruscuu en los números de las barras de acción"

    -- Perfiles y temas
    L["Profiles & Themes"] = "Perfiles y temas"
    L["Themes"] = "Temas"
    L["Themes change the colors and borders of the active profile."] = "Los temas cambian los colores y bordes del perfil activo."
    L["Ruscuu Neon"] = "Ruscuu Neón"
    L["Minimal"] = "Minimalista"
    L["Dark"] = "Oscuro"
    L["Classic"] = "Clásico"
    L["Profiles"] = "Perfiles"
    L["Active profile"] = "Perfil activo"
    L["New"] = "Nuevo"
    L["Copy"] = "Copiar"
    L["Delete"] = "Borrar"
    L["Reset"] = "Restablecer"
    L["Profile per specialization"] = "Perfil por especialización"
    L["The profile changes automatically when you switch specialization."] = "El perfil cambia solo al cambiar de especialización."
    L["Import / Export"] = "Importar / Exportar"
    L["Share your style by copying the text, or paste one to import it into the active profile."] = "Comparte tu estilo copiando el texto, o pega uno para importarlo en el perfil activo."
    L["Export"] = "Exportar"
    L["Import"] = "Importar"
    L["Export profile"] = "Exportar perfil"
    L["Import profile"] = "Importar perfil"
    L["Press Ctrl+C to copy."] = "Pulsa Ctrl+C para copiar."
    L["Paste the text with Ctrl+V and press Import."] = "Pega el texto con Ctrl+V y pulsa Importar."
    L["Close"] = "Cerrar"
    L["New profile name:"] = "Nombre del nuevo perfil:"
    L["Delete profile \"%s\"?"] = "¿Borrar el perfil \"%s\"?"
    L["Reset profile \"%s\" to default values?"] = "¿Restablecer el perfil \"%s\" a los valores por defecto?"
end

-- shared/main_locale.lua

-- Select the language table based on Config.Language
local translations = Lang[Config.Language]

-- If the selected language doesn't exist, fall back to a default (e.g., pt-br) and print a warning.
if not translations then
    print(string.format(Lang['pt-br']['diag_lang_fallback'] or '[CHEST DIAG] Language "%s" not found. Defaulting to "%s".', Config.Language, 'pt-br'))
    translations = Lang['pt-br']
end

-- Create the global translation function `_L`
-- This function will be accessible from any client or server script that loads after this one.
_L = function(key, ...)
    -- Find the translation string, if not found, use the key itself as the text
    local str = translations[key] or key
    -- If there are arguments (...), format the string with them
    if select("#", ...) > 0 then
        return string.format(str, ...)
    else
        return str
    end
end

-- Overwrite Config.Lang with the selected translations.
-- This ensures compatibility with any part of the script that might still use Config.Lang directly.
Config.Lang = translations

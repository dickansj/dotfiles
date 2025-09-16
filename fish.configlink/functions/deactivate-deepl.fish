# ~/.dotfiles/utility/deepl-env/bin/deactivate-deepl.fish
# Deactivate the DeepL virtual environment

# Restore PATH and PYTHONHOME
if set -q OLD_VIRTUAL_PATH
    set -gx PATH $OLD_VIRTUAL_PATH
    set -e OLD_VIRTUAL_PATH
end

if set -q OLD_VIRTUAL_PYTHONHOME
    set -gx PYTHONHOME $OLD_VIRTUAL_PYTHONHOME
    set -e OLD_VIRTUAL_PYTHONHOME
end

# Unset VIRTUAL_ENV
set -e VIRTUAL_ENV

# Restore Fish prompt
if set -q OLD_FISH_PROMPT
    function fish_prompt
        eval $OLD_FISH_PROMPT
    end
    set -e OLD_FISH_PROMPT
end

# Unset DEEPL_API_KEY (optional, keeps venv key isolated)
set -e DEEPL_API_KEY

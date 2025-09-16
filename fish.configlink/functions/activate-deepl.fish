# ~/.dotfiles/utility/deepl-env/bin/activate-deepl.fish
# Activate the DeepL virtual environment

# Save old environment variables
set -gx OLD_VIRTUAL_PATH $PATH
set -gx OLD_VIRTUAL_PYTHONHOME $PYTHONHOME

# Prepend venv bin to PATH
set -gx PATH ~/.dotfiles/utility/deepl-env/bin $PATH

# Set VIRTUAL_ENV
set -gx VIRTUAL_ENV ~/.dotfiles/utility/deepl-env

# Optional prompt modification
if not set -q OLD_FISH_PROMPT
    set -gx OLD_FISH_PROMPT $fish_prompt
end
function fish_prompt
    set_color green
    echo -n "(deepl-env) "
    set_color normal
    $OLD_FISH_PROMPT
end

# Export DeepL API key if exists in this file
# (this line will be appended by run-translate automatically)
set -gx DEEPL_API_KEY "your-api-key-here"

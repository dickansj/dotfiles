function run-translate
    # Usage check
    if test (count $argv) -lt 2
        echo "Usage: run-translate input.pdf output.pdf [--lang EN] [--txt]"
        return 1
    end

    # Paths
    set utility_dir ~/.dotfiles/utility
    set venv_dir $utility_dir/deepl-env
    set activate_file $venv_dir/bin/activate-deepl.fish
    set deactivate_file $venv_dir/bin/deactivate-deepl.fish
    set script_path $utility_dir/translate_pdf.py

    # Ensure translate_pdf.py exists
    if not test -f $script_path
        echo "❌ translate_pdf.py not found at $script_path"
        return 1
    end

    # Create virtual environment if missing
    if not test -d $venv_dir
        echo "Creating virtual environment at $venv_dir..."
        python3 -m venv $venv_dir

        # Rename default activate.fish → activate-deepl.fish
        if test -f $venv_dir/bin/activate.fish
            mv $venv_dir/bin/activate.fish $activate_file
        else
            echo "❌ Expected activate.fish not found. Venv creation may have failed."
            return 1
        end

        # Activate venv and install dependencies
        source $activate_file
        pip install --upgrade pip
        pip install PyPDF2 requests reportlab tqdm
    else
        # Existing venv: ensure activate-deepl.fish exists
        if not test -f $activate_file
            echo "❌ activate-deepl.fish missing in existing venv. Please delete the venv and retry."
            return 1
        end
        source $activate_file
    end

    # Prompt for API key if missing or empty
    if not set -q DEEPL_API_KEY -o "$DEEPL_API_KEY" = ""
        read -s -P "Enter your DeepL API Key: " api_key
        echo ""  # newline after silent input
        # Save permanently in venv
        echo "# Set DeepL API key for this venv only" >> $activate_file
        echo "set -gx DEEPL_API_KEY \"$api_key\"" >> $activate_file
        # Set for current session
        set -gx DEEPL_API_KEY $api_key
        echo "✅ API key saved and active for this session."
    end

    # Detect Free vs Pro plan using venv Python
    set plan_check_code "
import os, requests
key = os.environ.get('DEEPL_API_KEY')
plan = 'FREE'
url = 'https://api.deepl.com/v2/usage'
try:
    r = requests.get(url, headers={'Authorization': f'DeepL-Auth-Key {key}'})
    if r.status_code == 200: plan='PRO'
except:
    pass
print(plan)
"
    set PLAN ($venv_dir/bin/python -c "$plan_check_code")
    echo "🌐 Detected DeepL plan: $PLAN"

    # Run translation using venv Python
    $venv_dir/bin/python $script_path $argv

    # Properly deactivate venv
    if test -f $deactivate_file
        source $deactivate_file
    end

    echo "✅ Translation complete."
end

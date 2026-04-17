# CC BY-SA 4.0 Zughy
from pathlib import Path
import re
import subprocess
import tempfile
import yaml

PATH = Path(__file__).resolve().parent
LOCALE_PATH = PATH / "locale"
TEMPLATE = LOCALE_PATH / "template.pot"

LOCALE_PATH.mkdir(exist_ok=True)

def load_yaml(path: str) -> list[str]:
    with open(path, encoding='utf-8') as f:
        file = yaml.safe_load(f)
        descs = [value.get('description') for value in file.values() if value.get('description')]
        return descs

def translate_strings(strings: list[str]):
    # uso un file temporaneo per tradurre le stringhe da Python
    with tempfile.NamedTemporaryFile("w+", delete=False, suffix=".py") as temp_f:
        temp_f.writelines(f'_("{s}")\n' for s in strings)
        temp_path = Path(temp_f.name)

    subprocess.run(["xgettext", "--no-location", f"--output={str(TEMPLATE)}", str(temp_path)], check=True)
    temp_path.unlink()

def update_pot():
    strings = []
    # titolo menù
    settings_path = Path("SETTINGS.lua")
    pattern = re.compile(r'^magic_compass\.menu_title\s*=\s*"(.*)"')

    with settings_path.open(encoding='utf-8') as f:
        for line in f:
            match = pattern.match(line.strip())
            if match:
                strings.append(match.group(1))
                break
    # contenuto
    for file in PATH.glob("*"):
        if file.suffix in (".yml", ".yaml"):
            strings.extend(load_yaml(file))
    translate_strings(strings)

def update_po():
    for file in LOCALE_PATH.glob("*.po"):
        subprocess.run(["msgmerge", "--update", "--backup=none", "--verbose", str(file), f"{str(TEMPLATE)}"], check=True)


try:
    update_pot()
    update_po()
except Exception as e:
    print(f"Error: {e}")
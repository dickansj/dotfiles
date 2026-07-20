// LaunchAgent-only entry point for keeping osx-dictionaries/LocalDictionary
//   and Word's custom dictionary in sync (see osx-launchagents/
//   com.jdickan.syncdict.plist and osx-dictionaries/README.md).
//
// This exists as a compiled binary, not a shell script, because macOS's
//   Full Disk Access protection on Word's Group Container checks the
//   identity of whatever process is actually performing the file I/O -
//   for an interpreted script that's always the interpreter (bash),
//   regardless of which script triggered it, so a shell-script wrapper
//   can't get its own grantable identity no matter how it's invoked. A
//   real compiled binary can. That's the only reason this duplicates
//   bin.homelink/syncdict's logic instead of calling it - for everyday
//   interactive use, run `syncdict` instead; this binary is launchd-only.
//
// Deliberately dependency-free (std library only) so it builds with a
//   plain `rustc`, no Cargo project/crates.io fetch required - see the
//   build step in install_symlinks.sh's install_dictionaries().

use std::collections::HashSet;
use std::env;
use std::fs;
use std::path::PathBuf;

fn read_lines_utf8(path: &PathBuf) -> Vec<String> {
    fs::read_to_string(path)
        .unwrap_or_default()
        .lines()
        .map(|s| s.to_string())
        .filter(|s| !s.is_empty())
        .collect()
}

fn read_lines_utf16le(path: &PathBuf) -> Vec<String> {
    let bytes = match fs::read(path) {
        Ok(b) => b,
        Err(_) => return Vec::new(),
    };
    if bytes.len() < 2 {
        return Vec::new();
    }
    // Word's file starts with a UTF-16LE BOM (FF FE) - skip it rather
    //   than decoding it as a character.
    let data = if bytes[0] == 0xFF && bytes[1] == 0xFE {
        &bytes[2..]
    } else {
        &bytes[..]
    };
    let units: Vec<u16> = data
        .chunks_exact(2)
        .map(|c| u16::from_le_bytes([c[0], c[1]]))
        .collect();
    let decoded: String = char::decode_utf16(units)
        .map(|r| r.unwrap_or('\u{FFFD}'))
        .collect();
    decoded
        .replace('\r', "")
        .lines()
        .map(|s| s.to_string())
        .filter(|s| !s.is_empty())
        .collect()
}

// UTF-8/LF, one word per line, trailing newline. Returns true if the
//   file's content actually changed.
fn write_utf8_if_changed(path: &PathBuf, words: &[String]) -> bool {
    let mut content = words.join("\n");
    content.push('\n');
    if let Ok(existing) = fs::read_to_string(path) {
        if existing == content {
            return false;
        }
    }
    fs::write(path, content).expect("failed to write LocalDictionary");
    true
}

// UTF-16LE with a leading BOM and CRLF line endings (including after the
//   last word) - matches Word's own native format exactly. Written via a
//   temp file + atomic rename, same as the bash version. Returns true if
//   the file's content actually changed.
fn write_utf16le_if_changed(path: &PathBuf, words: &[String]) -> bool {
    let mut units: Vec<u16> = vec![0xFEFF];
    for word in words {
        units.extend(word.encode_utf16());
        units.push(0x000D);
        units.push(0x000A);
    }
    let mut bytes = Vec::with_capacity(units.len() * 2);
    for u in &units {
        bytes.extend_from_slice(&u.to_le_bytes());
    }

    if let Ok(existing) = fs::read(path) {
        if existing == bytes {
            return false;
        }
    }

    let tmp_path = path.with_file_name(format!(
        ".{}.syncdict-tmp",
        path.file_name().unwrap().to_string_lossy()
    ));
    fs::write(&tmp_path, &bytes).expect("failed to write temp file for Word's dictionary");
    fs::rename(&tmp_path, path).expect("failed to move temp file into place");
    true
}

fn main() {
    let home = env::var("HOME").expect("HOME not set");
    let canonical = PathBuf::from(&home).join(".dotfiles/osx-dictionaries/LocalDictionary");
    let word_dict = PathBuf::from(&home)
        .join("Library/Group Containers/UBF8T346G9.Office/Custom Dictionary");

    if let Some(parent) = canonical.parent() {
        fs::create_dir_all(parent).ok();
    }
    if !canonical.exists() {
        fs::write(&canonical, "").expect("failed to create LocalDictionary");
    }
    if let Some(parent) = word_dict.parent() {
        fs::create_dir_all(parent).ok();
    }

    // Union of both lists, exact-match dedup only (case variants like
    //   "Pneumatological"/"pneumatological" are kept as distinct entries
    //   on purpose), sorted case-insensitively for readability.
    let mut seen: HashSet<String> = HashSet::new();
    let mut merged: Vec<String> = Vec::new();
    for word in read_lines_utf8(&canonical)
        .into_iter()
        .chain(read_lines_utf16le(&word_dict))
    {
        if seen.insert(word.clone()) {
            merged.push(word);
        }
    }
    merged.sort_by_key(|s| s.to_lowercase());

    let canonical_changed = write_utf8_if_changed(&canonical, &merged);
    let word_changed = write_utf16le_if_changed(&word_dict, &merged);

    if canonical_changed || word_changed {
        println!(
            "Synced {} words to LocalDictionary and Word's custom dictionary.",
            merged.len()
        );
    } else {
        println!("Already in sync ({} words).", merged.len());
    }
}

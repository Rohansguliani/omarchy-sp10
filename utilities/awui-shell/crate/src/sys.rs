//! Running commands, talking to Hyprland, and finding app icons.

use anti_webui::shell::hyprland;
use anti_webui::shell::{apps, icon_path};
use std::path::PathBuf;
use std::process::{Command, Stdio};

/// Runs `cmd` through the shell without waiting; a thread reaps it.
pub fn spawn(cmd: &str) {
    let cmd = cmd.to_owned();
    let _ = std::thread::Builder::new()
        .name("spawn".into())
        .spawn(move || {
            if let Ok(mut child) = Command::new("sh")
                .arg("-c")
                .arg(&cmd)
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .spawn()
            {
                let _ = child.wait();
            }
        });
}

/// A Hyprland dispatcher in Lua, like `hl.dsp.focus({ window = "address:0x1" })`.
pub fn dispatch(lua: &str) {
    let _ = hyprland::request(&format!("dispatch {lua}"));
}

/// The name of the monitor with the focus.
pub fn focused_monitor() -> String {
    hyprland::monitors()
        .into_iter()
        .find(|m| m.focused)
        .or_else(|| hyprland::monitors().into_iter().next())
        .map(|m| m.name)
        .unwrap_or_default()
}

/// An icon for a window's class: its desktop entry's icon, else an icon named like the class.
/// The icon for a window's class, from its desktop entry. Reads the app list, so inside a memo
/// it updates once the list has loaded.
pub fn icon_for_class(class: &str) -> Option<PathBuf> {
    if class.is_empty() {
        return None;
    }
    let lower = class.to_lowercase();
    let all = apps().all();
    let app = all
        .iter()
        .find(|a| {
            a.id.trim_end_matches(".desktop")
                .eq_ignore_ascii_case(class)
        })
        .or_else(|| {
            all.iter().find(|a| {
                let id = a.id.trim_end_matches(".desktop").to_lowercase();
                id.rsplit('.').next() == Some(lower.as_str())
            })
        });
    if let Some(path) = app.and_then(|a| a.icon_path(64)) {
        return Some(path);
    }
    // Until the list has loaded, don't settle for a guess by class name.
    if !apps().loaded() {
        return None;
    }
    icon_path(class, 64).or_else(|| icon_path(&lower, 64))
}

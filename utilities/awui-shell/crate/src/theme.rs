//! Colors and type from the current Omarchy theme
//! (`~/.local/state/omarchy/current/theme/colors.toml`), reloaded when the theme changes.

use anti_webui::prelude::*;
use std::cell::Cell;
use std::path::PathBuf;
use std::time::{Duration, SystemTime};

/// Omarchy's UI font; its Nerd Font glyphs are the icons.
pub const FONT: &str = "JetBrainsMono Nerd Font";

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Theme {
    pub bg: Color,
    pub fg: Color,
    /// The brightest text: titles, values.
    pub bright: Color,
    /// Secondary text.
    pub soft: Color,
    /// Labels and disabled things.
    pub muted: Color,
    /// A panel over the desktop.
    pub panel: Color,
    /// A row under the pointer, a selected item.
    pub raised: Color,
    pub border: Color,
    pub accent: Color,
}

fn mix(a: Color, b: Color, t: f32) -> Color {
    Color::new(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1.0)
}

fn colors_file() -> Option<PathBuf> {
    std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".local/state/omarchy/current/theme/colors.toml"))
}

fn load() -> Theme {
    let text = colors_file().and_then(|p| std::fs::read_to_string(p).ok()).unwrap_or_default();
    let mut map = std::collections::HashMap::new();
    for line in text.lines() {
        if let Some((key, value)) = line.split_once('=')
            && let Some(hex) = value.trim().trim_matches('"').strip_prefix('#')
            && let Ok(v) = u32::from_str_radix(hex, 16)
        {
            map.insert(key.trim().to_owned(), v);
        }
    }
    let get = |k: &str, d: u32| rgb(*map.get(k).unwrap_or(&d));
    let bg = get("background", 0x000000);
    let fg = get("foreground", 0xdddddd);
    Theme {
        bg,
        fg,
        bright: get("bright_foreground", 0xffffff),
        soft: get("light_foreground", 0xbcbcbc),
        muted: get("muted", 0x6a6a6a),
        panel: mix(bg, fg, 0.04),
        raised: mix(bg, fg, 0.10),
        border: mix(bg, fg, 0.16),
        accent: get("accent", 0xdddddd),
    }
}

thread_local! {
    static THEME: Cell<Option<Signal<Theme>>> = const { Cell::new(None) };
}

/// The theme now; reading it tracks.
pub fn t() -> Theme {
    THEME.with(|t| t.get()).map(|s| s.get()).unwrap_or_else(load)
}

/// Loads the theme and follows the file. Call once, from the root.
pub fn install() {
    let theme = signal(load());
    THEME.with(|t| t.set(Some(theme)));
    let to_ui = ui_channel(move |_: ()| theme.set(load()));
    let _ = std::thread::Builder::new().name("theme".into()).spawn(move || {
        let stamp = || colors_file().and_then(|p| std::fs::metadata(p).ok()).and_then(|m| m.modified().ok());
        let mut last: Option<SystemTime> = stamp();
        loop {
            std::thread::sleep(Duration::from_secs(2));
            let now = stamp();
            if now != last {
                last = now;
                to_ui.send(());
            }
        }
    });
}

/// Text in the UI font.
pub fn label(size: f32, f: impl Fn() -> String + 'static) -> Div {
    div().whitespace_nowrap().font_family(FONT).text_size(size).child(text(f))
}

/// Fixed text in the UI font.
pub fn fixed(size: f32, s: impl Into<String>) -> Div {
    div().whitespace_nowrap().font_family(FONT).text_size(size).child(s.into())
}

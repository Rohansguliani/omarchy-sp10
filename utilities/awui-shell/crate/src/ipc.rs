//! Commands from outside (Hyprland key bindings, scripts), one line over a socket in
//! `$XDG_RUNTIME_DIR`:
//!
//! ```text
//! omarchy-awui msg toggle sound|battery     the bar's menus, on the focused monitor
//! omarchy-awui msg status
//! omarchy-awui msg quit
//! ```

use anti_webui::prelude::*;
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::PathBuf;

fn socket() -> PathBuf {
    let dir = std::env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(std::env::temp_dir);
    let display = std::env::var("WAYLAND_DISPLAY").unwrap_or_else(|_| "wayland-0".into());
    dir.join(format!("omarchy-awui.{display}.sock"))
}

/// Sends a command to the running shell and prints its answer.
pub fn send(args: &[String]) -> Result<(), String> {
    let mut stream = UnixStream::connect(socket()).map_err(|e| format!("not running: {e}"))?;
    writeln!(stream, "{}", args.join(" ")).map_err(|e| e.to_string())?;
    let _ = stream.shutdown(std::net::Shutdown::Write);
    let mut answer = String::new();
    BufReader::new(stream)
        .read_line(&mut answer)
        .map_err(|e| e.to_string())?;
    let answer = answer.trim();
    match answer.strip_prefix("ok") {
        Some(rest) => {
            if !rest.trim().is_empty() {
                println!("{}", rest.trim());
            }
            Ok(())
        }
        None => Err(answer.to_owned()),
    }
}

/// Listens for commands. Call once, from the root.
pub fn serve() {
    let path = socket();
    if UnixStream::connect(&path).is_ok() {
        eprintln!("omarchy-awui: already running at {}", path.display());
        std::process::exit(1);
    }
    let _ = std::fs::remove_file(&path);
    let listener = match UnixListener::bind(&path) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("omarchy-awui: no command socket: {e}");
            return;
        }
    };
    let to_ui = ui_channel(
        move |(line, answer): (String, std::sync::mpsc::Sender<String>)| {
            let _ = answer.send(match run(&line) {
                Ok(s) if s.is_empty() => "ok".into(),
                Ok(s) => format!("ok {s}"),
                Err(e) => e,
            });
        },
    );
    let _ = std::thread::Builder::new()
        .name("ipc".into())
        .spawn(move || {
            for stream in listener.incoming().flatten() {
                let mut line = String::new();
                if BufReader::new(&stream).read_line(&mut line).is_err() {
                    continue;
                }
                let (tx, rx) = std::sync::mpsc::channel();
                to_ui.send((line.trim().to_owned(), tx));
                let answer = rx
                    .recv_timeout(std::time::Duration::from_secs(2))
                    .unwrap_or_else(|_| "no answer".into());
                let _ = writeln!(&stream, "{answer}");
            }
        });
}

fn run(line: &str) -> Result<String, String> {
    let words: Vec<&str> = line.split_whitespace().collect();
    match words.as_slice() {
        ["toggle", name] => {
            let menu = crate::bar::Menu::from_name(name)
                .ok_or_else(|| format!("no menu called {name}"))?;
            crate::bar::toggle_menu(&crate::sys::focused_monitor(), menu);
            Ok(String::new())
        }
        ["settings"] => {
            crate::settings::open(None);
            Ok(String::new())
        }
        ["settings", page] => {
            let p = crate::settings::page_id(page).ok_or_else(|| format!("no settings page called {page}"))?;
            crate::settings::open(Some(p));
            Ok(String::new())
        }
        ["status"] => Ok(format!("menu={:?}", crate::bar::open_menu())),
        ["quit"] => {
            let _ = std::fs::remove_file(socket());
            quit();
            Ok(String::new())
        }
        _ => Err(format!("unknown command: {line}")),
    }
}

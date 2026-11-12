//! omarchy-awui: Omarchy's bar, menus and window tools, built on AntiWebUI.

mod bar;
mod battery;
mod ipc;
mod settings;
mod sound;
mod sys;
mod theme;
mod ui;

use anti_webui::shell::prelude::*;

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.first().map(String::as_str) == Some("msg") {
        if let Err(e) = ipc::send(&args[1..]) {
            eprintln!("omarchy-awui: {e}");
            std::process::exit(1);
        }
        return;
    }
    let result = Shell::new()
        .namespace("omarchy-awui")
        .app_id("omarchy-awui")
        .run(|| {
            ipc::serve();
            theme::install();
            for_each_output(|output| bar::open(output.clone()));
        });
    if let Err(e) = result {
        eprintln!("omarchy-awui: {e}");
        std::process::exit(1);
    }
}

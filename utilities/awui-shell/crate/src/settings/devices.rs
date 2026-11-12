//! Devices: the mice, touchpads and keyboards plugged in. Click one for its pointer and scroll
//! speed, natural scrolling, acceleration, tap to click, or swapping Alt and Super.
//!
//! `~/.local/lib/omarchy-awui/devices` does the work: `list` merges Hyprland, sysfs and udev
//! into one entry per physical device, and `set` checks a change, applies it live and saves it
//! to `~/.config/hypr/utilities/devices.lua`.

use super::kit::*;
use crate::theme::{fixed, label, t};
use crate::ui::volume_slider;
use anti_webui::prelude::*;
use anti_webui::shell::serde_json::{self, Value};
use std::cell::Cell;
use std::time::Duration;

fn helper() -> String {
    format!(
        "{}/.local/lib/omarchy-awui/devices",
        std::env::var("HOME").unwrap_or_default()
    )
}

fn glyph(kind: &str) -> &'static str {
    match kind {
        "mouse" => "󰍽",
        "touchpad" => "󰟸",
        _ => "󰌌",
    }
}

pub fn page() -> Div {
    let devices = signal(Vec::<Value>::new());
    let selected = signal(String::new());
    let load = move || {
        run_output(vec![helper(), "list".into()]).then(move |out| {
            if let Ok(Value::Array(list)) = serde_json::from_str::<Value>(&out) {
                devices.set(list);
            }
        });
    };
    load();
    // Plugging a device in or out shows up on its own.
    fn every(devices: Signal<Vec<Value>>, load: impl Fn() + Copy + 'static) {
        set_timeout(Duration::from_secs(4), move || {
            if devices.is_alive() && crate::settings::current_page() == "devices" {
                load();
                every(devices, load);
            }
        });
    }
    every(devices, load);

    div().size_full().child(dyn_view(move || {
        let id = selected.get();
        let list = untrack(|| devices.get());
        match list.iter().find(|d| d["id"] == id.as_str()) {
            Some(d) => detail(d.clone(), devices, selected).into_view(),
            None => overview(devices, selected).into_view(),
        }
    }))
}

fn overview(devices: Signal<Vec<Value>>, selected: Signal<String>) -> Div {
    sheet("Devices").child(group().child(dyn_view(move || {
        let list = devices.get();
        if list.is_empty() {
            return note("Looking for devices…").into_view();
        }
        let mut g = div().flex().flex_col();
        for d in list {
            let id = d["id"].as_str().unwrap_or("").to_owned();
            let kind = d["kind"].as_str().unwrap_or("").to_owned();
            let conn = d["connection"].as_str().unwrap_or("").to_owned();
            let battery = d["battery"].as_u64();
            let sub = match battery {
                Some(b) => format!("{} · {} · {b}%", capital(&kind), conn),
                None => format!("{} · {}", capital(&kind), conn),
            };
            g = g.child(
                click_row()
                    .on_click(move |_| selected.set(id.clone()))
                    .child(fixed(15.0, glyph(&kind)).w(20.0_f32))
                    .child(name_and(
                        d["name"].as_str().unwrap_or("").to_owned(),
                        move || sub.clone(),
                    ))
                    .child(fixed(13.0, "󰅂").dyn_style(|s| s.text_color(t().muted))),
            );
        }
        g.into_view()
    })))
}

fn capital(s: &str) -> String {
    let mut c = s.chars();
    c.next()
        .map(|f| f.to_uppercase().chain(c).collect())
        .unwrap_or_default()
}

/// Sends one setting to the helper, and puts the answer back into the list.
fn set(devices: Signal<Vec<Value>>, id: String, key: &'static str, v: Value) {
    let body = serde_json::json!({ "id": id, "settings": { key: v } }).to_string();
    devices.update(|list| {
        if let Some(d) = list.iter_mut().find(|d| d["id"] == id.as_str()) {
            d["settings"][key] = v.clone();
        }
    });
    run_output(vec![helper(), "set".into(), body]);
}

fn detail(d: Value, devices: Signal<Vec<Value>>, selected: Signal<String>) -> Div {
    let id = d["id"].as_str().unwrap_or("").to_owned();
    let kind = d["kind"].as_str().unwrap_or("").to_owned();
    let read = {
        let id = id.clone();
        move |key: &'static str| -> Value {
            devices.with(|l| {
                l.iter()
                    .find(|x| x["id"] == id.as_str())
                    .map(|x| x["settings"][key].clone())
                    .unwrap_or(Value::Null)
            })
        }
    };
    let mut g = group();

    let slider_row = |name: &'static str, key: &'static str, lo: f32, hi: f32, g: Div| {
        let id = id.clone();
        let read = read.clone();
        // Applied while dragging, at most every 120 ms.
        let pending: std::rc::Rc<Cell<Option<Timeout>>> = Default::default();
        let value = signal(read(key).as_f64().unwrap_or(0.0) as f32);
        let binding = Binding::new(
            move || (value.get() - lo) / (hi - lo),
            move |f: f32| {
                let v = ((lo + f * (hi - lo)) * 100.0).round() / 100.0;
                value.set(v);
                if let Some(p) = pending.take() {
                    p.cancel();
                }
                let id = id.clone();
                pending.set(Some(set_timeout(Duration::from_millis(120), move || {
                    set(devices, id, key, serde_json::json!(v));
                })));
            },
        );
        g.child(
            row()
                .child(fixed(13.0, name).w(130.0_f32))
                .child(volume_slider(binding).flex_1())
                .child(
                    label(12.0, move || format!("{:.2}", value.get()))
                        .w(40.0_f32)
                        .dyn_style(|s| s.text_color(t().soft)),
                ),
        )
    };
    let switch_row = |name: &'static str, key: &'static str, g: Div| {
        let id = id.clone();
        let read = read.clone();
        g.child(
            row()
                .child(fixed(13.0, name).flex_1())
                .child(toggle(Binding::new(
                    move || read(key).as_bool().unwrap_or(false),
                    move |on| set(devices, id.clone(), key, Value::Bool(on)),
                ))),
        )
    };

    let settings = d["settings"].as_object().cloned().unwrap_or_default();
    if settings.contains_key("speed") {
        g = slider_row("Pointer speed", "speed", -1.0, 1.0, g);
    }
    if settings.contains_key("scroll") {
        let hi = 4.0;
        let lo = if kind == "touchpad" { 0.1 } else { 0.2 };
        g = slider_row("Scroll speed", "scroll", lo, hi, g);
    }
    if settings.contains_key("natural_scroll") {
        g = switch_row("Natural scrolling", "natural_scroll", g);
    }
    if settings.contains_key("acceleration") {
        g = switch_row("Pointer acceleration", "acceleration", g);
    }
    if settings.contains_key("tap_to_click") {
        g = switch_row("Tap to click", "tap_to_click", g);
    }
    if settings.contains_key("swap_alt_super") {
        g = switch_row("Swap Alt and Super", "swap_alt_super", g);
    }
    let mut extras = group();
    let mut has_extras = false;
    for e in d["extras"].as_array().cloned().unwrap_or_default() {
        has_extras = true;
        let v = e["value"].as_str().unwrap_or("").to_owned();
        extras = extras.child(
            row()
                .child(fixed(13.0, e["title"].as_str().unwrap_or("").to_owned()).w(130.0_f32))
                .child(value(move || v.clone())),
        );
    }

    let mut p = sheet(d["name"].as_str().unwrap_or("Device"))
        .child(
            fixed(12.0, "󰅁 Devices")
                .on_click(move |_| selected.set(String::new()))
                .dyn_style(|s| s.text_color(t().soft)),
        )
        .child(g);
    if has_extras {
        p = p.child(section("On the device")).child(extras);
    }
    p
}

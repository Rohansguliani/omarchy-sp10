//! The Sound menu, like macOS's: the volume, where sound goes, the apps playing (folded away
//! until asked for), and a way into Settings.

use crate::theme::{fixed, label, t, FONT};
use crate::ui::{menu_panel, menu_row, menu_title, separator, volume_slider};
use anti_webui::prelude::*;
use anti_webui::shell::prelude::*;
use anti_webui::shell::{AudioDevice, AudioStream};

/// Headphones by what their name says.
pub fn is_headphones(description: &str, name: &str) -> bool {
    let s = format!("{description} {name}").to_lowercase();
    ["headphone", "headset", "airpods", "buds", "bluez"]
        .iter()
        .any(|k| s.contains(k))
}

/// A short name for an output, as macOS would put it.
pub fn device_name(d: &AudioDevice) -> String {
    let desc = d.description.trim();
    let lower = desc.to_lowercase();
    if lower.contains("alc")
        || lower.contains("built-in")
        || lower.contains("analog stereo") && !lower.contains("usb")
    {
        return "Speakers".into();
    }
    if lower.contains("hdmi") || lower.contains("displayport") {
        return "Display".into();
    }
    let short = desc
        .trim_end_matches(" Analog Stereo")
        .trim_end_matches(" Digital Stereo (IEC958)")
        .trim_end_matches(" Stereo");
    if short.to_lowercase().starts_with("hp usb-c") {
        return "HP Dock".into();
    }
    short.to_owned()
}

fn device_glyph(d: &AudioDevice) -> &'static str {
    let lower = d.description.to_lowercase();
    if is_headphones(&d.description, &d.name) {
        "󰋋"
    } else if lower.contains("hdmi")
        || lower.contains("displayport")
        || lower.contains("dock")
        || lower.contains("hp usb")
    {
        "󰍹"
    } else {
        "󰓃"
    }
}

/// The default output's volume, as a binding a slider can drive.
fn output_volume() -> Binding<f32> {
    Binding::new(
        || {
            audio()
                .default_sink()
                .map(|s| s.volume as f32)
                .unwrap_or(0.0)
        },
        |v: f32| {
            if let Some(s) = audio().default_sink() {
                let _ = s.set_volume(v as f64);
                if s.muted && v > 0.0 {
                    let _ = s.set_muted(false);
                }
            }
        },
    )
}

fn stream_volume(id: u32) -> Binding<f32> {
    let find = move || audio().streams().into_iter().find(|s| s.id == id);
    Binding::new(
        move || find().map(|s| s.volume as f32).unwrap_or(0.0),
        move |v: f32| {
            if let Some(s) = find() {
                let _ = s.set_volume(v as f64);
            }
        },
    )
}

fn playing() -> Vec<AudioStream> {
    let mut list: Vec<AudioStream> = audio().streams().into_iter().filter(|s| !s.input).collect();
    list.sort_by(|a, b| a.app_name.to_lowercase().cmp(&b.app_name.to_lowercase()));
    list
}

pub fn menu() -> Div {
    let apps_open = signal(false);
    menu_panel(300.0)
        .child(menu_title("Sound"))
        .child(
            div()
                .flex()
                .flex_row()
                .items_center()
                .gap(10.0_f32)
                .px(12.0_f32)
                .py(6.0_f32)
                .child(
                    label(15.0, || crate::bar::volume_glyph().to_owned())
                        .w(18.0_f32)
                        .on_click(|_| crate::sys::spawn("omarchy-audio-output-volume mute-toggle")),
                )
                .child(volume_slider(output_volume()).flex_1()),
        )
        .child(separator())
        .child(menu_title("Output"))
        .child(for_each(
            || audio().sinks(),
            |d: &AudioDevice| d.id,
            |d: AudioDevice| {
                let id = d.id;
                let is_default = memo(move || audio().default_sink().is_some_and(|s| s.id == id));
                let dev = d.clone();
                menu_row()
                    .on_click(move |_| {
                        let _ = audio().set_default(&dev);
                    })
                    .child(fixed(14.0, device_glyph(&d)).w(18.0_f32))
                    .child(
                        fixed(13.0, device_name(&d))
                            .flex_1()
                            .min_w(0.0)
                            .overflow_hidden(),
                    )
                    .child(label(13.0, move || {
                        if is_default.get() {
                            "󰄬".into()
                        } else {
                            String::new()
                        }
                    }))
            },
        ))
        .child(separator())
        .child(
            menu_row()
                .on_click(move |_| apps_open.update(|o| *o = !*o))
                .child(
                    label(13.0, || {
                        let n = playing().len();
                        if n == 0 {
                            "No apps playing".into()
                        } else {
                            format!("Apps · {n}")
                        }
                    })
                    .flex_1(),
                )
                .child(label(13.0, move || {
                    if apps_open.get() {
                        "󰅀".into()
                    } else {
                        "󰅂".into()
                    }
                })),
        )
        .child(show(
            move || apps_open.get(),
            || {
                div().flex().flex_col().child(for_each(
                    playing,
                    |s: &AudioStream| s.id,
                    |s: AudioStream| {
                        let name = if s.app_name.is_empty() {
                            s.media_name.clone()
                        } else {
                            s.app_name.clone()
                        };
                        div()
                            .flex()
                            .flex_col()
                            .gap(2.0_f32)
                            .px(12.0_f32)
                            .py(4.0_f32)
                            .child(
                                fixed(12.0, name)
                                    .overflow_hidden()
                                    .dyn_style(|st| st.text_color(t().soft)),
                            )
                            .child(volume_slider(stream_volume(s.id)))
                    },
                ))
            },
        ))
        .child(separator())
        .child(
            menu_row()
                .on_click(|_| {
                    crate::bar::close_menu();
                    crate::settings::open(Some("sound"));
                })
                .child(fixed(13.0, "Sound Settings…").font_family(FONT)),
        )
}

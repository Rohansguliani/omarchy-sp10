//! Sound: where sound goes and comes from, their volumes, and each app's volume.

use super::kit::*;
use crate::sound::device_name;
use crate::theme::{fixed, label};
use crate::ui::volume_slider;
use anti_webui::prelude::*;
use anti_webui::shell::prelude::*;
use anti_webui::shell::{AudioDevice, AudioStream};

fn device_volume(input: bool) -> Binding<f32> {
    let dev = move || {
        if input {
            audio().default_source()
        } else {
            audio().default_sink()
        }
    };
    Binding::new(
        move || dev().map(|d| d.volume as f32).unwrap_or(0.0),
        move |v: f32| {
            if let Some(d) = dev() {
                let _ = d.set_volume(v as f64);
            }
        },
    )
}

fn devices(input: bool) -> Div {
    group()
        .child(for_each(
            move || {
                if input {
                    audio().sources()
                } else {
                    audio().sinks()
                }
            },
            |d: &AudioDevice| d.id,
            move |d: AudioDevice| {
                let id = d.id;
                let on = memo(move || {
                    let def = if input {
                        audio().default_source()
                    } else {
                        audio().default_sink()
                    };
                    def.is_some_and(|x| x.id == id)
                });
                let dev = d.clone();
                click_row()
                    .on_click(move |_| {
                        let _ = audio().set_default(&dev);
                    })
                    .child(
                        fixed(13.0, device_name(&d))
                            .flex_1()
                            .min_w(0.0)
                            .overflow_hidden(),
                    )
                    .child(label(13.0, move || {
                        if on.get() {
                            "󰄬".into()
                        } else {
                            String::new()
                        }
                    }))
            },
        ))
        .child(
            row()
                .child(fixed(12.0, "Volume").w(70.0_f32))
                .child(volume_slider(device_volume(input)).flex_1()),
        )
}

pub fn page() -> Div {
    sheet("Sound")
        .child(section("Output"))
        .child(devices(false))
        .child(section("Input"))
        .child(devices(true))
        .child(section("Apps"))
        .child(group().child(dyn_view(|| {
            let n = audio().streams().iter().filter(|s| !s.input).count();
            if n == 0 {
                note("No apps are playing sound").into_view()
            } else {
                div()
                    .flex()
                    .flex_col()
                    .child(for_each(
                        || {
                            audio()
                                .streams()
                                .into_iter()
                                .filter(|s| !s.input)
                                .collect::<Vec<_>>()
                        },
                        |s: &AudioStream| s.id,
                        |s: AudioStream| {
                            let id = s.id;
                            let find = move || audio().streams().into_iter().find(|x| x.id == id);
                            let vol = Binding::new(
                                move || find().map(|x| x.volume as f32).unwrap_or(0.0),
                                move |v: f32| {
                                    if let Some(x) = find() {
                                        let _ = x.set_volume(v as f64);
                                    }
                                },
                            );
                            let name = if s.app_name.is_empty() {
                                s.media_name.clone()
                            } else {
                                s.app_name.clone()
                            };
                            row()
                                .child(fixed(13.0, name).w(160.0_f32).overflow_hidden())
                                .child(volume_slider(vol).flex_1())
                                .child(
                                    label(15.0, move || {
                                        if find().is_some_and(|x| x.muted) {
                                            "󰝟".into()
                                        } else {
                                            "󰕾".into()
                                        }
                                    })
                                    .on_click(move |_| {
                                        if let Some(x) = find() {
                                            let _ = x.set_muted(!x.muted);
                                        }
                                    }),
                                )
                        },
                    ))
                    .into_view()
            }
        })))
}

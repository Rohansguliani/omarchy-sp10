//! Control Center: quick toggles, volume and brightness, and the battery, in one menu from
//! the bar, like macOS's. Each tile toggles; its › opens that page of Settings.

use crate::settings::kit::{argv, run_output};
use crate::theme::{fixed, label, t, FONT};
use crate::ui::volume_slider;
use anti_webui::prelude::*;
use anti_webui::shell::prelude::*;
use std::cell::Cell;
use std::path::PathBuf;
use std::rc::Rc;
use std::time::Duration;

fn open_settings(page: Option<&'static str>) {
    crate::bar::close_menu();
    crate::settings::open(page);
}

fn stay_awake_file() -> PathBuf {
    PathBuf::from(std::env::var("HOME").unwrap_or_default())
        .join(".local/state/omarchy/indicators/stay-awake")
}

fn has_backlight() -> bool {
    std::fs::read_dir("/sys/class/backlight").is_ok_and(|mut d| d.next().is_some())
}

fn round_button(glyph: &'static str, click: impl Fn() + 'static) -> Div {
    let hover = signal(false);
    fixed(15.0, glyph)
        .size(30.0_f32)
        .flex()
        .items_center()
        .justify_center()
        .rounded(15.0_f32)
        .on_hover(move |h| hover.set(h))
        .on_click(move |_| click())
        .dyn_style(move |s| if hover.get() { s.bg(t().raised) } else { s })
}

/// One tile: clicking it toggles; `more` adds a › that opens a Settings page.
fn tile(
    glyph: impl Fn() -> String + 'static,
    title: &'static str,
    sub: impl Fn() -> String + 'static,
    on: impl Fn() -> bool + Copy + 'static,
    click: impl Fn() + 'static,
    more: Option<&'static str>,
) -> Div {
    let hover = signal(false);
    let mut d = div()
        .flex()
        .flex_row()
        .items_center()
        .flex_1()
        .min_w(0.0)
        .h(46.0_f32)
        .rounded(8.0_f32)
        .border(1.0_f32)
        .overflow_hidden()
        .dyn_style(move |s| {
            let th = t();
            s.bg(if on() { th.raised } else { th.panel })
                .border_color(th.border)
        })
        .child(
            div()
                .flex()
                .flex_row()
                .items_center()
                .gap(9.0_f32)
                .flex_1()
                .min_w(0.0)
                .h_full()
                .pl(10.0_f32)
                .on_hover(move |h| hover.set(h))
                .on_click(move |_| click())
                .dyn_style(move |s| {
                    if hover.get() {
                        s.bg(t().border.with_alpha(0.4))
                    } else {
                        s
                    }
                })
                .child(label(15.0, glyph).w(18.0_f32).dyn_style(move |s| {
                    let th = t();
                    s.text_color(if on() { th.bright } else { th.soft })
                }))
                .child(
                    div()
                        .flex()
                        .flex_col()
                        .flex_1()
                        .min_w(0.0)
                        .child(fixed(12.0, title).bold().overflow_hidden())
                        .child(
                            label(11.0, sub)
                                .overflow_hidden()
                                .dyn_style(|s| s.text_color(t().soft)),
                        ),
                ),
        );
    if let Some(page) = more {
        let hover = signal(false);
        d = d.child(
            fixed(13.0, "\u{f0142}")
                .w(26.0_f32)
                .h_full()
                .flex()
                .items_center()
                .justify_center()
                .on_hover(move |h| hover.set(h))
                .on_click(move |_| open_settings(Some(page)))
                .dyn_style(move |s| {
                    let th = t();
                    let s = s.text_color(th.muted);
                    if hover.get() {
                        s.bg(th.border.with_alpha(0.4))
                    } else {
                        s
                    }
                }),
        );
    }
    d
}

fn pair(a: Div, b: Div) -> Div {
    div().flex().flex_row().gap(6.0_f32).child(a).child(b)
}

fn card() -> Div {
    div()
        .flex()
        .flex_col()
        .gap(8.0_f32)
        .p(10.0_f32)
        .rounded(8.0_f32)
        .border(1.0_f32)
        .dyn_style(|s| {
            let th = t();
            s.bg(th.panel).border_color(th.border)
        })
}

fn header() -> Div {
    let user = std::env::var("USER").unwrap_or_default();
    let initial = user
        .chars()
        .next()
        .map(|c| c.to_uppercase().to_string())
        .unwrap_or_default();
    div()
        .flex()
        .flex_row()
        .items_center()
        .gap(10.0_f32)
        .child(
            fixed(13.0, initial)
                .size(30.0_f32)
                .flex()
                .items_center()
                .justify_center()
                .rounded(15.0_f32)
                .bold()
                .dyn_style(|s| s.bg(t().raised)),
        )
        .child(
            div()
                .flex()
                .flex_col()
                .flex_1()
                .min_w(0.0)
                .child(fixed(13.0, user).bold())
                .child(
                    label(11.0, || {
                        const DAYS: [&str; 7] = [
                            "Sunday",
                            "Monday",
                            "Tuesday",
                            "Wednesday",
                            "Thursday",
                            "Friday",
                            "Saturday",
                        ];
                        const MONTHS: [&str; 12] = [
                            "January",
                            "February",
                            "March",
                            "April",
                            "May",
                            "June",
                            "July",
                            "August",
                            "September",
                            "October",
                            "November",
                            "December",
                        ];
                        let n = local_time(Every::Minute);
                        let date = format!(
                            "{}, {} {}",
                            DAYS[n.weekday as usize % 7],
                            MONTHS[(n.month as usize + 11) % 12],
                            n.day
                        );
                        let b = battery();
                        if b.available() {
                            format!("{date} · {:.0}%", b.percentage())
                        } else {
                            date
                        }
                    })
                    .dyn_style(|s| s.text_color(t().soft)),
                ),
        )
        .child(round_button("\u{f0493}", || open_settings(None)))
        .child(round_button("\u{f0425}", || {
            crate::bar::close_menu();
            crate::sys::spawn("omarchy-menu toggle system");
        }))
}

fn tiles() -> Div {
    let dnd = signal(false);
    let read_dnd = move || {
        run_output(argv(&["omarchy-shell", "notifications", "isDnd"]))
            .then(move |o| dnd.set(o.trim() == "on"));
    };
    read_dnd();
    let awake = signal(stay_awake_file().exists());

    let wifi = tile(
        || {
            if network().wifi_enabled() {
                "\u{f05a9}".into()
            } else {
                "\u{f05aa}".into()
            }
        },
        "Wi-Fi",
        || {
            if !network().wifi_enabled() {
                "Off".into()
            } else {
                network()
                    .wifi()
                    .map(|a| a.ssid)
                    .unwrap_or_else(|| "Not connected".into())
            }
        },
        || network().wifi_enabled(),
        || {
            let _ = network().set_wifi_enabled(!network().wifi_enabled());
        },
        Some("wifi"),
    );
    let bt_on = || bluetooth().adapter().is_some_and(|a| a.powered);
    let bt = tile(
        move || {
            if bt_on() {
                "\u{f00af}".into()
            } else {
                "\u{f00b2}".into()
            }
        },
        "Bluetooth",
        move || {
            if !bt_on() {
                return "Off".into();
            }
            let connected: Vec<String> = bluetooth()
                .devices()
                .into_iter()
                .filter(|d| d.connected)
                .map(|d| d.name)
                .collect();
            match connected.len() {
                0 => "On".into(),
                1 => connected[0].clone(),
                n => format!("{n} devices"),
            }
        },
        bt_on,
        move || {
            let _ = bluetooth().set_powered(!bt_on());
        },
        Some("bluetooth"),
    );
    let quiet = tile(
        move || {
            if dnd.get() {
                "\u{f009b}".into()
            } else {
                "\u{f009a}".into()
            }
        },
        "Do Not Disturb",
        move || if dnd.get() { "On".into() } else { "Off".into() },
        move || dnd.get(),
        move || {
            run_output(argv(&["omarchy-toggle-notification-silencing"])).then(move |_| read_dnd());
        },
        None,
    );
    let stay = tile(
        || "\u{f0176}".into(),
        "Stay Awake",
        move || {
            if awake.get() {
                "On".into()
            } else {
                "Off".into()
            }
        },
        move || awake.get(),
        move || {
            run_output(argv(&["omarchy-toggle-idle", "toggle"]))
                .then(move |_| awake.set(stay_awake_file().exists()));
        },
        None,
    );
    let mode_name = || match power_profiles().active().as_str() {
        "power-saver" => "Low Power".to_owned(),
        "performance" => "High Performance".to_owned(),
        "balanced" => "Balanced".to_owned(),
        "" => "Unavailable".to_owned(),
        other => other.to_owned(),
    };
    let power = tile(
        || "\u{f04c5}".into(),
        "Power Mode",
        mode_name,
        || power_profiles().active() == "performance",
        || {
            let next = match power_profiles().active().as_str() {
                "power-saver" => "balanced",
                "balanced" => "performance",
                _ => "power-saver",
            };
            let _ = power_profiles().set_active(next);
        },
        Some("battery"),
    );
    let mic_on = || audio().default_source().is_some_and(|s| !s.muted);
    let mic = tile(
        move || {
            if mic_on() {
                "\u{f036c}".into()
            } else {
                "\u{f036d}".into()
            }
        },
        "Microphone",
        || match audio().default_source() {
            Some(s) if s.muted => "Muted".into(),
            Some(s) => crate::sound::device_name(&s),
            None => "None".into(),
        },
        mic_on,
        || {
            if let Some(s) = audio().default_source() {
                let _ = s.set_muted(!s.muted);
            }
        },
        Some("sound"),
    );
    div()
        .flex()
        .flex_col()
        .gap(6.0_f32)
        .child(pair(wifi, bt))
        .child(pair(quiet, stay))
        .child(pair(power, mic))
}

fn sliders() -> Div {
    let volume = Binding::new(
        || {
            audio()
                .default_sink()
                .map(|d| d.volume as f32)
                .unwrap_or(0.0)
        },
        |v: f32| {
            if let Some(d) = audio().default_sink() {
                let _ = d.set_volume(v as f64);
            }
        },
    );
    let mut c = card().child(
        div()
            .flex()
            .flex_row()
            .items_center()
            .gap(10.0_f32)
            .child(
                label(15.0, || crate::bar::volume_glyph().to_owned())
                    .w(18.0_f32)
                    .on_click(|_| {
                        if let Some(d) = audio().default_sink() {
                            let _ = d.set_muted(!d.muted);
                        }
                    }),
            )
            .child(volume_slider(volume).flex_1())
            .child(
                fixed(13.0, "\u{f0142}")
                    .on_click(|_| open_settings(Some("sound")))
                    .dyn_style(|s| s.text_color(t().muted)),
            ),
    );
    if has_backlight() {
        let level = signal(-1.0_f32);
        run_output(argv(&["brightnessctl", "-m"])).then(move |o| {
            let pct = o
                .lines()
                .next()
                .and_then(|l| l.split(',').nth(3))
                .and_then(|p| p.trim_end_matches('%').parse::<f32>().ok());
            if let Some(p) = pct {
                level.set(p / 100.0);
            }
        });
        // Applied while dragging, at most every 60 ms.
        let pending: Rc<Cell<Option<Timeout>>> = Default::default();
        let brightness = Binding::new(
            move || level.get().max(0.0),
            move |v: f32| {
                level.set(v);
                if let Some(p) = pending.take() {
                    p.cancel();
                }
                let pct = format!("{}%", (v * 100.0).round().max(1.0));
                pending.set(Some(set_timeout(Duration::from_millis(60), move || {
                    run_output(argv(&["brightnessctl", "-q", "set", &pct]));
                })));
            },
        );
        c = c.child(
            div()
                .flex()
                .flex_row()
                .items_center()
                .gap(10.0_f32)
                .child(fixed(15.0, "\u{f00e0}").w(18.0_f32))
                .child(volume_slider(brightness).flex_1())
                .child(div().w(8.0_f32)),
        );
    }
    c
}

fn stat(title: &'static str, value: impl Fn() -> String + 'static) -> Div {
    div()
        .flex()
        .flex_col()
        .flex_1()
        .gap(2.0_f32)
        .p(8.0_f32)
        .rounded(6.0_f32)
        .dyn_style(|s| s.bg(t().raised))
        .child(fixed(11.0, title).dyn_style(|s| s.text_color(t().soft)))
        .child(label(14.0, value).bold())
}

fn battery_card() -> Div {
    card()
        .child(
            div()
                .flex()
                .flex_row()
                .items_end()
                .gap(10.0_f32)
                .child(label(26.0, || format!("{:.0}%", battery().percentage())).bold())
                .child(
                    label(12.0, crate::battery::state_text)
                        .pb(4.0_f32)
                        .flex_1()
                        .dyn_style(|s| s.text_color(t().soft)),
                ),
        )
        .child(
            div()
                .flex()
                .flex_row()
                .gap(6.0_f32)
                .child(stat("Health", || {
                    battery()
                        .health()
                        .map(|h| format!("{h:.0}%"))
                        .unwrap_or_else(|| "—".into())
                }))
                .child(stat("Cycles", || {
                    battery()
                        .charge_cycles()
                        .map(|c| c.to_string())
                        .unwrap_or_else(|| "—".into())
                })),
        )
}

pub fn menu() -> Div {
    div()
        .w(340.0_f32)
        .flex()
        .flex_col()
        .gap(10.0_f32)
        .p(12.0_f32)
        .rounded(12.0_f32)
        .border(1.0_f32)
        .font_family(FONT)
        .select_none()
        .on_key_down(|e| {
            if e.key == Key::Named(NamedKey::Escape) {
                crate::bar::close_menu();
            }
        })
        .dyn_style(|s| {
            let th = t();
            s.bg(th.bg).border_color(th.border).text_color(th.fg)
        })
        .child(header())
        .child(tiles())
        .child(sliders())
        .child(show(|| battery().available(), battery_card))
}

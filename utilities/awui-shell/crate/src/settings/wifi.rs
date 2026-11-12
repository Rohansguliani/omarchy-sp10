//! Wi-Fi: the switch, the network in use, the ones joined before (in range or not), and the
//! others in range, with the password asked for right in the row.

use super::kit::*;
use crate::theme::{fixed, label, t};
use anti_webui::prelude::*;
use anti_webui::shell::prelude::*;
use anti_webui::shell::{AccessPoint, Security};
use std::time::Duration;

fn bars(strength: u8) -> &'static str {
    match strength {
        0..=24 => "󰤟",
        25..=49 => "󰤢",
        50..=74 => "󰤥",
        _ => "󰤨",
    }
}

fn wifi_on() -> Binding<bool> {
    Binding::new(
        || network().wifi_enabled(),
        |on| {
            let _ = network().set_wifi_enabled(on);
        },
    )
}

/// Wi-Fi connections NetworkManager has saved, by name (their SSIDs, in practice).
fn saved_networks(out: &str) -> Vec<String> {
    out.lines()
        .filter_map(|l| {
            let (name, kind) = l.rsplit_once(':')?;
            (kind == "802-11-wireless").then(|| name.replace("\\:", ":"))
        })
        .collect()
}

pub fn page() -> Div {
    let saved = signal(Vec::<String>::new());
    let ip = signal(String::new());
    let refresh = move || {
        run_output(argv(&[
            "nmcli",
            "-t",
            "-f",
            "NAME,TYPE",
            "connection",
            "show",
        ]))
        .then(move |out| saved.set(saved_networks(&out)));
        run_output(argv(&["sh", "-c", "nmcli -t -g IP4.ADDRESS device show $(nmcli -t -f DEVICE,TYPE device | awk -F: '$2==\"wifi\"{print $1; exit}') | head -1"]))
            .then(move |out| ip.set(out.trim().split('/').next().unwrap_or("").to_owned()));
    };
    refresh();
    // Scans while the page is on view; NetworkManager keeps the list fresh.
    let _ = network().scan();
    let ticking = signal(0u32);
    fn every(ticking: Signal<u32>, refresh: impl Fn() + Copy + 'static) {
        set_timeout(Duration::from_secs(8), move || {
            if ticking.is_alive()
                && crate::settings::is_open()
                && crate::settings::current_page() == "wifi"
            {
                let _ = network().scan();
                refresh();
                ticking.update(|t| *t += 1);
                every(ticking, refresh);
            }
        });
    }
    every(ticking, refresh);
    let expanded = signal(String::new());
    let password = signal(String::new());
    let error = signal(String::new());

    sheet("Wi-Fi")
        .child(
            group().child(
                row()
                    .child(fixed(15.0, "󰖩").w(20.0_f32))
                    .child(fixed(13.0, "Wi-Fi").flex_1())
                    .child(toggle(wifi_on())),
            ),
        )
        .child(show(
            || network().wifi_enabled() && network().wifi().is_some(),
            move || {
                div()
                    .flex()
                    .flex_col()
                    .gap(14.0_f32)
                    .child(section("Connected"))
                    .child(
                        group().child(
                            row()
                                .child(
                                    label(15.0, || {
                                        network()
                                            .wifi()
                                            .map(|a| bars(a.strength))
                                            .unwrap_or("")
                                            .to_owned()
                                    })
                                    .w(20.0_f32),
                                )
                                .child(name_and_dyn(
                                    || network().wifi().map(|a| a.ssid).unwrap_or_default(),
                                    move || {
                                        let i = ip.get();
                                        if i.is_empty() {
                                            "Connected".into()
                                        } else {
                                            format!("Connected · {i}")
                                        }
                                    },
                                ))
                                .child(btn("Disconnect", false, || {
                                    let _ = network().disconnect();
                                }))
                                .child(btn("Forget", false, move || {
                                    if let Some(a) = network().wifi() {
                                        run_output(argv(&[
                                            "nmcli",
                                            "connection",
                                            "delete",
                                            "id",
                                            &a.ssid,
                                        ]))
                                        .then(move |_| refresh());
                                    }
                                })),
                        ),
                    )
            },
        ))
        .child(show(
            || network().wifi_enabled(),
            move || {
                div()
                    .flex()
                    .flex_col()
                    .gap(14.0_f32)
                    .child(section("Previously connected"))
                    .child(group().child(dyn_view(move || {
                        let active = network().wifi().map(|a| a.ssid).unwrap_or_default();
                        let in_range = network().access_points();
                        let list: Vec<String> =
                            saved.get().into_iter().filter(|s| *s != active).collect();
                        if list.is_empty() {
                            return note("No other saved networks").into_view();
                        }
                        let mut g = div().flex().flex_col();
                        for ssid in list {
                            let ap = in_range.iter().find(|a| a.ssid == ssid).cloned();
                            let s2 = ssid.clone();
                            g = g.child(
                                row()
                                    .child(
                                        fixed(
                                            15.0,
                                            ap.as_ref().map(|a| bars(a.strength)).unwrap_or("󰤮"),
                                        )
                                        .w(20.0_f32),
                                    )
                                    .child(name_and(ssid.clone(), {
                                        let here = ap.is_some();
                                        move || {
                                            if here {
                                                "In range".into()
                                            } else {
                                                "Not in range".into()
                                            }
                                        }
                                    }))
                                    .child(match ap {
                                        Some(ap) => btn("Join", true, move || {
                                            let _ = network().connect(&ap, None);
                                        }),
                                        None => div(),
                                    })
                                    .child(btn("Forget", false, move || {
                                        run_output(argv(&[
                                            "nmcli",
                                            "connection",
                                            "delete",
                                            "id",
                                            &s2,
                                        ]))
                                        .then(move |_| refresh());
                                    })),
                            );
                        }
                        g.into_view()
                    })))
                    .child(section("Other networks"))
                    .child(group().child(dyn_view(move || {
                        let saved_now = saved.get();
                        let mut seen = std::collections::HashSet::new();
                        let mut list: Vec<AccessPoint> = network()
                            .access_points()
                            .into_iter()
                            .filter(|a| {
                                !a.ssid.is_empty()
                                    && !a.active
                                    && !saved_now.contains(&a.ssid)
                                    && seen.insert(a.ssid.clone())
                            })
                            .collect();
                        list.sort_by(|a, b| b.strength.cmp(&a.strength));
                        if list.is_empty() {
                            return note("No other networks in range").into_view();
                        }
                        let mut g = div().flex().flex_col();
                        for ap in list {
                            let ssid = ap.ssid.clone();
                            let open_net = ap.security == Security::Open;
                            let s_click = ssid.clone();
                            let s_show = ssid.clone();
                            let ap_join = ap.clone();
                            g = g.child(
                                click_row()
                                    .on_click(move |_| {
                                        if open_net {
                                            let _ = network().connect(&ap_join, None);
                                        } else {
                                            password.set(String::new());
                                            error.set(String::new());
                                            expanded.set(s_click.clone());
                                        }
                                    })
                                    .child(fixed(15.0, bars(ap.strength)).w(20.0_f32))
                                    .child(
                                        fixed(13.0, ssid.clone())
                                            .flex_1()
                                            .min_w(0.0)
                                            .overflow_hidden(),
                                    )
                                    .child(
                                        fixed(13.0, if open_net { "" } else { "󰌾" })
                                            .dyn_style(|s| s.text_color(t().muted)),
                                    ),
                            );
                            let ap_pw = ap.clone();
                            g = g.child(show(
                                move || expanded.get() == s_show,
                                move || {
                                    let ap_pw = ap_pw.clone();
                                    let join = move |pw: String| {
                                        error.set(String::new());
                                        network().connect(&ap_pw, Some(pw)).then(
                                            move |r| match r {
                                                Ok(()) => expanded.set(String::new()),
                                                Err(e) => {
                                                    error.set(format!("Couldn't join: {e:?}"))
                                                }
                                            },
                                        );
                                    };
                                    let join2 = join.clone();
                                    row()
                                        .child(
                                            text_input()
                                                .value(password)
                                                .placeholder("Password")
                                                .purpose(ImePurpose::Password)
                                                .on_submit(move |s| join(s.to_owned()))
                                                .flex_1()
                                                .h(28.0_f32)
                                                .px(8.0_f32)
                                                .rounded(6.0_f32)
                                                .border(1.0_f32)
                                                .dyn_style(|s| {
                                                    let th = t();
                                                    s.bg(th.bg)
                                                        .border_color(th.border)
                                                        .text_color(th.fg)
                                                }),
                                        )
                                        .child(
                                            label(11.0, move || error.get())
                                                .dyn_style(|s| s.text_color(t().soft)),
                                        )
                                        .child(btn("Cancel", false, move || {
                                            expanded.set(String::new())
                                        }))
                                        .child(btn("Join", true, move || {
                                            join2(untrack(|| password.get()))
                                        }))
                                },
                            ));
                        }
                        g.into_view()
                    })))
            },
        ))
}

fn name_and_dyn(title: impl Fn() -> String + 'static, sub: impl Fn() -> String + 'static) -> Div {
    div()
        .flex()
        .flex_col()
        .flex_1()
        .min_w(0.0)
        .child(label(13.0, title).overflow_hidden())
        .child(
            label(11.0, sub)
                .overflow_hidden()
                .dyn_style(|s| s.text_color(t().soft)),
        )
}

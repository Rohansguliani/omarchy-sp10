//! Bluetooth: the switch, then connected, previously connected and nearby devices. It searches
//! only while this page is on view.

use super::kit::*;
use crate::theme::{fixed, label};
use anti_webui::prelude::*;
use anti_webui::shell::prelude::*;
use anti_webui::shell::BluetoothDevice;
use std::time::Duration;

fn glyph(icon: &str) -> &'static str {
    match icon {
        i if i.contains("headset") || i.contains("headphone") => "󰋋",
        i if i.contains("keyboard") => "󰌌",
        i if i.contains("mouse") => "󰍽",
        i if i.contains("phone") => "󰏲",
        i if i.contains("speaker") || i.contains("audio") => "󰓃",
        _ => "󰂯",
    }
}

fn powered() -> Binding<bool> {
    Binding::new(
        || bluetooth().adapter().is_some_and(|a| a.powered),
        |on| {
            let _ = bluetooth().set_powered(on);
        },
    )
}

fn sub(d: &BluetoothDevice) -> String {
    let state = if d.connected {
        "Connected"
    } else {
        "Not connected"
    };
    match d.battery {
        Some(b) => format!("{state} · {b}% battery"),
        None => state.into(),
    }
}

fn device_rows(list: Vec<BluetoothDevice>, empty: &'static str) -> View {
    if list.is_empty() {
        return note(empty).into_view();
    }
    let mut g = div().flex().flex_col();
    for d in list {
        let (a, b, c) = (d.clone(), d.clone(), d.clone());
        let mut r = row()
            .child(fixed(15.0, glyph(&d.icon)).w(20.0_f32))
            .child(name_and(d.name.clone(), {
                let s = sub(&d);
                move || s.clone()
            }));
        r = if d.paired {
            r.child(if d.connected {
                btn("Disconnect", false, move || {
                    let _ = a.disconnect();
                })
            } else {
                btn("Connect", true, move || {
                    let _ = a.connect();
                })
            })
            .child(btn("Forget", false, move || {
                let _ = b.forget();
            }))
        } else {
            r.child(btn("Pair", true, move || {
                let c = c.clone();
                c.pair().then(move |r| {
                    if r.is_ok() {
                        let _ = c.set_trusted(true);
                        let _ = c.connect();
                    }
                });
            }))
        };
        g = g.child(r);
    }
    g.into_view()
}

pub fn page() -> Div {
    // Searching starts with the page and stops a moment after it is left: a search left
    // running starves Bluetooth audio.
    let alive = signal(());
    fn keep_searching(alive: Signal<()>) {
        let on = alive.is_alive()
            && crate::settings::is_open()
            && crate::settings::current_page() == "bluetooth";
        if bluetooth()
            .adapter()
            .is_some_and(|a| a.powered && a.discovering != on)
        {
            let _ = bluetooth().set_discovering(on);
        }
        if on {
            set_timeout(Duration::from_secs(2), move || keep_searching(alive));
        } else if bluetooth().adapter().is_some_and(|a| a.discovering) {
            let _ = bluetooth().set_discovering(false);
        }
    }
    keep_searching(alive);
    on_cleanup(move || {
        set_timeout(Duration::from_millis(500), || {
            if !(crate::settings::is_open() && crate::settings::current_page() == "bluetooth")
                && bluetooth().adapter().is_some_and(|a| a.discovering)
            {
                let _ = bluetooth().set_discovering(false);
            }
        });
    });

    sheet("Bluetooth")
        .child(
            group().child(
                row()
                    .child(fixed(15.0, "󰂯").w(20.0_f32))
                    .child(fixed(13.0, "Bluetooth").flex_1())
                    .child(label(11.0, || {
                        if bluetooth().adapter().is_some_and(|a| a.discovering) {
                            "Searching…".into()
                        } else {
                            String::new()
                        }
                    }))
                    .child(toggle(powered())),
            ),
        )
        .child(show(
            || bluetooth().adapter().is_some_and(|a| a.powered),
            || {
                div()
                    .flex()
                    .flex_col()
                    .gap(14.0_f32)
                    .child(section("Connected"))
                    .child(group().child(dyn_view(|| {
                        device_rows(
                            bluetooth()
                                .devices()
                                .into_iter()
                                .filter(|d| d.connected)
                                .collect(),
                            "Nothing connected",
                        )
                    })))
                    .child(section("Previously connected"))
                    .child(group().child(dyn_view(|| {
                        device_rows(
                            bluetooth()
                                .devices()
                                .into_iter()
                                .filter(|d| d.paired && !d.connected)
                                .collect(),
                            "No other paired devices",
                        )
                    })))
                    .child(section("Nearby"))
                    .child(group().child(dyn_view(|| {
                        // Nameless beacons (shown as their address) are left out.
                        device_rows(
                            bluetooth()
                                .devices()
                                .into_iter()
                                .filter(|d| {
                                    !d.paired
                                        && !d.name.is_empty()
                                        && d.name.replace('-', ":") != d.address
                                })
                                .collect(),
                            "Put a device in pairing mode to see it here",
                        )
                    })))
            },
        ))
}

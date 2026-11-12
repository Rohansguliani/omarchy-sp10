//! The battery menu: charge, what it is doing, and the power mode.

use crate::theme::{fixed, label, t};
use crate::ui::{menu_panel, menu_row, menu_title, separator};
use anti_webui::prelude::*;
use anti_webui::shell::prelude::*;
use anti_webui::shell::BatteryState;

pub fn state_text() -> String {
    let b = battery();
    let hm = |d: std::time::Duration| {
        let m = d.as_secs() / 60;
        if m >= 60 {
            format!("{}h {:02}m", m / 60, m % 60)
        } else {
            format!("{m}m")
        }
    };
    match b.state() {
        BatteryState::Charging => match b.time_to_full() {
            Some(d) if d.as_secs() > 0 => format!("Charging, {} until full", hm(d)),
            _ => "Charging".into(),
        },
        BatteryState::Discharging => match b.time_to_empty() {
            Some(d) if d.as_secs() > 0 => format!("On battery, {} left", hm(d)),
            _ => "On battery".into(),
        },
        BatteryState::Full => "Fully charged".into(),
        _ if !b.on_battery() => "Plugged in, not charging".into(),
        _ => "On battery".into(),
    }
}

pub fn menu() -> Div {
    let mut m = menu_panel(260.0).child(
        div()
            .flex()
            .flex_row()
            .items_end()
            .justify_between()
            .px(12.0_f32)
            .pt(6.0_f32)
            .child(fixed(13.0, "Battery").bold())
            .child(label(20.0, || format!("{:.0}%", battery().percentage())).bold()),
    );
    m = m.child(
        label(12.0, state_text)
            .px(12.0_f32)
            .pb(4.0_f32)
            .dyn_style(|s| s.text_color(t().soft)),
    );
    // power-profiles-daemon answers after the menu is built, so this follows it.
    m = m.child(show(
        || power_profiles().available(),
        || {
            let mut d = div()
                .flex()
                .flex_col()
                .child(separator())
                .child(menu_title("Power Mode"));
            for (id, name) in [
                ("power-saver", "Low Power"),
                ("balanced", "Balanced"),
                ("performance", "High Performance"),
            ] {
                d = d.child(
                    menu_row()
                        .on_click(move |_| {
                            let _ = power_profiles().set_active(id);
                        })
                        .child(fixed(13.0, name).flex_1())
                        .child(label(13.0, move || {
                            if power_profiles().active() == id {
                                "󰄬".into()
                            } else {
                                String::new()
                            }
                        })),
                );
            }
            d
        },
    ));
    m.child(separator()).child(
        menu_row()
            .on_click(|_| {
                crate::bar::close_menu();
                crate::settings::open(Some("battery"));
            })
            .child(fixed(13.0, "Battery Settings…")),
    )
}

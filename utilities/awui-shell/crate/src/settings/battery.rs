//! Battery: charge, what it is doing, the power mode, and its health.

use super::kit::*;
use crate::theme::{fixed, label};
use anti_webui::prelude::*;
use anti_webui::shell::prelude::*;

pub fn page() -> Div {
    let mut p = sheet("Battery").child(
        group().child(
            row()
                .child(
                    label(15.0, || {
                        let b = battery();
                        crate::bar::battery_glyph(b.percentage(), b.charging()).to_owned()
                    })
                    .w(20.0_f32),
                )
                .child(name_and_label())
                .child(label(22.0, || format!("{:.0}%", battery().percentage())).bold()),
        ),
    );
    p = p.child(show(
        || power_profiles().available(),
        || {
            let mut g = group();
            for (id, name, sub) in [
                ("power-saver", "Low Power", "Longest battery life"),
                ("balanced", "Balanced", "Performance when needed"),
                (
                    "performance",
                    "High Performance",
                    "Fastest, uses more power",
                ),
            ] {
                g = g.child(
                    click_row()
                        .on_click(move |_| {
                            let _ = power_profiles().set_active(id);
                        })
                        .child(name_and(name.into(), move || sub.into()))
                        .child(label(13.0, move || {
                            if power_profiles().active() == id {
                                "󰄬".into()
                            } else {
                                String::new()
                            }
                        })),
                );
            }
            div()
                .flex()
                .flex_col()
                .gap(14.0_f32)
                .child(section("Power Mode"))
                .child(g)
        },
    ));
    p.child(section("Health")).child(
        group()
            .child(
                row()
                    .child(fixed(13.0, "Capacity").flex_1())
                    .child(value(|| match battery().health() {
                        Some(h) => format!("{h:.0}%"),
                        None => "—".into(),
                    })),
            )
            .child(
                row()
                    .child(fixed(13.0, "Charge cycles").flex_1())
                    .child(value(|| match battery().charge_cycles() {
                        Some(c) => c.to_string(),
                        None => "—".into(),
                    })),
            )
            .child(
                row()
                    .child(fixed(13.0, "Draw").flex_1())
                    .child(value(|| format!("{:.1} W", battery().energy_rate().abs()))),
            ),
    )
}

fn name_and_label() -> Div {
    div()
        .flex()
        .flex_col()
        .flex_1()
        .child(fixed(13.0, "Battery"))
        .child(
            label(11.0, crate::battery::state_text)
                .dyn_style(|s| s.text_color(crate::theme::t().soft)),
        )
}

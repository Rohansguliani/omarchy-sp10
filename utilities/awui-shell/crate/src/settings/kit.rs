//! Building blocks of the Settings pages: groups of rows like macOS's System Settings.

use crate::theme::{fixed, label, t, FONT};
use anti_webui::prelude::*;
use anti_webui::widgets::{styled_switch, SwitchParts};
use std::process::Command;

/// A page: its title, then what is given, scrolling.
pub fn sheet(title: &str) -> Div {
    div()
        .flex()
        .flex_col()
        .gap(14.0_f32)
        .p(24.0_f32)
        .size_full()
        .overflow_y_scroll()
        .font_family(FONT)
        .child(
            fixed(20.0, title)
                .bold()
                .dyn_style(|s| s.text_color(t().bright)),
        )
}

/// A heading over a group.
pub fn section(s: &str) -> Div {
    fixed(12.0, s)
        .bold()
        .pl(4.0_f32)
        .mb(-8.0_f32)
        .dyn_style(|st| st.text_color(t().muted))
}

/// A rounded box of rows, divided by thin lines.
pub fn group() -> Div {
    div()
        .flex()
        .flex_col()
        .rounded(10.0_f32)
        .border(1.0_f32)
        .overflow_hidden()
        .dyn_style(|s| {
            let th = t();
            s.bg(th.panel).border_color(th.border)
        })
}

/// A row of a group: something on the left, something on the right.
pub fn row() -> Div {
    div()
        .flex()
        .flex_row()
        .items_center()
        .gap(10.0_f32)
        .min_h(44.0_f32)
        .px(14.0_f32)
        .py(6.0_f32)
        .border_b(1.0_f32)
        .dyn_style(|s| s.border_color(t().border))
}

/// A row that lights up under the pointer, for rows that are clicked.
pub fn click_row() -> Div {
    let hover = signal(false);
    row()
        .on_hover(move |h| hover.set(h))
        .dyn_style(move |s| if hover.get() { s.bg(t().raised) } else { s })
}

/// A name with a fixed second line.
pub fn name_and(title: String, sub: impl Fn() -> String + 'static) -> Div {
    div()
        .flex()
        .flex_col()
        .flex_1()
        .min_w(0.0)
        .child(fixed(13.0, title).overflow_hidden())
        .child(
            label(11.0, sub)
                .overflow_hidden()
                .dyn_style(|s| s.text_color(t().soft)),
        )
}

/// Grey text on the right of a row.
pub fn value(f: impl Fn() -> String + 'static) -> Div {
    label(13.0, f).dyn_style(|s| s.text_color(t().soft))
}

/// A small rounded button.
pub fn btn(text: &str, primary: bool, on_click: impl Fn() + 'static) -> Div {
    let hover = signal(false);
    fixed(12.0, text)
        .px(12.0_f32)
        .h(26.0_f32)
        .flex()
        .items_center()
        .rounded(6.0_f32)
        .border(1.0_f32)
        .flex_none()
        .on_hover(move |h| hover.set(h))
        .on_click(move |_| on_click())
        .dyn_style(move |s| {
            let th = t();
            if primary {
                s.bg(if hover.get() { th.bright } else { th.fg })
                    .text_color(th.bg)
                    .border_color(th.fg)
            } else {
                s.bg(if hover.get() { th.raised } else { th.panel })
                    .border_color(th.border)
                    .text_color(th.fg)
            }
        })
}

/// An on/off switch in the theme's colors.
pub fn toggle(on: Binding<bool>) -> Div {
    styled_switch(
        on,
        SwitchParts::new()
            .track(move |d, s| {
                d.w(36.0_f32)
                    .h(20.0_f32)
                    .rounded(10.0_f32)
                    .dyn_style(move |st| {
                        let th = t();
                        st.bg(if s.on() { th.fg } else { th.border })
                    })
            })
            .thumb(move |d, s| {
                d.size(16.0_f32).rounded(8.0_f32).dyn_style(move |st| {
                    let th = t();
                    st.bg(if s.on() { th.bg } else { th.soft })
                })
            }),
    )
}

/// A message in grey, for an empty list.
pub fn note(s: &str) -> Div {
    fixed(12.0, s)
        .px(14.0_f32)
        .py(12.0_f32)
        .dyn_style(|st| st.text_color(t().muted))
}

/// Runs a command and gives its standard output, on another thread.
pub fn run_output(argv: Vec<String>) -> Task<String> {
    task(move || {
        let Some((cmd, args)) = argv.split_first() else {
            return String::new();
        };
        Command::new(cmd)
            .args(args)
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
            .unwrap_or_default()
    })
}

pub fn argv(parts: &[&str]) -> Vec<String> {
    parts.iter().map(|s| s.to_string()).collect()
}

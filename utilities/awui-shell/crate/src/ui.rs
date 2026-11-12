//! Pieces the menus share, in the Omarchy theme.

use crate::theme::{fixed, t, FONT};
use anti_webui::prelude::*;
use anti_webui::widgets::{styled_slider, SliderParts};

/// The box of a menu.
pub fn menu_panel(width: f32) -> Div {
    div()
        .w(width)
        .flex()
        .flex_col()
        .py(6.0_f32)
        .rounded(10.0_f32)
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
            s.bg(th.panel).border_color(th.border).text_color(th.fg)
        })
}

/// A small heading.
pub fn menu_title(s: &str) -> Div {
    fixed(11.0, s)
        .px(12.0_f32)
        .pt(6.0_f32)
        .pb(3.0_f32)
        .bold()
        .dyn_style(|st| st.text_color(t().muted))
}

/// A row that lights up under the pointer.
pub fn menu_row() -> Div {
    let hover = signal(false);
    div()
        .flex()
        .flex_row()
        .items_center()
        .gap(8.0_f32)
        .mx(4.0_f32)
        .px(8.0_f32)
        .h(28.0_f32)
        .rounded(6.0_f32)
        .on_hover(move |h| hover.set(h))
        .dyn_style(move |s| if hover.get() { s.bg(t().raised) } else { s })
}

pub fn separator() -> Div {
    div()
        .h(1.0_f32)
        .mx(10.0_f32)
        .my(5.0_f32)
        .dyn_style(|s| s.bg(t().border))
}

/// A thin slider in the theme's colors.
pub fn volume_slider(value: Binding<f32>) -> Div {
    styled_slider(
        value,
        0.0,
        1.0,
        SliderParts::new()
            .track(|d, _| {
                d.h(4.0_f32)
                    .rounded(2.0_f32)
                    .dyn_style(|s| s.bg(t().border))
            })
            .fill(|d, _| d.rounded(2.0_f32).dyn_style(|s| s.bg(t().fg)))
            .thumb(|d, _| {
                d.size(12.0_f32)
                    .rounded(6.0_f32)
                    .dyn_style(|s| s.bg(t().bright))
            }),
    )
    .h(16.0_f32)
}

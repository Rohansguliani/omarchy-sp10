//! The Settings window: a sidebar of pages, like macOS's System Settings.
//!
//! `omarchy-awui msg settings [wifi|bluetooth|sound|displays|devices|battery|about]` opens it on
//! a page, or brings it forward on that page when it is already open.

mod about;
mod battery;
mod bluetooth;
mod devices;
mod displays;
mod kit;
mod sound;
mod wifi;

use crate::theme::{fixed, t, FONT};
use anti_webui::prelude::*;
use std::cell::{Cell, RefCell};

pub const PAGES: [(&str, &str, &str); 7] = [
    ("wifi", "Wi-Fi", "󰖩"),
    ("bluetooth", "Bluetooth", "󰂯"),
    ("sound", "Sound", "󰕾"),
    ("displays", "Displays", "󰍹"),
    ("devices", "Devices", "󰍽"),
    ("battery", "Battery", "󰁹"),
    ("about", "About", "󰋼"),
];

pub fn page_id(name: &str) -> Option<&'static str> {
    PAGES.iter().find(|p| p.0 == name).map(|p| p.0)
}

thread_local! {
    static PAGE: Cell<Option<Signal<&'static str>>> = const { Cell::new(None) };
    static WINDOW: RefCell<Option<WindowHandle>> = const { RefCell::new(None) };
}

fn page_signal() -> Signal<&'static str> {
    PAGE.with(|p| {
        p.get().unwrap_or_else(|| {
            let (s, _) = create_root(|| signal("wifi"));
            p.set(Some(s));
            s
        })
    })
}

/// The page on view; reading it tracks. Pages scan (Wi-Fi, Bluetooth) only while on view.
pub fn current_page() -> &'static str {
    page_signal().get()
}

pub fn is_open() -> bool {
    WINDOW.with(|w| w.borrow().as_ref().is_some_and(|h| h.is_open()))
}

/// Opens the window on `page`, or brings it forward.
pub fn open(page: Option<&'static str>) {
    if let Some(p) = page {
        page_signal().set(p);
    }
    if is_open() {
        crate::sys::dispatch("hl.dsp.focus({ window = \"title:^Settings$\" })");
        return;
    }
    let handle = open_window(
        WindowOptions::new()
            .title("Settings")
            .size(980, 700)
            .top_level()
            .background(t().bg),
        view,
    );
    WINDOW.with(|w| *w.borrow_mut() = Some(handle));
}

pub fn close() {
    WINDOW.with(|w| {
        if let Some(h) = w.borrow_mut().take() {
            h.close();
        }
    });
}

fn view() -> Div {
    let page = page_signal();
    div()
        .size_full()
        .flex()
        .flex_row()
        .select_none()
        .font_family(FONT)
        .focusable()
        .on_key_down(|e| {
            if e.key == Key::Named(NamedKey::Escape) {
                close();
            }
        })
        .dyn_style(|s| {
            let th = t();
            s.bg(th.bg).text_color(th.fg)
        })
        .child(sidebar(page))
        .child(
            div()
                .flex_1()
                .min_w(0.0)
                .h_full()
                .child(dyn_view(move || match page.get() {
                    "wifi" => wifi::page(),
                    "bluetooth" => bluetooth::page(),
                    "sound" => sound::page(),
                    "displays" => displays::page(),
                    "devices" => devices::page(),
                    "battery" => battery::page(),
                    _ => about::page(),
                })),
        )
}

fn sidebar(page: Signal<&'static str>) -> Div {
    let mut list = div()
        .w(200.0_f32)
        .h_full()
        .flex()
        .flex_col()
        .gap(2.0_f32)
        .p(10.0_f32)
        .pt(18.0_f32)
        .border_r(1.0_f32)
        .dyn_style(|s| {
            let th = t();
            s.bg(th.panel).border_color(th.border)
        })
        .child(
            fixed(11.0, "Settings")
                .bold()
                .px(10.0_f32)
                .pb(8.0_f32)
                .dyn_style(|s| s.text_color(t().muted)),
        );
    for (id, name, glyph) in PAGES {
        let hover = signal(false);
        list = list.child(
            div()
                .flex()
                .flex_row()
                .items_center()
                .gap(10.0_f32)
                .h(32.0_f32)
                .px(10.0_f32)
                .rounded(7.0_f32)
                .on_hover(move |h| hover.set(h))
                .on_click(move |_| page.set(id))
                .dyn_style(move |s| {
                    let th = t();
                    if page.get() == id {
                        s.bg(th.raised).text_color(th.bright)
                    } else if hover.get() {
                        s.bg(th.raised.with_alpha(0.5))
                    } else {
                        s
                    }
                })
                .child(fixed(15.0, glyph).w(18.0_f32))
                .child(fixed(13.0, name)),
        );
    }
    list
}

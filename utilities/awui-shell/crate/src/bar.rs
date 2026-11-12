//! The bar along the bottom of every monitor: the windows of the desktop on the left, and the
//! sound, battery and clock on the right. It hides until the pointer touches the bottom edge, and
//! stays while one of its menus is open.

use crate::sys;
use crate::theme::{fixed, label, t, FONT};
use anti_webui::prelude::*;
use anti_webui::shell::hyprland::{self, Client};
use anti_webui::shell::prelude::*;
use std::cell::Cell;
use std::time::Duration;

/// How tall the bar is, in logical pixels.
pub const H: i32 = 26;
/// The strip along the bottom edge that reveals it.
const EDGE: i32 = 2;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Menu {
    Sound,
    Battery,
}

impl Menu {
    pub fn from_name(name: &str) -> Option<Self> {
        match name {
            "sound" => Some(Self::Sound),
            "battery" => Some(Self::Battery),
            _ => None,
        }
    }
}

thread_local! {
    static MENU: Cell<Option<Signal<Option<(String, Menu)>>>> = const { Cell::new(None) };
}

fn menu_state() -> Signal<Option<(String, Menu)>> {
    MENU.with(|m| {
        m.get().unwrap_or_else(|| {
            let (s, _) = create_root(|| signal(None));
            m.set(Some(s));
            s
        })
    })
}

/// Which menu is open, and on which monitor.
pub fn open_menu() -> Option<(String, Menu)> {
    menu_state().get()
}

fn is_open(monitor: &str, menu: Menu) -> bool {
    menu_state().with(|s| s.as_ref().is_some_and(|(m, x)| m == monitor && *x == menu))
}

pub fn toggle_menu(monitor: &str, menu: Menu) {
    let now = is_open(monitor, menu);
    menu_state().set((!now).then(|| (monitor.to_owned(), menu)));
}

pub fn close_menu() {
    menu_state().set(None);
}

pub fn open(output: Output) {
    let name = output.name.clone();
    let width = output.logical_size.width.max(1);
    let hovered = signal(false);
    // Hidden a moment after the pointer leaves, so it doesn't flicker at the edge.
    let shown = signal(false);
    let pending: Cell<Option<Timeout>> = Cell::new(None);
    let keep = memo({
        let name = name.clone();
        move || hovered.get() || menu_state().with(|s| s.as_ref().is_some_and(|(m, _)| *m == name))
    });
    effect(move || {
        if let Some(p) = pending.take() {
            p.cancel();
        }
        if keep.get() {
            shown.set(true);
        } else {
            pending.set(Some(set_timeout(Duration::from_millis(350), move || {
                if shown.is_alive() {
                    shown.set(false);
                }
            })));
        }
    });

    let view_name = name.clone();
    let layer = open_layer(
        LayerOptions::new()
            .layer(Layer::Top)
            .anchor(Anchor::BOTTOM | Anchor::LEFT | Anchor::RIGHT)
            .height(H)
            .exclusive(Exclusive::Ignore)
            .output(&output)
            .namespace("omarchy-awui-bar"),
        move || view(view_name.clone(), hovered, shown),
    );
    effect(move || {
        layer.set_input_region(if shown.get() {
            InputRegion::Full
        } else {
            InputRegion::Rects(vec![RectI {
                x: 0,
                y: H - EDGE,
                width,
                height: EDGE,
            }])
        });
    });
}

fn view(monitor: String, hovered: Signal<bool>, shown: Signal<bool>) -> Div {
    div()
        .select_none()
        .size_full()
        .on_hover(move |h| hovered.set(h))
        .child(
            div()
                .size_full()
                .flex()
                .flex_row()
                .items_center()
                .gap(4.0_f32)
                .px(6.0_f32)
                .font_family(FONT)
                .dyn_style(move |s| {
                    let th = t();
                    s.bg(th.bg)
                        .text_color(th.fg)
                        .opacity(if shown.get() { 1.0_f32 } else { 0.0 })
                })
                .child(taskbar(monitor.clone()))
                .child(sound_button(monitor.clone()))
                .child(battery_button(monitor))
                .child(clock()),
        )
}

/// A button of the bar: text that lights up under the pointer.
fn bar_button(content: Div, active: impl Fn() -> bool + 'static) -> Div {
    let hover = signal(false);
    content
        .h(H as f32 - 4.0)
        .px(7.0_f32)
        .rounded(5.0_f32)
        .flex()
        .flex_row()
        .items_center()
        .gap(6.0_f32)
        .flex_none()
        .on_hover(move |h| hover.set(h))
        .dyn_style(move |s| {
            let th = t();
            if hover.get() || active() {
                s.bg(th.raised)
            } else {
                s
            }
        })
}

// --- Windows ------------------------------------------------------------------------------

fn minimized(c: &Client) -> bool {
    c.workspace.name == "special:minimized"
}

/// The windows of the desktop the monitor shows, then the minimized ones, in a steady order.
fn windows_of(monitor: &str) -> Vec<Client> {
    let ws = hyprland::monitors()
        .into_iter()
        .find(|m| m.name == monitor)
        .map(|m| m.active_workspace.id);
    let mut list: Vec<Client> = hyprland::clients()
        .into_iter()
        .filter(|c| !c.address.is_empty() && (Some(c.workspace.id) == ws || minimized(c)))
        .collect();
    list.sort_by(|a, b| {
        minimized(a)
            .cmp(&minimized(b))
            .then(a.address.cmp(&b.address))
    });
    list
}

fn taskbar(monitor: String) -> Div {
    div()
        .flex()
        .flex_row()
        .items_center()
        .gap(3.0_f32)
        .flex_1()
        .min_w(0.0)
        .overflow_hidden()
        .child(for_each(
            move || windows_of(&monitor),
            |c: &Client| c.address.clone(),
            window_button,
        ))
}

fn window_button(c: Client) -> Div {
    let address = c.address.clone();
    let live = memo({
        let address = address.clone();
        move || {
            hyprland::clients()
                .into_iter()
                .find(|x| x.address == address)
        }
    });
    let active = memo({
        let address = address.clone();
        move || hyprland::active_window().is_some_and(|w| w.address == address)
    });
    let icon = sys::icon_for_class(&c.class);
    let click_address = address.clone();
    bar_button(
        div()
            .max_w(240.0_f32)
            .min_w(0.0)
            .flex_shrink(1.0_f32)
            .on_click(move |_| {
                let Some(c) = untrack(|| live.get()) else { return };
                let a = &click_address;
                if minimized(&c) {
                    let ws = hyprland::monitors()
                        .into_iter()
                        .find(|m| m.focused)
                        .map(|m| m.active_workspace.id)
                        .unwrap_or(1);
                    sys::dispatch(&format!(
                        "hl.dsp.window.move({{ window = \"address:{a}\", workspace = \"{ws}\", follow = false }})"
                    ));
                    sys::dispatch(&format!("hl.dsp.focus({{ window = \"address:{a}\" }})"));
                } else if untrack(|| active.get()) {
                    sys::spawn(&format!("omarchy-hyprland-window-minimize {a}"));
                } else {
                    sys::dispatch(&format!("hl.dsp.focus({{ window = \"address:{a}\" }})"));
                }
            })
            .dyn_style(move |s| {
                let gone = live.get().is_some_and(|c| minimized(&c));
                s.opacity(if gone { 0.45_f32 } else { 1.0 })
            })
            .child(match icon {
                Some(path) => img(path).object_fit(ObjectFit::Contain).size(14.0_f32).flex_none().into_view(),
                None => fixed(12.0, "󰣆").flex_none().into_view(),
            })
            .child(
                label(12.0, move || live.get().map(|c| c.title).unwrap_or_default())
                    .min_w(0.0)
                    .overflow_hidden(),
            ),
        move || active.get(),
    )
}

// --- Sound --------------------------------------------------------------------------------

pub fn volume_glyph() -> &'static str {
    let Some(sink) = audio().default_sink() else {
        return "󰝟";
    };
    if sink.muted || sink.volume <= 0.001 {
        "󰝟"
    } else if crate::sound::is_headphones(&sink.description, &sink.name) {
        "󰋋"
    } else if sink.volume < 0.34 {
        "󰕿"
    } else if sink.volume < 0.67 {
        "󰖀"
    } else {
        "󰕾"
    }
}

fn sound_button(monitor: String) -> Div {
    let anchor = node_ref();
    let m = monitor.clone();
    let m2 = monitor.clone();
    bar_button(
        div()
            .node_ref(anchor)
            .on_click(move |_| toggle_menu(&m, Menu::Sound))
            .on_scroll(move |e| {
                let up = e.delta_y < 0.0;
                sys::spawn(if up {
                    "omarchy-audio-output-volume +5"
                } else {
                    "omarchy-audio-output-volume -5"
                });
            })
            .child(label(13.0, || volume_glyph().to_owned()))
            .child(show(
                move || is_open(&m2, Menu::Sound),
                move || {
                    popup()
                        .anchor(anchor)
                        .placement(Placement::AboveEnd)
                        .gap(6)
                        .on_dismiss(close_menu)
                        .child(crate::sound::menu())
                },
            )),
        {
            let monitor = monitor.clone();
            move || is_open(&monitor, Menu::Sound)
        },
    )
}

// --- Battery ------------------------------------------------------------------------------

pub fn battery_glyph(percent: f64, charging: bool) -> &'static str {
    if charging {
        return "󰂄";
    }
    const LEVELS: [&str; 11] = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
    LEVELS[((percent / 10.0).round() as usize).min(10)]
}

fn battery_button(monitor: String) -> Div {
    // UPower answers after the bar is built, so this follows it.
    div().child(show(
        || battery().available(),
        move || battery_button_shown(monitor.clone()),
    ))
}

fn battery_button_shown(monitor: String) -> Div {
    let anchor = node_ref();
    let m = monitor.clone();
    let m2 = monitor.clone();
    bar_button(
        div()
            .node_ref(anchor)
            .on_click(move |_| toggle_menu(&m, Menu::Battery))
            .child(label(13.0, || {
                let b = battery();
                battery_glyph(b.percentage(), b.charging()).to_owned()
            }))
            .child(show(
                move || is_open(&m2, Menu::Battery),
                move || {
                    popup()
                        .anchor(anchor)
                        .placement(Placement::AboveEnd)
                        .gap(6)
                        .on_dismiss(close_menu)
                        .child(crate::battery::menu())
                },
            )),
        move || is_open(&monitor, Menu::Battery),
    )
}

// --- Clock --------------------------------------------------------------------------------

fn clock() -> Div {
    let long = signal(false);
    bar_button(
        div()
            .on_click(move |_| long.update(|l| *l = !*l))
            .child(label(12.0, move || {
                let n = local_time(Every::Minute);
                if long.get() {
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
                    format!(
                        "{} {} {} {}",
                        DAYS[n.weekday as usize % 7],
                        MONTHS[(n.month as usize + 11) % 12],
                        n.day,
                        n.year
                    )
                } else {
                    let h = match n.hour % 12 {
                        0 => 12,
                        h => h,
                    };
                    let ap = if n.hour < 12 { "AM" } else { "PM" };
                    format!("{}/{} {}:{:02} {}", n.month, n.day, h, n.minute, ap)
                }
            })),
        || false,
    )
}

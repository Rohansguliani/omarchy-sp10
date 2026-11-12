//! Displays: arrange them by dragging, and pick resolution, refresh rate, scale and rotation.
//!
//! Changes apply at once with `hl.monitor(...)`. Arranging saves right away; the others ask
//! "Keep these display settings?" and go back by themselves after 15 seconds. Saving goes
//! through `~/.local/lib/omarchy-awui/displays-save`, which rewrites only its own block of
//! `~/.config/hypr/monitors.lua`.

use super::kit::*;
use crate::theme::{fixed, label, t};
use anti_webui::prelude::*;
use anti_webui::shell::hyprland;
use anti_webui::shell::serde_json::{self, Value};
use std::time::Duration;

#[derive(Clone, Copy, Debug, PartialEq)]
struct Mode {
    w: i64,
    h: i64,
    rate: f64,
}

#[derive(Clone, Debug, PartialEq)]
struct Display {
    name: String,
    label: String,
    description: String,
    internal: bool,
    modes: Vec<Mode>,
    w: i64,
    h: i64,
    rate: f64,
    scale: f64,
    transform: i64,
    x: i64,
    y: i64,
    focused: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
struct Rect {
    x: f64,
    y: f64,
    w: f64,
    h: f64,
}

// --- Geometry (Hyprland layout pixels) -------------------------------------------------------

/// Two displays must share at least this much edge for the pointer to cross.
const MIN_TOUCH: f64 = 64.0;
/// Within this distance an edge or centre lines up with its neighbour's.
const ALIGN: f64 = 48.0;
const PRESETS: [f64; 11] = [1.0, 1.25, 4.0 / 3.0, 1.5, 1.6, 5.0 / 3.0, 1.75, 2.0, 2.25, 2.5, 3.0];

fn gcd(mut a: i64, mut b: i64) -> i64 {
    while b != 0 {
        let t = a % b;
        a = b;
        b = t;
    }
    a
}

/// The closest scale at or above `scale` that makes whole pixels both ways (Hyprland's rule).
fn clean_scale(scale: f64, w: i64, h: i64) -> f64 {
    let g = gcd(w * 120, h * 120);
    let mut k = ((scale * 120.0).round() as i64).max(1).min(g);
    while g % k != 0 {
        k += 1;
    }
    k as f64 / 120.0
}

/// Scales this mode supports exactly, with the size each makes it look like.
fn scale_options(w: i64, h: i64) -> Vec<(f64, i64, i64)> {
    let mut out: Vec<(f64, i64, i64)> = Vec::new();
    for p in PRESETS {
        let s = clean_scale(p, w, h);
        if (s - p).abs() > 0.02 || out.iter().any(|o| (o.0 - s).abs() < 1e-4) {
            continue;
        }
        let (lw, lh) = ((w as f64 / s).round() as i64, (h as f64 / s).round() as i64);
        if lw.min(lh) >= 600 {
            out.push((s, lw, lh));
        }
    }
    out
}

fn scale_text(s: f64) -> String {
    let t = format!("{s:.6}");
    t.trim_end_matches('0').trim_end_matches('.').to_owned()
}

fn logical(d: &Display) -> (f64, f64) {
    let (lw, lh) = ((d.w as f64 / d.scale).round(), (d.h as f64 / d.scale).round());
    if d.transform % 2 == 1 { (lh, lw) } else { (lw, lh) }
}

fn rect_of(d: &Display) -> Rect {
    let (w, h) = logical(d);
    Rect { x: d.x as f64, y: d.y as f64, w, h }
}

fn overlaps(a: &Rect, b: &Rect) -> bool {
    a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
}

fn align(v: f64, size: f64, start: f64, span: f64) -> f64 {
    for target in [start, start + span - size, start + (span - size) / 2.0] {
        if (v - target).abs() < ALIGN {
            return target;
        }
    }
    v
}

/// The position nearest to `r` where it touches one of `others` along an edge without overlap.
fn snap(r: Rect, others: &[Rect]) -> (f64, f64) {
    if others.is_empty() {
        return (0.0, 0.0);
    }
    let mut candidates = Vec::new();
    for o in others {
        let ty = MIN_TOUCH.min(r.h).min(o.h);
        let y = align(r.y, r.h, o.y, o.h).clamp(o.y - r.h + ty, o.y + o.h - ty);
        candidates.push((o.x + o.w, y));
        candidates.push((o.x - r.w, y));
        let tx = MIN_TOUCH.min(r.w).min(o.w);
        let x = align(r.x, r.w, o.x, o.w).clamp(o.x - r.w + tx, o.x + o.w - tx);
        candidates.push((x, o.y + o.h));
        candidates.push((x, o.y - r.h));
    }
    let best = candidates
        .into_iter()
        .filter(|&(x, y)| !others.iter().any(|o| overlaps(&Rect { x, y, ..r }, o)))
        .min_by(|a, b| {
            let da = (a.0 - r.x).powi(2) + (a.1 - r.y).powi(2);
            let db = (b.0 - r.x).powi(2) + (b.1 - r.y).powi(2);
            da.total_cmp(&db)
        });
    let (x, y) = best.unwrap_or_else(|| (others.iter().map(|o| o.x + o.w).fold(0.0, f64::max), others[0].y));
    (x.round(), y.round())
}

/// Moves the arrangement so its top-left is 0,0.
fn normalize(list: &mut [Display]) {
    let min_x = list.iter().map(|d| d.x).min().unwrap_or(0);
    let min_y = list.iter().map(|d| d.y).min().unwrap_or(0);
    for d in list {
        d.x -= min_x;
        d.y -= min_y;
    }
}

/// Every display touching: `anchor` stays put, the rest snap in by distance from it.
fn arrange(list: &mut [Display], anchor: &str) {
    let Some(first) = list.iter().position(|d| d.name == anchor).or(if list.is_empty() { None } else { Some(0) }) else {
        return;
    };
    let fr = rect_of(&list[first]);
    let (cx, cy) = (fr.x + fr.w / 2.0, fr.y + fr.h / 2.0);
    let mut order: Vec<usize> = (0..list.len()).filter(|&i| i != first).collect();
    order.sort_by(|&a, &b| {
        let (ra, rb) = (rect_of(&list[a]), rect_of(&list[b]));
        let da = (ra.x + ra.w / 2.0 - cx).powi(2) + (ra.y + ra.h / 2.0 - cy).powi(2);
        let db = (rb.x + rb.w / 2.0 - cx).powi(2) + (rb.y + rb.h / 2.0 - cy).powi(2);
        da.total_cmp(&db)
    });
    let mut placed = vec![fr];
    for i in order {
        let (x, y) = snap(rect_of(&list[i]), &placed);
        list[i].x = x as i64;
        list[i].y = y as i64;
        placed.push(rect_of(&list[i]));
    }
    normalize(list);
}

// --- Reading and applying -------------------------------------------------------------------

fn parse(v: &Value) -> Vec<Display> {
    let mut out = Vec::new();
    for m in v.as_array().cloned().unwrap_or_default() {
        let name = m["name"].as_str().unwrap_or("").to_owned();
        if name == "FALLBACK" || m["disabled"].as_bool() == Some(true) {
            continue;
        }
        let (w, h) = (m["width"].as_i64().unwrap_or(0), m["height"].as_i64().unwrap_or(0));
        let rate = (m["refreshRate"].as_f64().unwrap_or(60.0) * 100.0).round() / 100.0;
        let mut modes: Vec<Mode> = Vec::new();
        let mut all: Vec<String> = m["availableModes"]
            .as_array()
            .map(|a| a.iter().filter_map(|x| x.as_str().map(str::to_owned)).collect())
            .unwrap_or_default();
        all.push(format!("{w}x{h}@{rate}Hz"));
        for s in all {
            let Some((wh, r)) = s.trim_end_matches("Hz").split_once('@') else { continue };
            let Some((mw, mh)) = wh.split_once('x') else { continue };
            let (Ok(mw), Ok(mh), Ok(r)) = (mw.parse(), mh.parse(), r.parse::<f64>()) else { continue };
            let mode = Mode { w: mw, h: mh, rate: (r * 100.0).round() / 100.0 };
            if !modes.contains(&mode) {
                modes.push(mode);
            }
        }
        modes.sort_by(|a, b| (b.w * b.h).cmp(&(a.w * a.h)).then(b.rate.total_cmp(&a.rate)));
        let internal = ["eDP-", "LVDS-", "DSI-"].iter().any(|p| name.starts_with(p));
        let make = m["make"].as_str().unwrap_or("");
        let model = m["model"].as_str().unwrap_or("");
        let brand = make.split(' ').next().unwrap_or("");
        let short = if model.starts_with(brand) { model.to_owned() } else { format!("{brand} {model}") };
        out.push(Display {
            label: if internal { "Built-in Display".into() } else { short.trim().to_owned() },
            description: m["description"].as_str().unwrap_or("").to_owned(),
            internal,
            modes,
            w,
            h,
            rate,
            scale: m["scale"].as_f64().unwrap_or(1.0),
            transform: m["transform"].as_i64().unwrap_or(0),
            x: m["x"].as_i64().unwrap_or(0),
            y: m["y"].as_i64().unwrap_or(0),
            focused: m["focused"].as_bool().unwrap_or(false),
            name,
        });
    }
    out.sort_by(|a, b| a.x.cmp(&b.x).then(a.y.cmp(&b.y)));
    out
}

fn output_of(d: &Display) -> String {
    if d.internal || d.description.is_empty() { d.name.clone() } else { format!("desc:{}", d.description) }
}

fn lua_string(s: &str) -> String {
    format!("\"{}\"", s.replace('\\', "\\\\").replace('"', "\\\""))
}

fn mode_text(d: &Display) -> String {
    format!("{}x{}@{}", d.w, d.h, d.rate)
}

fn apply_live(list: &[Display]) {
    let rules: Vec<String> = list
        .iter()
        .map(|d| {
            format!(
                "hl.monitor({{ output = {}, mode = {}, position = \"{}x{}\", scale = {}, transform = {} }})",
                lua_string(&output_of(d)),
                lua_string(&mode_text(d)),
                d.x,
                d.y,
                scale_text(d.scale),
                d.transform
            )
        })
        .collect();
    let _ = hyprland::request(&format!("eval {}", rules.join("; ")));
}

fn save(list: &[Display]) {
    let rules: Vec<Value> = list
        .iter()
        .map(|d| {
            serde_json::json!({
                "output": output_of(d),
                "mode": mode_text(d),
                "position": format!("{}x{}", d.x, d.y),
                "scale": scale_text(d.scale),
                "transform": d.transform,
            })
        })
        .collect();
    let helper = format!("{}/.local/lib/omarchy-awui/displays-save", std::env::var("HOME").unwrap_or_default());
    run_output(vec![helper, Value::Array(rules).to_string()]);
}

// --- The page --------------------------------------------------------------------------------

#[derive(Clone, Copy)]
struct State {
    displays: Signal<Vec<Display>>,
    selected: Signal<String>,
    revert_to: Signal<Option<Vec<Display>>>,
    countdown: Signal<i32>,
}

impl State {
    fn reload(self) {
        hyprland::request_json("monitors all").then(move |r| {
            if let Ok(v) = r {
                let list = parse(&v);
                if !list.iter().any(|d| d.name == untrack(|| self.selected.get())) {
                    let pick = list.iter().find(|d| d.focused).or(list.first()).map(|d| d.name.clone());
                    self.selected.set(pick.unwrap_or_default());
                }
                self.displays.set(list);
            }
        });
    }

    /// A change that asks before it is kept: applied now, the arrangement kept touching.
    fn change(self, name: &str, f: impl FnOnce(&mut Display)) {
        let before = untrack(|| self.displays.get());
        let mut list = before.clone();
        let Some(i) = list.iter().position(|d| d.name == name) else { return };
        let (w0, h0) = (list[i].w, list[i].h);
        f(&mut list[i]);
        if (list[i].w, list[i].h) != (w0, h0) {
            list[i].scale = clean_scale(list[i].scale, list[i].w, list[i].h);
        }
        // The largest other display stays put; this one snaps back beside it.
        let anchor = list
            .iter()
            .filter(|d| d.name != name)
            .max_by_key(|d| d.w * d.h)
            .map(|d| d.name.clone())
            .unwrap_or_else(|| name.to_owned());
        arrange(&mut list, &anchor);
        apply_live(&list);
        self.displays.set(list);
        if untrack(|| self.revert_to.get()).is_none() {
            self.revert_to.set(Some(before));
        }
        self.countdown.set(15);
        self.tick();
    }

    fn tick(self) {
        set_timeout(Duration::from_secs(1), move || {
            if !self.countdown.is_alive() || untrack(|| self.revert_to.get()).is_none() {
                return;
            }
            let left = untrack(|| self.countdown.get()) - 1;
            if left <= 0 {
                self.revert();
            } else {
                self.countdown.set(left);
                self.tick();
            }
        });
    }

    fn keep(self) {
        self.revert_to.set(None);
        save(&untrack(|| self.displays.get()));
    }

    fn revert(self) {
        if let Some(before) = untrack(|| self.revert_to.get()) {
            apply_live(&before);
            self.displays.set(before);
            self.revert_to.set(None);
        }
    }

    fn move_display(self, name: &str, x: f64, y: f64) {
        let mut list = untrack(|| self.displays.get());
        let Some(i) = list.iter().position(|d| d.name == name) else { return };
        let (w, h) = logical(&list[i]);
        let others: Vec<Rect> = list.iter().filter(|d| d.name != name).map(rect_of).collect();
        let (sx, sy) = snap(Rect { x, y, w, h }, &others);
        list[i].x = sx as i64;
        list[i].y = sy as i64;
        normalize(&mut list);
        apply_live(&list);
        save(&list);
        self.displays.set(list);
    }
}

pub fn page() -> Div {
    let s = State {
        displays: signal(Vec::new()),
        selected: signal(String::new()),
        revert_to: signal(None),
        countdown: signal(15),
    };
    s.reload();
    // Leaving the page with a change not kept puts it back.
    on_cleanup(move || {
        if let Some(before) = untrack(|| s.revert_to.get()) {
            apply_live(&before);
            save(&before);
        }
    });

    sheet("Displays")
        .child(show(
            move || s.revert_to.get().is_some(),
            move || {
                group().child(
                    row()
                        .child(label(13.0, move || format!("Keep these display settings? Reverting in {} s", s.countdown.get())).flex_1())
                        .child(btn("Revert", false, move || s.revert()))
                        .child(btn("Keep", true, move || s.keep())),
                )
            },
        ))
        .child(arrangement(s))
        .child(fixed(11.0, "Drag displays to arrange them. Click one to change its settings.").dyn_style(|st| st.text_color(t().muted)))
        .child(dyn_view(move || {
            let name = s.selected.get();
            match untrack(|| s.displays.get()).into_iter().find(|d| d.name == name) {
                Some(d) => details(s, d.name).into_view(),
                None => div().into_view(),
            }
        }))
}

const CANVAS_H: f32 = 240.0;

fn arrangement(s: State) -> Div {
    // While dragging: which display, and where (layout pixels) its top-left would go.
    let drag = signal(None::<(String, f64, f64, f32, f32)>);
    let canvas_w = signal(600.0_f32);
    // Layout pixels to canvas pixels: everything fits with room around.
    let fit = memo(move || {
        let list = s.displays.get();
        let max_x = list.iter().map(|d| d.x as f64 + logical(d).0).fold(1.0, f64::max);
        let max_y = list.iter().map(|d| d.y as f64 + logical(d).1).fold(1.0, f64::max);
        let k = ((canvas_w.get() as f64 * 0.6) / max_x).min((CANVAS_H as f64 * 0.65) / max_y);
        let ox = (canvas_w.get() as f64 - max_x * k) / 2.0;
        let oy = (CANVAS_H as f64 - max_y * k) / 2.0;
        (k, ox, oy)
    });
    group()
        .h(CANVAS_H)
        .relative()
        .on_resized(move |w, _| canvas_w.set(w))
        .on_pointer_move(move |e| {
            if let Some((name, _, _, gx, gy)) = untrack(|| drag.get()) {
                let (k, ox, oy) = untrack(|| fit.get());
                let x = (e.local.x - gx) as f64;
                let y = (e.local.y - gy) as f64;
                drag.set(Some((name, (x - ox) / k, (y - oy) / k, gx, gy)));
            }
        })
        .on_pointer_up(move |_| {
            if let Some((name, x, y, _, _)) = untrack(|| drag.get()) {
                drag.set(None);
                s.move_display(&name, x, y);
            }
        })
        .child(for_each(
            move || s.displays.get().into_iter().map(|d| d.name).collect::<Vec<_>>(),
            |n: &String| n.clone(),
            move |name: String| {
                let d = memo({
                    let name = name.clone();
                    move || s.displays.get().into_iter().find(|d| d.name == name)
                });
                let n2 = name.clone();
                let n3 = name.clone();
                div()
                    .absolute()
                    .flex()
                    .flex_col()
                    .items_center()
                    .justify_center()
                    .rounded(6.0_f32)
                    .border(2.0_f32)
                    .overflow_hidden()
                    .on_pointer_down(move |e| {
                        s.selected.set(n2.clone());
                        if untrack(|| s.revert_to.get()).is_none()
                            && let Some(d) = untrack(|| d.get())
                        {
                            drag.set(Some((n2.clone(), d.x as f64, d.y as f64, e.local.x, e.local.y)));
                        }
                    })
                    .dyn_style(move |st| {
                        let th = t();
                        let Some(d) = d.get() else { return st };
                        let (k, ox, oy) = fit.get();
                        let (w, h) = logical(&d);
                        let (x, y) = match drag.get() {
                            Some((n, x, y, _, _)) if n == n3 => (x, y),
                            _ => (d.x as f64, d.y as f64),
                        };
                        let on = s.selected.get() == d.name;
                        st.left((ox + x * k) as f32)
                            .top((oy + y * k) as f32)
                            .w((w * k) as f32)
                            .h((h * k) as f32)
                            .bg(if on { th.raised } else { th.panel })
                            .border_color(if on { th.fg } else { th.border })
                    })
                    .child(label(12.0, move || d.get().map(|d| d.label).unwrap_or_default()).bold())
                    .child(
                        label(10.0, move || {
                            d.get()
                                .map(|d| {
                                    let (lw, lh) = logical(&d);
                                    if (d.scale - 1.0).abs() < 1e-3 {
                                        format!("{} × {}", d.w, d.h)
                                    } else {
                                        format!("{} × {}\nlooks like {} × {}", d.w, d.h, lw, lh)
                                    }
                                })
                                .unwrap_or_default()
                        })
                        .text_align(TextAlign::Center)
                        .dyn_style(|st| st.text_color(t().soft)),
                    )
            },
        ))
}

/// A row of choices; the one chosen lit.
fn chips<T: Clone + 'static>(items: Vec<(T, String, bool)>, pick: impl Fn(T) + Clone + 'static) -> Div {
    let mut d = div().flex().flex_row().flex_wrap().gap(6.0_f32).flex_1();
    for (v, text, on) in items {
        let pick = pick.clone();
        let hover = signal(false);
        d = d.child(
            fixed(12.0, text)
                .px(10.0_f32)
                .h(26.0_f32)
                .flex()
                .items_center()
                .rounded(6.0_f32)
                .border(1.0_f32)
                .on_hover(move |h| hover.set(h))
                .on_click(move |_| pick(v.clone()))
                .dyn_style(move |s| {
                    let th = t();
                    if on {
                        s.bg(th.fg).text_color(th.bg).border_color(th.fg)
                    } else {
                        s.bg(if hover.get() { th.raised } else { th.panel }).border_color(th.border)
                    }
                }),
        );
    }
    d
}

fn details(s: State, name: String) -> Div {
    let n = name.clone();
    div().flex().flex_col().gap(14.0_f32).child(dyn_view(move || {
        let Some(d) = s.displays.get().into_iter().find(|d| d.name == n) else { return div().into_view() };
        let mut resolutions: Vec<(i64, i64)> = Vec::new();
        for m in &d.modes {
            if !resolutions.contains(&(m.w, m.h)) {
                resolutions.push((m.w, m.h));
            }
        }
        let rates: Vec<f64> = d.modes.iter().filter(|m| m.w == d.w && m.h == d.h).map(|m| m.rate).collect();
        let name_r = d.name.clone();
        let name_f = d.name.clone();
        let name_s = d.name.clone();
        let name_t = d.name.clone();
        let modes = d.modes.clone();
        let current_rate = d.rate;
        let scales = scale_options(d.w, d.h);
        let looks = scales
            .iter()
            .find(|o| (o.0 - d.scale).abs() < 1e-3)
            .map(|o| format!("Looks like {} × {}", o.1, o.2))
            .unwrap_or_default();
        let sub = format!("{} · {}", if d.description.is_empty() { &d.name } else { &d.description }, d.name);
        div()
            .flex()
            .flex_col()
            .gap(14.0_f32)
            .child(section(&d.label))
            .child(fixed(11.0, sub).dyn_style(|st| st.text_color(t().muted)))
            .child(
                group()
                    .child(
                        row().child(fixed(13.0, "Resolution").w(110.0_f32)).child(chips(
                            resolutions
                                .iter()
                                .enumerate()
                                .map(|(i, &(w, h))| {
                                    ((w, h), format!("{w} × {h}{}", if i == 0 { " (native)" } else { "" }), (w, h) == (d.w, d.h))
                                })
                                .collect(),
                            move |(w, h): (i64, i64)| {
                                let best = modes
                                    .iter()
                                    .filter(|m| m.w == w && m.h == h)
                                    .find(|m| m.rate == current_rate)
                                    .or_else(|| modes.iter().find(|m| m.w == w && m.h == h))
                                    .copied();
                                if let Some(m) = best {
                                    s.change(&name_r, |x| {
                                        x.w = m.w;
                                        x.h = m.h;
                                        x.rate = m.rate;
                                    });
                                }
                            },
                        )),
                    )
                    .child(
                        row().child(fixed(13.0, "Refresh rate").w(110.0_f32)).child(chips(
                            rates.iter().map(|&r| (r, format!("{} Hz", r), (r - d.rate).abs() < 1e-3)).collect(),
                            move |r: f64| s.change(&name_f, |x| x.rate = r),
                        )),
                    )
                    .child(
                        row()
                            .child(fixed(13.0, "Scale").w(110.0_f32))
                            .child(
                                div()
                                    .flex()
                                    .flex_col()
                                    .gap(4.0_f32)
                                    .flex_1()
                                    .child(chips(
                                        scales
                                            .iter()
                                            .map(|o| (o.0, format!("{}×", scale_text((o.0 * 100.0).round() / 100.0)), (o.0 - d.scale).abs() < 1e-3))
                                            .collect(),
                                        move |sc: f64| s.change(&name_s, |x| x.scale = sc),
                                    ))
                                    .child(fixed(11.0, looks).dyn_style(|st| st.text_color(t().muted))),
                            ),
                    )
                    .child(
                        row().child(fixed(13.0, "Rotation").w(110.0_f32)).child(chips(
                            [(0, "Standard"), (1, "90°"), (2, "180°"), (3, "270°")]
                                .into_iter()
                                .map(|(v, l)| (v, l.to_owned(), d.transform == v))
                                .collect(),
                            move |v: i64| s.change(&name_t, |x| x.transform = v),
                        )),
                    ),
            )
            .into_view()
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn scales_are_whole_pixels() {
        let opts = scale_options(3840, 2160);
        assert!(opts.iter().any(|o| (o.0 - 1.5).abs() < 1e-9 && o.1 == 2560 && o.2 == 1440));
        for (s, lw, lh) in opts {
            assert_eq!((3840.0 / s).fract(), 0.0, "{s}");
            assert_eq!(lw, (3840.0 / s) as i64);
            assert_eq!(lh, (2160.0 / s) as i64);
        }
    }

    #[test]
    fn snap_touches_without_overlap() {
        let big = Rect { x: 0.0, y: 0.0, w: 2560.0, h: 1440.0 };
        let (x, y) = snap(Rect { x: 1000.0, y: 1500.0, w: 1440.0, h: 960.0 }, &[big]);
        assert_eq!(y, 1440.0);
        assert!(x > -1440.0 && x < 2560.0);
        let (x, _) = snap(Rect { x: 2400.0, y: 200.0, w: 1440.0, h: 960.0 }, &[big]);
        assert_eq!(x, 2560.0);
    }
}

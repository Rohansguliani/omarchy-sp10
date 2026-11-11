.pragma library

// Display geometry for the Displays page: valid scales, logical sizes, and
// macOS-style arrangement (displays always touch along an edge).
// All rectangles are in Hyprland layout (logical) pixels: { x, y, w, h }.

// Two displays must share at least this much edge for the pointer to cross.
var MIN_TOUCH = 64
// Within this distance an edge or centre lines up with its neighbour's.
var ALIGN = 48

function gcd(a, b) {
  while (b) { var t = a % b; a = b; b = t }
  return a
}

// The closest scale at or above `scale` for which both w/scale and h/scale
// are whole pixels: Hyprland's rule, as omarchy-hyprland-monitor-scaling does.
function cleanScale(scale, w, h) {
  var g = gcd(Math.round(w * 120), Math.round(h * 120))
  var k = Math.max(1, Math.round(scale * 120))
  if (k > g) k = g
  while (g % k !== 0) k++
  return k / 120
}

var PRESETS = [1, 1.25, 4 / 3, 1.5, 1.6, 5 / 3, 1.75, 2, 2.25, 2.5, 3]

// Scales this mode supports exactly, with the size each makes it look like.
function scaleOptions(w, h) {
  var out = []
  var seen = ({})
  for (var i = 0; i < PRESETS.length; i++) {
    var s = cleanScale(PRESETS[i], w, h)
    if (Math.abs(s - PRESETS[i]) > 0.02) continue
    var key = s.toFixed(4)
    if (seen[key]) continue
    seen[key] = true
    var lw = Math.round(w / s), lh = Math.round(h / s)
    if (Math.min(lw, lh) < 600) continue
    out.push({ scale: s, lw: lw, lh: lh })
  }
  return out
}

// Scale as Hyprland config text: 1.5, 2, 1.333333.
function scaleText(s) {
  return String(Number(s.toFixed(6)))
}

// Logical size of a display setting { w, h, scale, transform }.
function logical(d) {
  var lw = Math.round(d.w / d.scale), lh = Math.round(d.h / d.scale)
  return d.transform % 2 === 1 ? { w: lh, h: lw } : { w: lw, h: lh }
}

function overlaps(a, b) {
  return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
}

function clamp(v, lo, hi) {
  return Math.max(lo, Math.min(hi, v))
}

// Line `v` (start of a span of `size`) up with a neighbour's start, end or
// centre when it is within ALIGN.
function align(v, size, start, span) {
  var targets = [start, start + span - size, start + (span - size) / 2]
  for (var i = 0; i < targets.length; i++)
    if (Math.abs(v - targets[i]) < ALIGN) return targets[i]
  return v
}

// The position nearest to r's where it touches one of `others` along an edge
// without overlapping any of them.
function snap(r, others) {
  if (others.length === 0) return { x: 0, y: 0 }
  var candidates = []
  for (var i = 0; i < others.length; i++) {
    var o = others[i]
    var ty = Math.min(MIN_TOUCH, r.h, o.h)
    var y = clamp(align(r.y, r.h, o.y, o.h), o.y - r.h + ty, o.y + o.h - ty)
    candidates.push({ x: o.x + o.w, y: y }, { x: o.x - r.w, y: y })
    var tx = Math.min(MIN_TOUCH, r.w, o.w)
    var x = clamp(align(r.x, r.w, o.x, o.w), o.x - r.w + tx, o.x + o.w - tx)
    candidates.push({ x: x, y: o.y + o.h }, { x: x, y: o.y - r.h })
  }
  var best = null
  for (var c = 0; c < candidates.length; c++) {
    var p = candidates[c]
    var moved = { x: p.x, y: p.y, w: r.w, h: r.h }
    var free = true
    for (var j = 0; j < others.length; j++) if (overlaps(moved, others[j])) { free = false; break }
    if (!free) continue
    var d = (p.x - r.x) * (p.x - r.x) + (p.y - r.y) * (p.y - r.y)
    if (!best || d < best.d) best = { x: p.x, y: p.y, d: d }
  }
  if (!best) {
    // Boxed in: go right of everything.
    var right = 0
    for (var k = 0; k < others.length; k++) right = Math.max(right, others[k].x + others[k].w)
    best = { x: right, y: others[0].y }
  }
  return { x: Math.round(best.x), y: Math.round(best.y) }
}

// Lay out `rects` (each { name, x, y, w, h }) so every display touches the
// arrangement: `anchor` stays put, the rest snap in order of distance from it,
// keeping their side. Then the top-left corner moves to 0,0. Returns new
// objects; the input is not changed.
function arrange(rects, anchor) {
  var list = rects.map(function(r) { return { name: r.name, x: r.x, y: r.y, w: r.w, h: r.h } })
  if (list.length === 0) return list
  var first = list.filter(function(r) { return r.name === anchor })[0] || list[0]
  var cx = first.x + first.w / 2, cy = first.y + first.h / 2
  var rest = list.filter(function(r) { return r !== first })
  rest.sort(function(a, b) {
    var da = Math.pow(a.x + a.w / 2 - cx, 2) + Math.pow(a.y + a.h / 2 - cy, 2)
    var db = Math.pow(b.x + b.w / 2 - cx, 2) + Math.pow(b.y + b.h / 2 - cy, 2)
    return da - db
  })
  var placed = [first]
  for (var i = 0; i < rest.length; i++) {
    var p = snap(rest[i], placed)
    rest[i].x = p.x
    rest[i].y = p.y
    placed.push(rest[i])
  }
  var minX = Infinity, minY = Infinity
  for (var j = 0; j < list.length; j++) { minX = Math.min(minX, list[j].x); minY = Math.min(minY, list[j].y) }
  for (var k = 0; k < list.length; k++) { list[k].x -= minX; list[k].y -= minY }
  return list
}

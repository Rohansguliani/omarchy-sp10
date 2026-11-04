// Pure tile-seam geometry for the rohansguliani.seams plugin.
//
// No Qt/Quickshell dependencies: this file runs both inside QML
// (import "SeamLogic.js" as SeamLogic) and under plain node for tests.
//
// Tiles are plain { address, x, y, w, h } rects in one shared coordinate
// space (screen-local logical pixels). A seam is
//   { axis, pos, start, end, first, second }
// where axis "x" is a vertical line at x=pos spanning y in [start,end] and
// dragging it +dx grows `first` (the left window); axis "y" is a horizontal
// line at y=pos spanning x in [start,end] and +dy grows `first` (top window).
//
// MIN_HANDLE is the shortest segment (px) worth a grab target. Kept in one
// place so the QML overlay and the geometry agree.
var MIN_HANDLE = 96

function overlap(a0, a1, b0, b1) {
  var start = Math.max(a0, b0)
  var end = Math.min(a1, b1)
  return end > start ? { start: start, end: end, length: end - start } : null
}

function findSeams(tiles, opts) {
  var tolerance = (opts && opts.tolerance !== undefined) ? opts.tolerance : 1
  var minOverlap = (opts && opts.minOverlap !== undefined) ? opts.minOverlap : MIN_HANDLE
  var seams = []
  var seen = {}

  function consider(seam) {
    if (seam.end - seam.start < minOverlap) return
    var key = seam.axis + "|" + Math.round(seam.pos) + "|" + Math.round(seam.start)
      + "|" + Math.round(seam.end) + "|" + seam.first + "|" + seam.second
    if (seen[key]) return
    seen[key] = true
    seams.push(seam)
  }

  for (var i = 0; i < tiles.length; i++) {
    for (var j = 0; j < tiles.length; j++) {
      if (i === j) continue
      var a = tiles[i], b = tiles[j]
      if (!a || !b) continue

      // a left of b: a's right edge meets b's left edge -> vertical seam.
      // first=a grows rightward when dragged +dx (verified: dwindle moves
      // the shared split 1:1 for the adjacent pair).
      if (Math.abs((a.x + a.w) - b.x) <= tolerance) {
        var v = overlap(a.y, a.y + a.h, b.y, b.y + b.h)
        if (v) {
          consider({
            axis: "x",
            pos: ((a.x + a.w) + b.x) / 2,
            start: v.start, end: v.end,
            first: a.address, second: b.address
          })
        }
      }

      // a above b: a's bottom edge meets b's top edge -> horizontal seam.
      if (Math.abs((a.y + a.h) - b.y) <= tolerance) {
        var h = overlap(a.x, a.x + a.w, b.x, b.x + b.w)
        if (h) {
          consider({
            axis: "y",
            pos: ((a.y + a.h) + b.y) / 2,
            start: h.start, end: h.end,
            first: a.address, second: b.address
          })
        }
      }
    }
  }

  // Stable slot assignment: identical input must yield identical order so
  // overlay handles don't flicker between slots on recompute.
  seams.sort(function (l, r) {
    if (l.axis !== r.axis) return l.axis < r.axis ? -1 : 1
    if (l.pos !== r.pos) return l.pos - r.pos
    return l.start - r.start
  })
  return seams
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { findSeams: findSeams, overlap: overlap }
}

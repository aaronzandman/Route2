/* Minimal QR code generator (byte mode, error correction L or M, versions 1-40).
   Written for Route2 so the online planner needs no third-party code.
   Usage: const q = RouteQR.make("https://...", "M"); q.size; q.get(x, y) -> true for dark.
          RouteQR.draw(canvas, q, pixelsPerModule) */
(function (root) {
  "use strict";
  var ECC = {
    L: [-1, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
    M: [-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28]
  };
  var BLOCKS = {
    L: [-1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25],
    M: [-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49]
  };
  var FORMAT = { L: 1, M: 0 };

  function rawModules(ver) {
    var r = (16 * ver + 128) * ver + 64;
    if (ver >= 2) { var n = Math.floor(ver / 7) + 2; r -= (25 * n - 10) * n - 55; if (ver >= 7) r -= 36; }
    return r;
  }
  function dataCodewords(ver, ecl) { return Math.floor(rawModules(ver) / 8) - ECC[ecl][ver] * BLOCKS[ecl][ver]; }

  function gfMul(x, y) {
    var z = 0;
    for (var i = 7; i >= 0; i--) { z = (z << 1) ^ ((z >>> 7) * 0x11D); z ^= ((y >>> i) & 1) * x; }
    return z & 0xFF;
  }
  function rsDivisor(degree) {
    var r = []; for (var i = 0; i < degree - 1; i++) r.push(0); r.push(1);
    var root = 1;
    for (i = 0; i < degree; i++) {
      for (var j = 0; j < r.length; j++) { r[j] = gfMul(r[j], root); if (j + 1 < r.length) r[j] ^= r[j + 1]; }
      root = gfMul(root, 0x02);
    }
    return r;
  }
  function rsRemainder(data, div) {
    var r = div.map(function () { return 0; });
    data.forEach(function (b) {
      var f = b ^ r.shift(); r.push(0);
      div.forEach(function (c, i) { r[i] ^= gfMul(c, f); });
    });
    return r;
  }
  function utf8(s) {
    var out = [], e = unescape(encodeURIComponent(s));
    for (var i = 0; i < e.length; i++) out.push(e.charCodeAt(i));
    return out;
  }

  function make(text, ecl, forceMask) {
    ecl = ecl === "L" ? "L" : "M";
    var bytes = utf8(text), ver;
    for (ver = 1; ver <= 40; ver++) {
      var cc = ver < 10 ? 8 : 16;
      if (4 + cc + bytes.length * 8 <= dataCodewords(ver, ecl) * 8) break;
    }
    if (ver > 40) throw new Error("Too much data for one QR code");
    var cap = dataCodewords(ver, ecl) * 8, bits = [];
    function put(v, n) { for (var i = n - 1; i >= 0; i--) bits.push((v >>> i) & 1); }
    put(4, 4); put(bytes.length, ver < 10 ? 8 : 16);
    bytes.forEach(function (b) { put(b, 8); });
    put(0, Math.min(4, cap - bits.length));
    put(0, (8 - bits.length % 8) % 8);
    for (var pad = 0xEC; bits.length < cap; pad ^= 0xEC ^ 0x11) put(pad, 8);
    var data = [];
    for (var i = 0; i < bits.length; i += 8) { var v = 0; for (var k = 0; k < 8; k++) v = (v << 1) | bits[i + k]; data.push(v); }

    // error correction + interleave
    var nb = BLOCKS[ecl][ver], el = ECC[ecl][ver], raw = Math.floor(rawModules(ver) / 8);
    var nShort = nb - raw % nb, shortLen = Math.floor(raw / nb), div = rsDivisor(el), blocks = [], p = 0;
    for (i = 0; i < nb; i++) {
      var dat = data.slice(p, p + shortLen - el + (i < nShort ? 0 : 1)); p += dat.length;
      var ecc = rsRemainder(dat, div);
      if (i < nShort) dat.push(0);
      blocks.push(dat.concat(ecc));
    }
    var cw = [];
    for (i = 0; i < blocks[0].length; i++)
      for (var j = 0; j < blocks.length; j++)
        if (i !== shortLen - el || j >= nShort) cw.push(blocks[j][i]);

    // matrix
    var size = ver * 4 + 17, mod = [], fn = [];
    for (i = 0; i < size; i++) { mod.push(new Array(size).fill(false)); fn.push(new Array(size).fill(false)); }
    function setF(x, y, d) { mod[y][x] = d; fn[y][x] = true; }
    for (i = 0; i < size; i++) { setF(6, i, i % 2 === 0); setF(i, 6, i % 2 === 0); }
    function finder(cx, cy) {
      for (var dy = -4; dy <= 4; dy++) for (var dx = -4; dx <= 4; dx++) {
        var d = Math.max(Math.abs(dx), Math.abs(dy)), x = cx + dx, y = cy + dy;
        if (x >= 0 && x < size && y >= 0 && y < size) setF(x, y, d !== 2 && d !== 4);
      }
    }
    finder(3, 3); finder(size - 4, 3); finder(3, size - 4);
    if (ver > 1) {
      var na = Math.floor(ver / 7) + 2, step = ver === 32 ? 26 : Math.ceil((ver * 4 + 4) / (na * 2 - 2)) * 2, pos = [6];
      for (var q = size - 7; pos.length < na; q -= step) pos.splice(1, 0, q);
      for (i = 0; i < na; i++) for (j = 0; j < na; j++) {
        if ((i === 0 && j === 0) || (i === 0 && j === na - 1) || (i === na - 1 && j === 0)) continue;
        for (var ay = -2; ay <= 2; ay++) for (var ax = -2; ax <= 2; ax++)
          setF(pos[i] + ax, pos[j] + ay, Math.max(Math.abs(ax), Math.abs(ay)) !== 1);
      }
    }
    function drawFormat(mask) {
      var d = FORMAT[ecl] << 3 | mask, r = d;
      for (var k = 0; k < 10; k++) r = (r << 1) ^ ((r >>> 9) * 0x537);
      var b = ((d << 10) | r) ^ 0x5412, bit = function (n) { return ((b >>> n) & 1) !== 0; };
      for (k = 0; k <= 5; k++) setF(8, k, bit(k));
      setF(8, 7, bit(6)); setF(8, 8, bit(7)); setF(7, 8, bit(8));
      for (k = 9; k < 15; k++) setF(14 - k, 8, bit(k));
      for (k = 0; k < 8; k++) setF(size - 1 - k, 8, bit(k));
      for (k = 8; k < 15; k++) setF(8, size - 15 + k, bit(k));
      setF(8, size - 8, true);
    }
    drawFormat(0);
    if (ver >= 7) {
      var r = ver;
      for (i = 0; i < 12; i++) r = (r << 1) ^ ((r >>> 11) * 0x1F25);
      var vb = ver << 12 | r;
      for (i = 0; i < 18; i++) {
        var bt = ((vb >>> i) & 1) !== 0, a = size - 11 + i % 3, c = Math.floor(i / 3);
        setF(a, c, bt); setF(c, a, bt);
      }
    }
    // data placement
    var bi = 0;
    for (var right = size - 1; right >= 1; right -= 2) {
      if (right === 6) right = 5;
      for (var vert = 0; vert < size; vert++) for (j = 0; j < 2; j++) {
        var x = right - j, up = ((right + 1) & 2) === 0, y = up ? size - 1 - vert : vert;
        if (!fn[y][x] && bi < cw.length * 8) { mod[y][x] = ((cw[bi >>> 3] >>> (7 - (bi & 7))) & 1) !== 0; bi++; }
      }
    }
    // pick the mask with the lowest (simplified) penalty
    function maskFn(m, x, y) {
      switch (m) {
        case 0: return (x + y) % 2 === 0; case 1: return y % 2 === 0; case 2: return x % 3 === 0;
        case 3: return (x + y) % 3 === 0; case 4: return (Math.floor(x / 3) + Math.floor(y / 2)) % 2 === 0;
        case 5: return x * y % 2 + x * y % 3 === 0; case 6: return (x * y % 2 + x * y % 3) % 2 === 0;
        default: return ((x + y) % 2 + x * y % 3) % 2 === 0;
      }
    }
    function applyMask(m) { for (var y = 0; y < size; y++) for (var x = 0; x < size; x++) if (!fn[y][x] && maskFn(m, x, y)) mod[y][x] = !mod[y][x]; }
    function penalty() {
      var s = 0, dark = 0, x, y, run, prev;
      for (y = 0; y < size; y++) { run = 0; prev = null; for (x = 0; x < size; x++) { var c = mod[y][x]; if (c) dark++; if (c === prev) { run++; if (run === 5) s += 3; else if (run > 5) s++; } else { prev = c; run = 1; } } }
      for (x = 0; x < size; x++) { run = 0; prev = null; for (y = 0; y < size; y++) { c = mod[y][x]; if (c === prev) { run++; if (run === 5) s += 3; else if (run > 5) s++; } else { prev = c; run = 1; } } }
      for (y = 0; y < size - 1; y++) for (x = 0; x < size - 1; x++) { c = mod[y][x]; if (c === mod[y][x + 1] && c === mod[y + 1][x] && c === mod[y + 1][x + 1]) s += 3; }
      // finder-like patterns (1:1:3:1:1 with 4 light modules on either side) confuse scanners
      var P1 = [1,0,1,1,1,0,1,0,0,0,0], P2 = [0,0,0,0,1,0,1,1,1,0,1];
      function at(x, y) { return (x < 0 || y < 0 || x >= size || y >= size) ? 0 : (mod[y][x] ? 1 : 0); }
      for (y = -1; y <= size; y++) for (x = -11; x <= size; x++) {
        var h1 = true, h2 = true, v1 = true, v2 = true;
        for (var k = 0; k < 11; k++) {
          var a1 = at(x + k, y), b1 = at(y, x + k);
          if (a1 !== P1[k]) h1 = false; if (a1 !== P2[k]) h2 = false;
          if (b1 !== P1[k]) v1 = false; if (b1 !== P2[k]) v2 = false;
        }
        s += 40 * ((h1 ? 1 : 0) + (h2 ? 1 : 0) + (v1 ? 1 : 0) + (v2 ? 1 : 0));
      }
      s += Math.floor(Math.abs(dark * 20 - size * size * 10) / (size * size)) * 10;
      return s;
    }
    var best = 0, bestScore = Infinity;
    for (var m = 0; m < 8; m++) { applyMask(m); drawFormat(m); var sc = penalty(); if (sc < bestScore) { bestScore = sc; best = m; } applyMask(m); }
    if (forceMask >= 0 && forceMask < 8) best = forceMask;
    applyMask(best); drawFormat(best);
    return { size: size, version: ver, mask: best, get: function (x, y) { return mod[y][x]; } };
  }

  function draw(canvas, q, scale) {
    var border = 4, n = q.size + border * 2;
    canvas.width = canvas.height = n * scale;
    var g = canvas.getContext("2d");
    g.fillStyle = "#fff"; g.fillRect(0, 0, canvas.width, canvas.height); g.fillStyle = "#000";
    for (var y = 0; y < q.size; y++) for (var x = 0; x < q.size; x++)
      if (q.get(x, y)) g.fillRect((x + border) * scale, (y + border) * scale, scale, scale);
  }

  root.RouteQR = { make: make, draw: draw, capacity: function (ver, ecl) { return dataCodewords(ver, ecl || "M") - (ver < 10 ? 2 : 3); } };
})(typeof window !== "undefined" ? window : this);

(function () {
  const R = window.REPORT_JSON || {};
  const meta = R.report_meta || {};
  const towers = R.towers || {};
  const melt = R.meltdown || {};
  const $ = (id) => document.getElementById(id);

  $("title").textContent = R.title || "Balance Lab";
  $("meta-line").textContent = [
    meta.game_version,
    meta.level_id,
    meta.difficulty_id,
    "seed " + meta.seed,
    meta.git_commit,
    meta.parameter_fingerprint,
    meta.timestamp
  ].filter(Boolean).join(" · ");
  $("designer-summary").textContent = R.designer_summary || "";

  const chipClass = (code) => {
    if (code === "WITHIN_TARGET") return "ok";
    if (code === "BELOW_TARGET" || code === "ABOVE_TARGET") return "warn";
    if (code === "SEVERELY_BELOW_TARGET") return "crit";
    return "muted";
  };
  const chips = $("chips");
  const status = R.tower_status || {};
  Object.keys(status).forEach((k) => {
    const el = document.createElement("div");
    el.className = "chip " + chipClass(status[k]);
    el.textContent = k.replace("_", " ") + ": " + String(status[k]).replaceAll("_", " ");
    chips.appendChild(el);
  });

  const cards = $("status-cards");
  ["basic_tower", "guard_post", "lava_tower"].forEach((id) => {
    const t = towers[id] || {};
    const d = document.createElement("div");
    d.className = "stat";
    d.innerHTML = "<div class='k'>" + (t.display_name || id) + "</div><div class='v'>" +
      (t.status_label || t.status || "NOT MEASURED") + "</div><div class='muted'>v/g " +
      fmt(t.median_value_per_gold) + " · rel " + fmt(t.relative_to_anchor_median) + "</div>";
    cards.appendChild(d);
  });
  const diff = document.createElement("div");
  diff.className = "stat";
  const dstat = (R.difficulty || {}).status_label || status.difficulty || "NOT MEASURED";
  diff.innerHTML = "<div class='k'>DIFFICULTY</div><div class='v'>" + dstat + "</div>";
  cards.appendChild(diff);

  const bars = $("anchor-bars");
  const maxRel = Math.max(1.2, ...["basic_tower", "guard_post", "lava_tower"].map((id) => Number((towers[id] || {}).relative_to_anchor_median || 0)));
  ["basic_tower", "guard_post", "lava_tower"].forEach((id) => {
    const t = towers[id] || {};
    const rel = Number(t.relative_to_anchor_median || 0);
    const wrap = document.createElement("div");
    wrap.innerHTML = "<div class='muted'>" + (t.display_name || id) + "</div><div class='bar'><span style='width:" +
      (100 * rel / maxRel) + "%'></span></div>";
    bars.appendChild(wrap);
  });

  const table = $("eff-table");
  table.innerHTML = "<tr><th>Tower</th><th>Cost</th><th>Median v/g</th><th>Rel. anchor</th><th>CV</th><th>Best</th><th>Worst</th><th>Early</th></tr>";
  ["basic_tower", "guard_post", "lava_tower"].forEach((id) => {
    const t = towers[id] || {};
    const tr = document.createElement("tr");
    tr.innerHTML = [t.display_name, fmt(t.cost), fmt(t.median_value_per_gold), fmt(t.relative_to_anchor_median),
      fmt(t.placement_cv), t.best_spot || "—", t.worst_spot || "—", fmt(t.early_build_multiplier)]
      .map((c) => "<td>" + c + "</td>").join("");
    table.appendChild(tr);
  });

  const placements = R.placements || (R.matrix && R.matrix.rows) || [];
  const heat = $("heatmap");
  const drawHeat = () => {
    const metric = $("heat-metric").value;
    const towersIds = [...new Set(placements.map((r) => r.tower_id))];
    const spots = [...new Set(placements.map((r) => r.spot_id))];
    const lookup = {};
    placements.forEach((r) => { lookup[r.tower_id + "|" + r.spot_id] = r; });
    const vals = placements.map((r) => Number(r[metric] || 0));
    const lo = Math.min(...vals, 0);
    const hi = Math.max(...vals, 1);
    heat.innerHTML = "";
    const grid = document.createElement("div");
    grid.className = "heat-grid";
    grid.style.gridTemplateColumns = "80px repeat(" + spots.length + ", 1fr)";
    grid.appendChild(cell("", true));
    spots.forEach((s) => grid.appendChild(cell(s, true)));
    towersIds.forEach((tid) => {
      grid.appendChild(cell(tid, true));
      spots.forEach((s) => {
        const row = lookup[tid + "|" + s];
        if (!row) {
          const m = document.createElement("div");
          m.className = "heat-cell heat-miss";
          m.textContent = "—";
          grid.appendChild(m);
          return;
        }
        const v = Number(row[metric] || 0);
        const t = (v - lo) / (hi - lo || 1);
        const el = document.createElement("div");
        el.className = "heat-cell";
        el.style.background = "rgb(" + Math.round(89 + t * 80) + "," + Math.round(184 - t * 90) + "," + Math.round(140 - t * 40) + ")";
        el.textContent = v.toFixed(2);
        grid.appendChild(el);
      });
    });
    heat.appendChild(grid);
  };
  function cell(text, header) {
    const d = document.createElement("div");
    d.className = "heat-cell" + (header ? " heat-miss" : "");
    d.textContent = text;
    return d;
  }
  $("heat-metric").addEventListener("change", drawHeat);
  drawHeat();

  const timing = R.build_timing || R.early_build || {};
  drawLines($("timing-chart"), Object.keys(timing).map((tid) => {
    const by = (timing[tid] || {}).by_wave || {};
    const xs = Object.keys(by).map(Number).sort((a, b) => a - b);
    return { label: tid, pts: xs.map((w) => ({ x: w, y: Number(by[w] || by[String(w)] || 0) })) };
  }));

  const params = melt.parameters || {};
  $("melt-params").innerHTML = Object.keys(params).map((k) => "<div><span class='muted'>" + k + "</span><br>" + fmt(params[k]) + "</div>").join("");
  const ramp = melt.ramp;
  $("melt-ramp").textContent = ramp
    ? ("t25=" + nnull(ramp.t_25) + "  t50=" + nnull(ramp.t_50) + "  t90=" + nnull(ramp.t_90) +
      "  peak DPS " + fmt(melt.peak_cell_dps) + " (" + pct(melt.peak_damage_fraction) + " of nominal)")
    : "Meltdown ramp NOT MEASURED";
  const mb = melt.mass_balance;
  if (mb) {
    const keys = ["emitted", "landed", "same_floor", "cross_floor", "decayed", "void_lost", "active"];
    const maxm = Math.max(...keys.map((k) => Number(mb[k] || 0)), 1);
    $("melt-mass").className = "mass";
    $("melt-mass").innerHTML = keys.map((k) => "<div style='height:" + (100 * Number(mb[k] || 0) / maxm) + "%'>" + k + "</div>").join("");
  }
  const series = melt.series || [];
  if (series.length) {
    drawLines($("melt-series"), [{
      label: "peak_cell_dps",
      pts: series.map((p) => ({ x: p.time, y: p.peak_cell_dps }))
    }, {
      label: "total_mass",
      pts: series.map((p) => ({ x: p.time, y: p.total_mass }))
    }]);
  }

  const fbs = R.full_builds || [];
  $("full-build").textContent = fbs.length
    ? JSON.stringify({ full_builds: fbs, defense_margin: R.defense_margin }, null, 2)
    : "Full-build NOT MEASURED. Defense margin NOT MEASURED.";
  const front = R.difficulty_frontier;
  if (!front) {
    $("frontier").textContent = "Difficulty frontier NOT MEASURED.";
  } else {
    $("frontier").textContent = JSON.stringify(front, null, 2);
  }
  if (!R.counterfactual && !R.shapley) {
    $("cf").textContent = "Counterfactual / Shapley not executed.";
  } else {
    $("cf").textContent = JSON.stringify({ counterfactual: R.counterfactual, shapley: R.shapley }, null, 2);
  }
  const warnings = R.warnings || [];
  $("warnings").innerHTML = warnings.length
    ? warnings.map((w) => "<li>[" + (w.severity || "") + "] " + (w.code || "") + " — " + (w.message || w) + "</li>").join("")
    : "<li>none</li>";
  const delta = R.previous_delta;
  $("delta").textContent = !delta
    ? "No previous report."
    : (delta.comparable ? JSON.stringify(delta, null, 2) : (delta.message || "Previous report not directly comparable."));

  function fmt(v) {
    if (v === null || v === undefined) return "null";
    const n = Number(v);
    return Number.isFinite(n) ? n.toFixed(3) : String(v);
  }
  function nnull(v) { return v === null || v === undefined ? "null" : Number(v).toFixed(2) + "s"; }
  function pct(v) { return v === null || v === undefined ? "null" : (100 * Number(v)).toFixed(1) + "%"; }

  function drawLines(canvas, seriesArr) {
    if (!canvas || !canvas.getContext) return;
    const ctx = canvas.getContext("2d");
    ctx.fillStyle = "#12141a";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    const pts = seriesArr.flatMap((s) => s.pts || []);
    if (!pts.length) return;
    const xs = pts.map((p) => p.x);
    const ys = pts.map((p) => p.y);
    const minX = Math.min(...xs), maxX = Math.max(...xs);
    const minY = Math.min(0, ...ys), maxY = Math.max(...ys, 1);
    const colors = ["#59b88c", "#eb9e59", "#6aa4d8"];
    seriesArr.forEach((s, i) => {
      ctx.strokeStyle = colors[i % colors.length];
      ctx.beginPath();
      (s.pts || []).forEach((p, j) => {
        const x = 40 + (canvas.width - 60) * ((p.x - minX) / (maxX - minX || 1));
        const y = canvas.height - 20 - (canvas.height - 40) * ((p.y - minY) / (maxY - minY || 1));
        if (j === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      });
      ctx.stroke();
    });
  }
})();

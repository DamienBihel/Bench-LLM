const COLORS = ["#7cc4ff", "#f8b26a", "#b794f6", "#4ade80", "#f87171", "#fbbf24", "#34d399", "#c084fc"];

/* ---------- theme ---------- */
function applyTheme(theme) {
  document.documentElement.setAttribute("data-theme", theme);
  localStorage.setItem("bench-theme", theme);
  const btn = document.getElementById("theme-toggle");
  if (btn) btn.textContent = theme === "light" ? "🌙" : "☀️";
  if (typeof renderAll === "function" && CURRENT_RUN) renderAll();
}
function initTheme() {
  const saved = localStorage.getItem("bench-theme");
  const prefersLight = window.matchMedia("(prefers-color-scheme: light)").matches;
  applyTheme(saved || (prefersLight ? "light" : "dark"));
  document.getElementById("theme-toggle")?.addEventListener("click", () => {
    const cur = document.documentElement.getAttribute("data-theme");
    applyTheme(cur === "light" ? "dark" : "light");
  });
}
initTheme();

let DATA = null;
let CURRENT_RUN = null;
let SELECTED_MODELS = new Set();
let CURRENT_TEST = null;
const charts = {};

function getCssVar(name) {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim() || "";
}

/* ---------- bootstrap ---------- */
async function load() {
  const res = await fetch("data.json", { cache: "no-store" });
  DATA = await res.json();

  const gen = document.getElementById("generated");
  if (DATA.generated_at) gen.textContent = "Généré : " + DATA.generated_at.replace("T", " ").slice(0, 16) + " UTC";

  const select = document.getElementById("run-select");
  DATA.runs.forEach((r, i) => {
    const opt = document.createElement("option");
    opt.value = i;
    opt.textContent = r.is_synthesis ? r.name : r.name;
    if (r.is_synthesis) opt.style.fontWeight = "bold";
    select.appendChild(opt);
  });
  const defaultIdx = DATA.runs.findIndex(r => r.is_synthesis);
  select.value = defaultIdx >= 0 ? defaultIdx : DATA.runs.length - 1;
  select.addEventListener("change", () => loadRun(DATA.runs[select.value]));

  document.querySelectorAll(".tab").forEach(btn => {
    btn.addEventListener("click", () => switchTab(btn.dataset.tab));
  });

  loadRun(DATA.runs[select.value]);
}

function switchTab(name) {
  document.querySelectorAll(".tab").forEach(t => t.classList.toggle("active", t.dataset.tab === name));
  document.querySelectorAll(".tab-panel").forEach(p => p.classList.toggle("active", p.id === "tab-" + name));
}

function loadRun(run) {
  CURRENT_RUN = run;
  const models = uniqueModels(run);
  SELECTED_MODELS = new Set(models);
  buildModelCheckboxes(models);
  buildTestSelector(run);
  renderAll();
}

function modelMeta(model) {
  return (DATA.models || {})[model] || {};
}

function modelSizeLabel(model) {
  const m = modelMeta(model);
  if (!m.params && !m.size_gb) return "";
  const bits = [];
  if (m.params) bits.push(m.params);
  if (m.size_gb) bits.push(m.size_gb + " Go");
  return bits.join(" · ");
}

function buildModelCheckboxes(models) {
  const cb = document.getElementById("model-checkboxes");
  cb.innerHTML = "<legend>Modèles affichés</legend>";
  models.forEach((m, i) => {
    const id = "cb-" + m.replace(/[^a-z0-9]/gi, "_");
    const meta = modelMeta(m);
    const sizeLabel = modelSizeLabel(m);
    const label = document.createElement("label");
    label.innerHTML = `<input type="checkbox" id="${id}" value="${m}" checked> <span style="color:${COLORS[i % COLORS.length]}">●</span> <strong>${m}</strong>${sizeLabel ? ` <span class="model-size">(${sizeLabel})</span>` : ""}`;
    label.querySelector("input").addEventListener("change", e => {
      if (e.target.checked) SELECTED_MODELS.add(m); else SELECTED_MODELS.delete(m);
      renderAll();
    });
    cb.appendChild(label);
  });
}

function buildTestSelector(run) {
  const tests = uniqueTests(run);
  const sel = document.getElementById("test-select");
  sel.innerHTML = "";
  tests.forEach(([id, label]) => {
    const opt = document.createElement("option");
    opt.value = id;
    opt.textContent = id + " — " + label;
    sel.appendChild(opt);
  });
  CURRENT_TEST = tests[0]?.[0] || null;
  sel.value = CURRENT_TEST;
  sel.onchange = () => { CURRENT_TEST = sel.value; renderResponses(); };
}

function renderAll() {
  renderKPIs();
  renderSpeedChart();
  renderDurationChart();
  renderScoresChart();
  renderScoresByTest();
  renderResponses();
}

/* ---------- helpers ---------- */
function uniqueModels(run) { return [...new Set(run.metrics.map(m => m.model))]; }
function uniqueTests(run) {
  const seen = new Map();
  run.metrics.forEach(m => { if (!seen.has(m.test_id)) seen.set(m.test_id, m.test_label); });
  return [...seen.entries()].sort(([a], [b]) => a.localeCompare(b));
}
function activeModels() { return uniqueModels(CURRENT_RUN).filter(m => SELECTED_MODELS.has(m)); }
function modelColor(model) {
  const all = uniqueModels(CURRENT_RUN);
  return COLORS[all.indexOf(model) % COLORS.length];
}
function escapeHtml(s) {
  if (s == null) return "";
  return String(s).replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
}
/* Mappe test_id long (metrics) <-> test_id court (scores) */
function scoresForTest(model, test_id) {
  const prefix = test_id.split("_")[0];
  return (CURRENT_RUN.scores || []).filter(s =>
    s.model === model && (
      s.test_id === test_id ||
      test_id.startsWith(s.test_id) ||
      s.test_id.startsWith(prefix + "_") ||
      s.test_id === prefix
    )
  );
}

/* ---------- KPIs ---------- */
function renderKPIs() {
  const container = document.getElementById("kpis");
  container.innerHTML = "";
  const models = activeModels();
  if (!models.length) {
    container.innerHTML = `<div class="kpi"><div class="label">Aucun modèle</div><div class="value">—</div></div>`;
    return;
  }

  const add = (label, value, sub) => {
    const div = document.createElement("div");
    div.className = "kpi";
    div.innerHTML = `<div class="label">${label}</div><div class="value">${value}</div>${sub ? `<div class="sub-value">${sub}</div>` : ""}`;
    container.appendChild(div);
  };

  models.forEach(m => {
    const rows = CURRENT_RUN.metrics.filter(r => r.model === m && r.tokens_per_s != null);
    if (!rows.length) return;
    const avgSpeed = rows.reduce((s, r) => s + r.tokens_per_s, 0) / rows.length;
    const avgDur = rows.reduce((s, r) => s + (r.duree_s || 0), 0) / rows.length;

    const scoreRows = (CURRENT_RUN.scores || []).filter(s => s.model === m);
    let scoreSub = "";
    if (scoreRows.length) {
      const pass = scoreRows.filter(s => s.resultat === "PASS").length;
      const pct = Math.round((pass / scoreRows.length) * 100);
      scoreSub = `${pct}% PASS (${pass}/${scoreRows.length})`;
    } else {
      scoreSub = "scoring n/a";
    }
    const sizeLabel = modelSizeLabel(m);
    const subBits = [];
    if (sizeLabel) subBits.push(sizeLabel);
    subBits.push(`~${avgDur.toFixed(0)}s/test`);
    subBits.push(scoreSub);
    add(m, `${avgSpeed.toFixed(1)} t/s`, subBits.join(" · "));
  });
}

/* ---------- Charts ---------- */
function makeDataset(field) {
  const models = activeModels();
  const tests = uniqueTests(CURRENT_RUN);
  const labels = tests.map(([id]) => id);
  const datasets = models.map(m => ({
    label: m,
    data: tests.map(([id]) => {
      const row = CURRENT_RUN.metrics.find(r => r.model === m && r.test_id === id);
      return row ? row[field] : null;
    }),
    backgroundColor: modelColor(m),
    borderColor: modelColor(m),
  }));
  return { labels, datasets };
}

function renderBarChart(id, field, yLabel) {
  const ctx = document.getElementById(id);
  if (charts[id]) charts[id].destroy();
  charts[id] = new Chart(ctx, {
    type: "bar",
    data: makeDataset(field),
    options: {
      responsive: true,
      plugins: {
        legend: { labels: { color: getCssVar("--fg") } },
        tooltip: { mode: "index", intersect: false },
      },
      scales: {
        x: { ticks: { color: getCssVar("--chart-tick") }, grid: { color: getCssVar("--chart-grid") } },
        y: { ticks: { color: getCssVar("--chart-tick") }, grid: { color: getCssVar("--chart-grid") }, title: { display: true, text: yLabel, color: getCssVar("--chart-tick") } },
      },
    },
  });
}
function renderSpeedChart() { renderBarChart("chart-speed", "tokens_per_s", "tokens/s"); }
function renderDurationChart() { renderBarChart("chart-duration", "duree_s", "secondes"); }

function renderScoresChart() {
  const ctx = document.getElementById("chart-scores");
  if (charts["chart-scores"]) charts["chart-scores"].destroy();
  const models = activeModels();
  const data = models.map(m => {
    const rows = (CURRENT_RUN.scores || []).filter(s => s.model === m);
    if (!rows.length) return 0;
    const pass = rows.filter(s => s.resultat === "PASS").length;
    return Math.round((pass / rows.length) * 100);
  });

  charts["chart-scores"] = new Chart(ctx, {
    type: "bar",
    data: {
      labels: models,
      datasets: [{
        label: "% PASS",
        data,
        backgroundColor: models.map(m => modelColor(m)),
      }],
    },
    options: {
      indexAxis: "y",
      responsive: true,
      plugins: { legend: { display: false }, tooltip: { callbacks: { label: c => c.parsed.x + "% de critères PASS" } } },
      scales: {
        x: { min: 0, max: 100, ticks: { color: getCssVar("--chart-tick"), callback: v => v + "%" }, grid: { color: getCssVar("--chart-grid") } },
        y: { ticks: { color: getCssVar("--chart-tick") }, grid: { color: getCssVar("--chart-grid") } },
      },
    },
  });
}

/* ---------- Critères regroupés par test ---------- */
function renderScoresByTest() {
  const container = document.getElementById("scores-by-test");
  container.innerHTML = "";
  const scores = CURRENT_RUN.scores || [];
  if (!scores.length) {
    container.innerHTML = `<p class="hint">Pas de scoring automatique pour ce run.</p>`;
    return;
  }

  const models = activeModels();
  const tests = uniqueTests(CURRENT_RUN);

  tests.forEach(([test_id, test_label]) => {
    const testScores = models.flatMap(m => scoresForTest(m, test_id));
    if (!testScores.length) return;

    const block = document.createElement("div");
    block.className = "test-block";

    const criteria = [...new Set(testScores.map(s => s.critere))];
    const totalPossible = criteria.length * models.length;
    const passCount = testScores.filter(s => s.resultat === "PASS").length;

    let html = `<h3>${test_id} — ${test_label}</h3>`;
    html += `<p class="summary">${passCount}/${totalPossible} critères PASS sur ${models.length} modèle(s)</p>`;
    html += `<table class="criteria-table"><thead><tr><th>Critère</th>`;
    models.forEach(m => html += `<th>${m}</th>`);
    html += `</tr></thead><tbody>`;
    criteria.forEach(c => {
      html += `<tr><td>${c}</td>`;
      models.forEach(m => {
        const row = scoresForTest(m, test_id).find(s => s.critere === c);
        if (!row) { html += "<td><span class='badge'>—</span></td>"; return; }
        const cls = row.resultat === "PASS" ? "pass" : "fail";
        const detail = row.detail ? `<span class="detail">${escapeHtml(row.detail)}</span>` : "";
        html += `<td><span class="badge ${cls}">${row.resultat}</span>${detail}</td>`;
      });
      html += `</tr>`;
    });
    html += `</tbody></table>`;
    block.innerHTML = html;
    container.appendChild(block);
  });
}

/* ---------- Réponses brutes ---------- */
function renderResponses() {
  if (!CURRENT_RUN || !CURRENT_TEST) return;
  const test_id = CURRENT_TEST;
  const prompt = (DATA.prompts || []).find(p => p.id === test_id);

  const desc = document.getElementById("test-description");
  if (prompt) {
    desc.innerHTML = `
      <h3>${prompt.id} — ${prompt.label}</h3>
      <p class="meta"><strong>Source :</strong> ${escapeHtml(prompt.source || "n/a")}</p>
      <dl>
        <dt>Prompt envoyé</dt><dd><pre>${escapeHtml(prompt.prompt)}</pre></dd>
        ${prompt.rubrique ? `<dt>Méthode d'évaluation</dt><dd><pre>${escapeHtml(prompt.rubrique)}</pre></dd>` : ""}
      </dl>
    `;
  } else {
    desc.innerHTML = `<p class="meta">Pas de descriptif disponible pour ce test.</p>`;
  }

  const grid = document.getElementById("responses-grid");
  grid.innerHTML = "";
  const models = activeModels();
  if (!models.length) {
    grid.innerHTML = `<p class="hint" style="padding:0 2rem">Sélectionne au moins un modèle.</p>`;
    return;
  }

  models.forEach(model => {
    const resp = (CURRENT_RUN.responses || []).find(r => r.model === model && r.test_id === test_id);
    const metric = CURRENT_RUN.metrics.find(m => m.model === model && m.test_id === test_id);
    const scores = scoresForTest(model, test_id);

    const card = document.createElement("div");
    card.className = "response-card";

    let stats = "stats indisponibles";
    if (metric) {
      const parts = [
        `durée ${metric.duree_s}s`,
        `${metric.eval_count} tokens total`,
        `${metric.tokens_per_s} t/s`,
      ];
      if (metric.thinking_chars != null) {
        const tc = metric.thinking_chars;
        const rc = metric.response_chars || 0;
        const total = tc + rc;
        if (tc > 0) {
          const pct = total > 0 ? Math.round((tc / total) * 100) : 0;
          parts.push(`réflexion ${tc}c (${pct}%)`);
        } else {
          parts.push("0 réflexion");
        }
      }
      stats = parts.join(" · ");
    }

    let scoresHtml = "";
    if (scores.length) {
      const passC = scores.filter(s => s.resultat === "PASS").length;
      scoresHtml = `<div class="scores">
        <span class="label">Scoring : ${passC}/${scores.length} PASS</span>
        <ul>` +
        scores.map(s => `<li><span class="badge ${s.resultat === 'PASS' ? 'pass' : 'fail'}">${s.resultat}</span> ${escapeHtml(s.critere)}${s.detail ? ' — <i>' + escapeHtml(s.detail) + '</i>' : ''}</li>`).join("") +
        `</ul></div>`;
    }

    const sizeLabel = modelSizeLabel(model);
    card.innerHTML = `
      <h3 style="color:${modelColor(model)}">${model}${sizeLabel ? ` <span class="model-size">${sizeLabel}</span>` : ""}</h3>
      <p class="stats">${stats}</p>
      <pre>${resp && resp.response ? escapeHtml(resp.response) : "<i>Pas de réponse</i>"}</pre>
      ${scoresHtml}
    `;
    grid.appendChild(card);
  });
}

load();

const COLORS = ["#7cc4ff", "#f8b26a", "#b794f6", "#4ade80", "#f87171", "#fbbf24"];

let DATA = null;
let charts = {};

async function load() {
  const res = await fetch("data.json", { cache: "no-store" });
  DATA = await res.json();

  const gen = document.getElementById("generated");
  if (DATA.generated_at) gen.textContent = "Dernière génération : " + DATA.generated_at.replace("T", " ").slice(0, 16) + " UTC";

  const select = document.getElementById("run-select");
  DATA.runs.forEach((r, i) => {
    const opt = document.createElement("option");
    opt.value = i;
    opt.textContent = r.name;
    select.appendChild(opt);
  });
  select.value = DATA.runs.length - 1;
  select.addEventListener("change", () => render(DATA.runs[select.value]));
  render(DATA.runs[select.value]);
}

function render(run) {
  renderKPIs(run);
  renderSpeedChart(run);
  renderDurationChart(run);
  renderScoresChart(run);
  renderScoresTable(run);
}

function uniqueModels(run) {
  return [...new Set(run.metrics.map(m => m.model))];
}

function uniqueTests(run) {
  const seen = new Map();
  run.metrics.forEach(m => { if (!seen.has(m.test_id)) seen.set(m.test_id, m.test_label); });
  return [...seen.entries()].sort(([a], [b]) => a.localeCompare(b));
}

function renderKPIs(run) {
  const models = uniqueModels(run);
  const container = document.getElementById("kpis");
  container.innerHTML = "";

  const add = (label, value) => {
    const div = document.createElement("div");
    div.className = "kpi";
    div.innerHTML = `<div class="label">${label}</div><div class="value">${value}</div>`;
    container.appendChild(div);
  };

  add("Run", run.name);
  add("Modèles", models.length);
  add("Tests", uniqueTests(run).length);

  models.forEach(m => {
    const rows = run.metrics.filter(r => r.model === m && r.tokens_per_s != null);
    if (!rows.length) return;
    const avg = rows.reduce((s, r) => s + r.tokens_per_s, 0) / rows.length;
    add(m + " (moy. tok/s)", avg.toFixed(1));
  });
}

function makeDataset(run, field) {
  const models = uniqueModels(run);
  const tests = uniqueTests(run);
  const labels = tests.map(([id]) => id);
  const datasets = models.map((m, i) => ({
    label: m,
    data: tests.map(([id]) => {
      const row = run.metrics.find(r => r.model === m && r.test_id === id);
      return row ? row[field] : null;
    }),
    backgroundColor: COLORS[i % COLORS.length],
    borderColor: COLORS[i % COLORS.length],
  }));
  return { labels, datasets };
}

function renderBarChart(id, run, field, yLabel) {
  const ctx = document.getElementById(id);
  if (charts[id]) charts[id].destroy();
  charts[id] = new Chart(ctx, {
    type: "bar",
    data: makeDataset(run, field),
    options: {
      responsive: true,
      plugins: {
        legend: { labels: { color: "#e7e9ee" } },
        tooltip: { mode: "index", intersect: false },
      },
      scales: {
        x: { ticks: { color: "#9aa3b2" }, grid: { color: "#262a33" } },
        y: { ticks: { color: "#9aa3b2" }, grid: { color: "#262a33" }, title: { display: true, text: yLabel, color: "#9aa3b2" } },
      },
    },
  });
}

function renderSpeedChart(run) { renderBarChart("chart-speed", run, "tokens_per_s", "tokens/s"); }
function renderDurationChart(run) { renderBarChart("chart-duration", run, "duree_s", "secondes"); }

function renderScoresChart(run) {
  const ctx = document.getElementById("chart-scores");
  if (charts["chart-scores"]) charts["chart-scores"].destroy();

  if (!run.scores || !run.scores.length) {
    ctx.parentElement.querySelector("h2").insertAdjacentHTML("afterend", '<p style="color:var(--muted);margin:0">Pas de scoring pour ce run.</p>');
    return;
  }

  const models = uniqueModels(run);
  const data = models.map(m => {
    const rows = run.scores.filter(s => s.model === m);
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
        backgroundColor: data.map((v, i) => COLORS[i % COLORS.length]),
      }],
    },
    options: {
      indexAxis: "y",
      responsive: true,
      plugins: { legend: { display: false } },
      scales: {
        x: { min: 0, max: 100, ticks: { color: "#9aa3b2", callback: v => v + "%" }, grid: { color: "#262a33" } },
        y: { ticks: { color: "#9aa3b2" }, grid: { color: "#262a33" } },
      },
    },
  });
}

function renderScoresTable(run) {
  const container = document.getElementById("scores-table");
  if (!run.scores || !run.scores.length) {
    container.innerHTML = '<p style="color:var(--muted)">Pas de scoring pour ce run.</p>';
    return;
  }
  const models = uniqueModels(run);
  const criteria = [...new Set(run.scores.map(s => s.test_id + " · " + s.critere))].sort();
  let html = "<table><thead><tr><th>Critère</th>";
  models.forEach(m => html += `<th>${m}</th>`);
  html += "</tr></thead><tbody>";
  criteria.forEach(c => {
    const [test_id, critere] = c.split(" · ");
    html += `<tr><td>${c}</td>`;
    models.forEach(m => {
      const row = run.scores.find(s => s.model === m && s.test_id === test_id && s.critere === critere);
      if (!row) { html += "<td></td>"; return; }
      const cls = row.resultat === "PASS" ? "pass" : "fail";
      const label = row.detail ? `${row.resultat} (${row.detail})` : row.resultat;
      html += `<td class="${cls}">${label}</td>`;
    });
    html += "</tr>";
  });
  html += "</tbody></table>";
  container.innerHTML = html;
}

load();

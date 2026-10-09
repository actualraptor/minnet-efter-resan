// Renders development status, roadmap and updates from data/roadmap.json,
// the single maintained source for the site (and the seed for GitHub issues).
(async function () {
  const esc = s => String(s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  let data;
  try {
    const res = await fetch("data/roadmap.json", { cache: "no-cache" });
    data = await res.json();
  } catch (e) {
    document.querySelectorAll("[data-status-error]").forEach(el => (el.hidden = false));
    return;
  }
  const label = s => data.statuses[s] || s;
  const badge = s => `<span class="badge s-${esc(s)}">${esc(label(s))}</span>`;

  const current = data.phases.find(p => p.id === data.current_milestone);
  const devList = document.getElementById("dev-items");
  if (devList && current) {
    document.getElementById("dev-title").textContent = `Milestone ${current.id}: ${current.title}`;
    devList.innerHTML = (current.items || []).map(i =>
      `<li>${badge(i.status)}<span>${esc(i.title)}${i.note ? `<span class="note">${esc(i.note)}</span>` : ""}</span></li>`).join("");
  }

  const tl = document.getElementById("timeline");
  if (tl) {
    tl.innerHTML = data.phases.map(p => `
      <article class="phase card${p.id === data.current_milestone ? " current" : ""}">
        <header><span class="num">${esc(p.id)}</span><h3>${esc(p.title)}</h3>${badge(p.status)}</header>
        <p>${esc(p.summary)}</p>
        ${p.items ? `<ul class="status-list" style="margin-top:12px">${p.items.map(i => `<li>${badge(i.status)}<span>${esc(i.title)}</span></li>`).join("")}</ul>` : ""}
      </article>`).join("");
  }

  const up = document.getElementById("updates");
  if (up) {
    up.innerHTML = data.updates.map(u => `
      <article><time datetime="${esc(u.date)}">${esc(u.date)}</time><h3>${esc(u.title)}</h3><p>${esc(u.body)}</p></article>`).join("");
  }
  document.querySelectorAll("[data-updated]").forEach(el => (el.textContent = data.updated));
})();

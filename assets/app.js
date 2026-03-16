'use strict';

const REFRESH_INTERVAL = 60; // seconds between data refreshes

let countdown = REFRESH_INTERVAL;
let refreshTimer = null;

// ── Fetch helpers ──────────────────────────────────────────────────────────

async function fetchJSON(url) {
  const res = await fetch(url + '?_=' + Date.now());
  if (!res.ok) throw new Error('HTTP ' + res.status);
  return res.json();
}

async function fetchText(url) {
  const res = await fetch(url + '?_=' + Date.now());
  if (!res.ok) return null;
  return res.text();
}

// ── Rendering ──────────────────────────────────────────────────────────────

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function renderStats(stats) {
  const s = stats || {};

  document.getElementById('val-total').textContent    = s.total    ?? '—';
  document.getElementById('val-deployed').textContent = s.deployed ?? '—';
  document.getElementById('val-skipped').textContent  = s.skipped  ?? '—';
  document.getElementById('val-failed').textContent   = s.failed   ?? '—';

  // Dim the failed card when nothing failed
  const failCard = document.querySelector('.stat-card.danger');
  if (failCard) failCard.dataset.zero = (s.failed === 0) ? 'true' : 'false';
}

function renderPackages(packages) {
  const grid = document.getElementById('packages');
  if (!grid) return;
  grid.innerHTML = '';

  if (!packages || packages.length === 0) {
    grid.innerHTML = '<div class="empty-state">No packages configured yet.</div>';
    return;
  }

  for (const pkg of packages) {
    const card = document.createElement('div');
    card.className = 'pkg-card ' + (pkg.deployed ? 'deployed' : 'not-deployed');

    const statusBadge = pkg.deployed
      ? '<span class="badge badge-deployed">deployed</span>'
      : '<span class="badge badge-pending">pending</span>';

    const signedBadge = pkg.deployed
      ? (pkg.signed
          ? '<span class="badge badge-signed">signed</span>'
          : '<span class="badge badge-unsigned">unsigned</span>')
      : '';

    const metaLines = [];
    if (pkg.size)    metaLines.push(escapeHtml(pkg.size));
    if (pkg.updated) metaLines.push('updated ' + formatDate(pkg.updated));

    card.innerHTML =
      '<div class="pkg-name">' + escapeHtml(pkg.name) + '</div>' +
      '<div class="pkg-badges">' + statusBadge + signedBadge + '</div>' +
      (metaLines.length
        ? '<div class="pkg-meta"><span>' + metaLines.join('</span><span>') + '</span></div>'
        : '');

    grid.appendChild(card);
  }
}

function formatDate(raw) {
  // Try to parse whatever date string comes from the script
  const d = new Date(raw);
  if (isNaN(d.getTime())) return escapeHtml(raw);
  return d.toLocaleString(undefined, {
    month: 'short', day: 'numeric',
    hour: '2-digit', minute: '2-digit'
  });
}

async function renderMotd(hasMOTD) {
  const section = document.getElementById('motd-section');
  if (!section) return;

  if (!hasMOTD) {
    section.classList.add('hidden');
    return;
  }

  const text = await fetchText('motd.txt');
  if (text && text.trim()) {
    document.getElementById('motd-content').textContent = text;
    section.classList.remove('hidden');
  } else {
    section.classList.add('hidden');
  }
}

async function renderLog() {
  const details = document.querySelector('.log-section details');
  if (!details || !details.open) return; // only fetch when visible

  const text = await fetchText('rollerblades.log');
  const el = document.getElementById('log-content');
  if (el) el.textContent = (text !== null && text.trim()) ? text : '(empty)';
}

function renderFooter(generated) {
  const el = document.getElementById('generated');
  if (!el) return;
  try {
    const d = new Date(generated);
    el.textContent = 'Last run: ' + d.toLocaleString();
  } catch {
    el.textContent = 'Last run: ' + generated;
  }
}

// ── Refresh countdown ──────────────────────────────────────────────────────

function updateCountdown() {
  const el = document.getElementById('refresh-info');
  if (el) {
    el.innerHTML =
      '<span class="refresh-dot"></span>refreshing in ' + countdown + 's';
  }

  countdown--;
  if (countdown < 0) {
    countdown = REFRESH_INTERVAL;
    load();
  }
}

// ── Main load ──────────────────────────────────────────────────────────────

async function load() {
  const errorBanner = document.getElementById('error-banner');

  try {
    const data = await fetchJSON('status.json');

    if (errorBanner) errorBanner.classList.add('hidden');

    renderStats(data.stats);
    renderPackages(data.packages);
    renderFooter(data.generated || '');
    await renderMotd(!!data.has_motd);
    await renderLog();

  } catch (err) {
    if (errorBanner) errorBanner.classList.remove('hidden');
  }
}

// ── Init ───────────────────────────────────────────────────────────────────

// Fetch log when the section is expanded
document.addEventListener('DOMContentLoaded', () => {
  const details = document.querySelector('.log-section details');
  if (details) {
    details.addEventListener('toggle', () => {
      if (details.open) renderLog();
    });
  }
});

load();

clearInterval(refreshTimer);
refreshTimer = setInterval(updateCountdown, 1000);

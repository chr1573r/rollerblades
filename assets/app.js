'use strict';

const REFRESH_INTERVAL = 60; // seconds between data refreshes

let countdown = REFRESH_INTERVAL;
let refreshTimer = null;
let clonePrefix = '';

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

// ── Utilities ──────────────────────────────────────────────────────────────

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function formatDate(raw) {
  const d = new Date(raw);
  if (isNaN(d.getTime())) return escapeHtml(raw);
  return d.toLocaleString(undefined, {
    month: 'short', day: 'numeric',
    hour: '2-digit', minute: '2-digit'
  });
}

// Convert clone prefix to a browsable HTTPS URL.
// Handles both HTTPS and SSH (git@host:org) formats.
function repoUrl(prefix, name) {
  if (!prefix || !name) return null;
  const sshMatch = prefix.match(/^git@([^:]+):(.+)$/);
  if (sshMatch) {
    return 'https://' + sshMatch[1] + '/' + sshMatch[2] + '/' + name;
  }
  return prefix.replace(/\/$/, '') + '/' + name;
}

async function copyToClipboard(text, btn) {
  try {
    await navigator.clipboard.writeText(text);
    btn.textContent = 'Copied!';
    btn.classList.add('copied');
    setTimeout(() => {
      btn.textContent = 'Copy';
      btn.classList.remove('copied');
    }, 2000);
  } catch {
    // Clipboard API unavailable — silently ignore
  }
}

// ── Rendering ──────────────────────────────────────────────────────────────

function renderStats(stats, hiddenStats) {
  const s = stats || {};
  document.getElementById('val-total').textContent    = s.total    ?? '—';
  document.getElementById('val-deployed').textContent = s.deployed ?? '—';
  document.getElementById('val-skipped').textContent  = s.skipped  ?? '—';
  document.getElementById('val-failed').textContent   = s.failed   ?? '—';

  const failCard = document.getElementById('public-failed-card');
  if (failCard) failCard.dataset.zero = (s.failed === 0) ? 'true' : 'false';

  const h = hiddenStats || {};
  const group = document.getElementById('unlisted-stats-group');
  if (group) {
    if (h.total > 0) {
      group.classList.remove('hidden');
      document.getElementById('val-hidden-total').textContent    = h.total    ?? '—';
      document.getElementById('val-hidden-deployed').textContent = h.deployed ?? '—';
      document.getElementById('val-hidden-skipped').textContent  = h.skipped  ?? '—';
      document.getElementById('val-hidden-failed').textContent   = h.failed   ?? '—';
      const hiddenFailCard = document.getElementById('unlisted-failed-card');
      if (hiddenFailCard) hiddenFailCard.dataset.zero = (h.failed === 0) ? 'true' : 'false';
    } else {
      group.classList.add('hidden');
    }
  }
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

    // Repo link
    const url = repoUrl(clonePrefix, pkg.name);
    const repoLink = url
      ? `<a class="pkg-repo-link" href="${escapeHtml(url)}" target="_blank" rel="noopener" title="View source repository">↗</a>`
      : '';

    // Status + signed badges
    const statusBadge = pkg.deployed
      ? '<span class="badge badge-deployed">deployed</span>'
      : '<span class="badge badge-pending">pending</span>';

    const signedBadge = pkg.deployed
      ? (pkg.signed
          ? '<span class="badge badge-signed">signed</span>'
          : '<span class="badge badge-unsigned">unsigned</span>')
      : '';

    // Meta line (size + updated)
    const metaParts = [];
    if (pkg.size)    metaParts.push(escapeHtml(pkg.size));
    if (pkg.updated) metaParts.push('updated ' + formatDate(pkg.updated));
    const metaHtml = metaParts.length
      ? `<div class="pkg-meta"><span>${metaParts.join('</span><span>')}</span></div>`
      : '';

    // Install command (only for deployed packages)
    const installCmd = `sk8 install ${pkg.name}`;
    const installBar = pkg.deployed
      ? `<div class="install-bar">
           <code class="install-cmd">${escapeHtml(installCmd)}</code>
           <button class="copy-btn" data-cmd="${escapeHtml(installCmd)}">Copy</button>
         </div>`
      : '';

    card.innerHTML =
      `<div class="pkg-header">
         <div class="pkg-name">${escapeHtml(pkg.name)}</div>
         ${repoLink}
       </div>
       <div class="pkg-badges">${statusBadge}${signedBadge}</div>
       ${metaHtml}
       ${installBar}`;

    grid.appendChild(card);
  }
}

async function renderMotd(hasMOTD) {
  const section = document.getElementById('motd-section');
  if (!section) return;

  if (!hasMOTD) { section.classList.add('hidden'); return; }

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
  if (!details || !details.open) return;

  const text = await fetchText('rollerblades.log');
  const el = document.getElementById('log-content');
  if (el) el.textContent = (text !== null && text.trim()) ? text : '(empty)';
}

async function renderSigningKey() {
  const details = document.querySelector('.key-section details');
  if (!details || !details.open) return;

  const text = await fetchText('rollerblades.pub');
  const el = document.getElementById('key-content');
  if (el) el.textContent = (text !== null && text.trim()) ? text.trim() : '(not available)';
}

function renderFooter(generated) {
  const el = document.getElementById('generated');
  if (!el) return;
  try {
    el.textContent = 'Last run: ' + new Date(generated).toLocaleString();
  } catch {
    el.textContent = 'Last run: ' + generated;
  }
}

// ── Refresh countdown ──────────────────────────────────────────────────────

function updateCountdown() {
  const el = document.getElementById('refresh-info');
  if (el) {
    el.innerHTML = '<span class="refresh-dot"></span>refreshing in ' + countdown + 's';
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
  const initBanner  = document.getElementById('init-banner');
  try {
    const data = await fetchJSON('status.json');

    if (errorBanner) errorBanner.classList.add('hidden');

    // Server is still initialising — show the banner, skip rendering
    if (data.initializing) {
      if (initBanner) initBanner.classList.remove('hidden');
      return;
    }

    if (initBanner) initBanner.classList.add('hidden');

    clonePrefix = data.clone_prefix || '';

    renderStats(data.stats, data.hidden_stats);
    renderPackages(data.packages);
    renderFooter(data.generated || '');
    await renderMotd(!!data.has_motd);
    await renderLog();
    await renderSigningKey();

  } catch {
    if (errorBanner) errorBanner.classList.remove('hidden');
  }
}

// ── Event wiring ───────────────────────────────────────────────────────────

// Copy buttons on package cards (event delegation)
document.addEventListener('click', (e) => {
  const btn = e.target.closest('.copy-btn');
  if (btn) copyToClipboard(btn.dataset.cmd, btn);
});

// Signing key copy button
const keyCopyBtn = document.getElementById('key-copy-btn');
if (keyCopyBtn) {
  keyCopyBtn.addEventListener('click', () => {
    const text = document.getElementById('key-content')?.textContent;
    if (text) copyToClipboard(text, keyCopyBtn);
  });
}

// Lazy-load log when expanded
document.querySelector('.log-section details')
  ?.addEventListener('toggle', (e) => { if (e.target.open) renderLog(); });

// Lazy-load signing key when expanded
document.querySelector('.key-section details')
  ?.addEventListener('toggle', (e) => { if (e.target.open) renderSigningKey(); });

// ── Init ───────────────────────────────────────────────────────────────────

load();

clearInterval(refreshTimer);
refreshTimer = setInterval(updateCountdown, 1000);

// 下载 Termux 与 Termux:X11（本机 curl/PowerShell 的 TLS 坏了，只能走 Node）
const https = require('https');
const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const outDir = __dirname;

function get(url, redirects = 0) {
  return new Promise((resolve, reject) => {
    if (redirects > 6) return reject(new Error('too many redirects'));
    https.get(url, { headers: { 'User-Agent': 'curl/8', Accept: 'application/vnd.github+json' } }, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        res.resume();
        return resolve(get(res.headers.location, redirects + 1));
      }
      if (res.statusCode !== 200) {
        let b = '';
        res.on('data', (d) => (b += d));
        res.on('end', () => reject(new Error('HTTP ' + res.statusCode + ' ' + b.slice(0, 200))));
        return;
      }
      resolve(res);
    }).on('error', reject);
  });
}

async function json(url) {
  const res = await get(url);
  let b = '';
  for await (const c of res) b += c;
  return JSON.parse(b);
}

async function download(url, file) {
  const res = await get(url);
  const hash = crypto.createHash('sha256');
  const out = fs.createWriteStream(file);
  res.on('data', (d) => hash.update(d));
  res.pipe(out);
  await new Promise((r, j) => out.on('finish', r).on('error', j));
  return { size: fs.statSync(file).size, sha: hash.digest('hex') };
}

(async () => {
  const targets = [
    { repo: 'termux/termux-app', match: /arm64.*\.apk$|universal.*\.apk$/i, name: 'termux.apk' },
    { repo: 'termux/termux-x11', match: /universal.*\.apk$|arm64.*\.apk$/i, name: 'termux-x11.apk' },
  ];
  for (const t of targets) {
    const rel = await json(`https://api.github.com/repos/${t.repo}/releases/latest`);
    const apks = (rel.assets || []).filter((a) => /\.apk$/i.test(a.name));
    console.log(`\n== ${t.repo} ${rel.tag_name} ==`);
    apks.forEach((a) => console.log('   ', a.name, (a.size / 1048576).toFixed(1) + 'MB'));
    const pick = apks.find((a) => t.match.test(a.name)) || apks[0];
    if (!pick) { console.log('   !! no apk asset'); continue; }
    const r = await download(pick.browser_download_url, path.join(outDir, t.name));
    console.log('   saved', t.name, (r.size / 1048576).toFixed(1) + 'MB', 'sha256=' + r.sha.slice(0, 16) + '...');
  }
})().catch((e) => { console.error('FAILED:', e.message); process.exit(1); });

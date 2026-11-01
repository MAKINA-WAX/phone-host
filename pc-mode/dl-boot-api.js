// 下载 Termux:Boot 与 Termux:API（本机 curl/PowerShell 的 TLS 坏了，走 Node）
const https = require('https');
const fs = require('fs');
const path = require('path');
function get(u, r = 0) {
  return new Promise((res, rej) => https.get(u, { headers: { 'User-Agent': 'curl/8', Accept: 'application/vnd.github+json' } }, x => {
    if (x.statusCode >= 300 && x.statusCode < 400 && x.headers.location) { x.resume(); return res(get(x.headers.location, r + 1)); }
    if (x.statusCode !== 200) { x.resume(); return rej(new Error('HTTP ' + x.statusCode)); }
    res(x);
  }).on('error', rej));
}
(async () => {
  const dir = process.argv[2];
  for (const [repo, out] of [['termux/termux-boot', 'termux-boot.apk'], ['termux/termux-api', 'termux-api.apk']]) {
    const r = await get(`https://api.github.com/repos/${repo}/releases/latest`);
    let b = ''; for await (const c of r) b += c;
    const j = JSON.parse(b);
    const apks = (j.assets || []).filter(a => /\.apk$/i.test(a.name));
    console.log(repo, j.tag_name, apks.map(a => a.name).join(', '));
    const pick = apks.find(a => /arm64.*\.apk$/.test(a.name)) || apks[0];
    if (!pick) { console.log('  no apk'); continue; }
    const d = await get(pick.browser_download_url);
    const o = fs.createWriteStream(path.join(dir, out));
    d.pipe(o);
    await new Promise(res => o.on('finish', res));
    console.log('  saved', out, fs.statSync(path.join(dir, out)).size);
  }
})().catch(e => { console.error('FAILED', e.message); process.exit(1); });

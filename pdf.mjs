/* Genera una lámina imprimible con la ascendencia de una persona.
 *
 *   node pdf.mjs --raiz anibal --salida "G:/.../Ascendencia Anibal Carlini"
 *
 * Escribe un HTML autocontenido y lo manda a Chrome headless con --print-to-pdf.
 * Sale VECTOR: el texto queda seleccionable y nítido a cualquier ampliación, que
 * es lo que hace falta para imprimir grande. Además deja un PNG a 3x por si hay
 * que mandarlo por chat.
 */
import { readFileSync, writeFileSync } from 'node:fs'
import { execFileSync } from 'node:child_process'

const arg = (n, d) => { const i = process.argv.indexOf('--' + n); return i > 0 ? process.argv[i + 1] : d }
const RAIZ = arg('raiz', 'anibal')
const SALIDA = arg('salida', 'ascendencia')
const CHROME = arg('chrome', 'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe')

const P = eval('(' + readFileSync('datos.js', 'utf8').match(/const P=(\{[\s\S]*\});/)[1] + ')')
const pa = (id) => (P[id]?.pa || []).filter((x) => P[x])
if (!P[RAIZ]) { console.error('No existe la persona', RAIZ); process.exit(1) }

/* ── geometría, en píxeles CSS (1px = 1/96") ── */
const CW = 236, GX = 84, GY = 20, PAD = 64, CABEZA = 196
const alto = (id) => 58 + (P[id].pr ? 15 : 0) + ((P[id].c?.length) ? 13 : 0)

const X = {}, Y = {}, orden = []
let cursor = 0, maxD = 0
;(function poner (id, d) {
  if (Y[id] !== undefined) return Y[id]
  maxD = Math.max(maxD, d)
  const ps = pa(id)
  if (!ps.length) { Y[id] = cursor; cursor += alto(id) + GY }
  else {
    const ys = ps.map((p) => poner(p, d + 1))
    Y[id] = (Math.min(...ys) + Math.max(...ys) + alto(ps[ps.length - 1]) - alto(id)) / 2
  }
  X[id] = d * (CW + GX)
  orden.push(id)
  return Y[id]
})(RAIZ, 0)

const W = (maxD + 1) * (CW + GX) - GX + PAD * 2
const H = Math.max(...orden.map((i) => Y[i] + alto(i))) + PAD * 2 + CABEZA + 56
const mm = (px) => (px * 25.4 / 96).toFixed(2)

/* ── parentescos, vistos desde la raíz ── */
const PARENT = ['', 'Padres', 'Abuelos', 'Bisabuelos', 'Tatarabuelos', 'Trastatarabuelos',
  '4.os abuelos', '5.os abuelos', '6.os abuelos', '7.os abuelos']
const par = (d) => PARENT[d] ?? `${d}.ª generación atrás`

const COLOR = { sicilia: '#9b3350', friuli: '#286b5c', arg: '#35566f' }
const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;')
const año = (id) => { const m = P[id].d?.match(/\d{4}/); return m ? +m[0] : null }

/* ── conectores: una horquilla por persona con padres ── */
let paths = ''
for (const id of orden) {
  const ps = pa(id)
  if (!ps.length) continue
  const x1 = PAD + X[id] + CW, y1 = PAD + CABEZA + Y[id] + alto(id) / 2
  const mid = x1 + GX / 2
  const ys = ps.map((p) => PAD + CABEZA + Y[p] + alto(p) / 2)
  const hip = P[id].hyp
  const st = `fill="none" stroke="${hip ? '#8a5514' : '#c9c4ba'}" stroke-width="${hip ? 1.4 : 1.2}"` +
    (hip ? ' stroke-dasharray="5 3"' : '') + ' stroke-linecap="round"'
  paths += `<path d="M${x1} ${y1} H${mid}" ${st}/>`
  if (ys.length > 1) paths += `<path d="M${mid} ${Math.min(...ys)} V${Math.max(...ys)}" ${st}/>`
  for (const p of ps) {
    paths += `<path d="M${mid} ${PAD + CABEZA + Y[p] + alto(p) / 2} H${PAD + X[p]}" ${st}/>`
  }
  paths += `<circle cx="${mid}" cy="${y1}" r="2.2" fill="${hip ? '#8a5514' : '#a4a9a5'}"/>`
  if (hip) paths += `<text x="${mid + 5}" y="${y1 - 5}" fill="#8a5514" font-size="8.5"` +
    ` font-family="Inter Tight,sans-serif" letter-spacing="0.6">HIPÓTESIS</text>`
}

/* ── tarjetas ── */
let cards = ''
for (const id of orden) {
  const p = P[id]
  const c = COLOR[p.b] || '#c9c4ba'
  const cert = p.c?.length && !p.t && !p.hyp
  const fuente = p.c?.length ? p.c[0][0] : (p.t ? 'Testimonio familiar' : '')
  cards += `<div class="p${p.open ? ' open' : ''}" style="left:${PAD + X[id]}px;top:${PAD + CABEZA + Y[id]}px;` +
    `width:${CW}px;border-left-color:${c}">` +
    `<b>${esc(p.n)}${cert ? '<i class="ck">✓</i>' : ''}</b>` +
    `<span class="yr">${esc(p.d)}</span>` +
    (p.pr ? `<span class="pr">${esc(p.pr)}</span>` : '') +
    (fuente ? `<span class="src">${esc(fuente)}</span>` : '') +
    '</div>'
}

/* ── encabezados de columna ── */
let heads = ''
for (let d = 0; d <= maxD; d++) {
  const gente = orden.filter((i) => X[i] === d * (CW + GX))
  const ys = gente.map(año).filter(Boolean)
  heads += `<div class="ch" style="left:${PAD + d * (CW + GX)}px">` +
    `<b>${d === 0 ? P[RAIZ].n.split(' ')[0] : par(d)}</b>` +
    (ys.length ? `<span>${Math.min(...ys)}${Math.min(...ys) !== Math.max(...ys) ? '–' + Math.max(...ys) : ''} · ${gente.length} persona${gente.length===1?"":"s"}</span>` : '') +
    '</div>'
}

const docs = orden.filter((i) => P[i].c?.length).length
const hips = orden.filter((i) => P[i].hyp).length
const front = orden.filter((i) => P[i].open).length
const años_ = orden.map(año).filter(Boolean)

const html = `<!doctype html><meta charset="utf-8">
<title>Ascendencia de ${esc(P[RAIZ].n)}</title>
<style>${readFileSync("fonts/inline.css","utf8")}</style>
<style>
@page { size: ${mm(W)}mm ${mm(H)}mm; margin: 0 }
*{box-sizing:border-box;margin:0;padding:0}
body{width:${W}px;height:${H}px;position:relative;background:#fffefb;color:#191c1a;
  font-family:"Inter Tight",system-ui,sans-serif;-webkit-print-color-adjust:exact;print-color-adjust:exact}
.tit{position:absolute;left:${PAD}px;top:${PAD - 26}px;width:${W - PAD * 2}px}
.tit h1{font-family:Fraunces,Georgia,serif;font-size:31px;font-weight:500;letter-spacing:-.015em}
.tit p{margin-top:7px;font-size:13px;color:#6b716d;max-width:78ch;line-height:1.55}
.meta{margin-top:11px;font-size:11px;color:#a4a9a5;display:flex;gap:20px;flex-wrap:wrap}
.meta i{font-style:normal;color:#6b716d}
svg{position:absolute;inset:0;width:${W}px;height:${H}px}
.ch{position:absolute;top:${PAD + CABEZA - 34}px;white-space:nowrap}
.ch b{display:block;font-family:Fraunces,serif;font-size:13px;font-weight:500;color:#6b716d}
.ch span{display:block;font-size:9.5px;color:#a4a9a5;margin-top:1px;font-variant-numeric:tabular-nums}
.p{position:absolute;background:#fff;border:1px solid #ddd8ce;border-left:3px solid;border-radius:9px;
  padding:8px 11px 9px}
.p.open{border-style:dashed;border-left-style:solid;background:#fdf8ef}
.p b{display:block;font-size:13.5px;font-weight:600;line-height:1.22;letter-spacing:-.005em}
.p .ck{display:inline-block;font-style:normal;font-size:8.5px;margin-left:4px;color:#286b5c;
  border:1px solid #286b5c;border-radius:50%;width:11px;height:11px;line-height:10px;text-align:center;
  vertical-align:1.5px}
.p .yr{display:block;font-size:10.5px;color:#6b716d;margin-top:2px;font-variant-numeric:tabular-nums}
.p .pr{display:block;font-size:10px;color:#8a8f8b;font-style:italic;margin-top:3px;line-height:1.3}
.p .src{display:block;font-size:8.5px;color:#b3b8b4;margin-top:4px;line-height:1.3;
  overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.leg{position:absolute;left:${PAD}px;bottom:${PAD - 34}px;display:flex;gap:22px;flex-wrap:wrap;
  font-size:10px;color:#6b716d;align-items:center}
.leg i{font-style:normal;display:inline-flex;align-items:center;gap:6px}
.sw{width:15px;height:9px;border-radius:2px;border:1px solid #6b716d;display:inline-block}
.sw.s{border-left:3px solid #9b3350}.sw.a{border-left:3px solid #35566f}
.sw.o{border-style:dashed;background:#fdf8ef;border-color:#8a5514}
.dash{width:22px;border-top:1.4px dashed #8a5514;display:inline-block}
</style>
<div class="tit">
  <h1>Ascendencia de ${esc(P[RAIZ].n)}</h1>
  <p>Reconstruida a partir de actas civiles y parroquiales de Sicilia y de la Argentina. Cada
  persona con ✓ está respaldada por al menos un documento; las líneas punteadas marcan vínculos
  razonados que todavía ningún acta confirma, y las cajas de borde punteado son fronteras abiertas
  de la investigación.</p>
  <div class="meta">
    <span><i>${orden.length}</i> personas</span>
    <span><i>${maxD + 1}</i> generaciones</span>
    <span><i>${Math.min(...años_)}–${Math.max(...años_)}</i></span>
    <span><i>${docs}</i> documentadas</span>
    <span><i>${hips}</i> hipótesis</span>
    <span><i>${front}</i> fronteras</span>
    <span>arbol-novello-carlini · 24 de agosto de 2026</span>
  </div>
</div>
<svg xmlns="http://www.w3.org/2000/svg">${paths}</svg>
${heads}${cards}
<div class="leg">
  <i><span class="sw s"></span> rama siciliana</i>
  <i><span class="sw a"></span> rama argentina</i>
  <i><span class="sw o"></span> frontera: la investigación sigue</i>
  <i><span class="dash"></span> vínculo hipotético</i>
  <i>✓ respaldado por documentos</i>
</div>`

const base = SALIDA.replace(/\.(pdf|html)$/i, '')
writeFileSync(base + '.html', html)
console.log(`lámina: ${W}×${H}px = ${mm(W)}×${mm(H)}mm · ${orden.length} personas · ${maxD + 1} columnas`)

const url = 'file:///' + (base + '.html').replace(/\\/g, '/').replace(/ /g, '%20')
for (const [flag, ext] of [[`--print-to-pdf=${base}.pdf`, 'pdf'], [`--screenshot=${base}.png`, 'png']]) {
  execFileSync(CHROME, [
    '--headless=new', '--disable-gpu', '--no-pdf-header-footer', '--no-margins',
    '--run-all-compositor-stages-before-draw', '--virtual-time-budget=12000',
    ext === 'png' ? `--window-size=${W},${H}` : '--window-size=1200,900',
    ext === 'png' ? '--force-device-scale-factor=3' : '--force-device-scale-factor=1',
    flag, url,
  ], { stdio: 'pipe' })
  console.log(' ->', base + '.' + ext)
}

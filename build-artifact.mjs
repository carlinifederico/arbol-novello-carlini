/* Arma _artifact.html: la misma página, pero autocontenida.
   El visor de artifacts bloquea todo host externo salvo Google Fonts, así que
   los dos scripts y las imágenes de registro se meten adentro del archivo. */
import { readFileSync, writeFileSync, readdirSync } from 'node:fs'

let h = readFileSync('index.html', 'utf8')

for (const f of ['datos.js', 'vistas.js']) {
  const js = readFileSync(f, 'utf8')
  h = h.replace(`<script src="${f}"></script>`, `<script>\n${js}\n</script>`)
}

let n = 0
for (const f of readdirSync('registros')) {
  const b64 = readFileSync(`registros/${f}`).toString('base64')
  const mime = f.endsWith('.png') ? 'image/png' : 'image/jpeg'
  const antes = h
  h = h.split(`registros/${f}`).join(`data:${mime};base64,${b64}`)
  if (h !== antes) n++
}

writeFileSync('_artifact.html', h)
console.log(`_artifact.html · ${(h.length / 1e6).toFixed(2)} MB · ${n} imágenes embebidas`)
if (h.includes('registros/')) console.log('OJO: quedó alguna referencia a registros/ sin embeber')
if (h.length > 16e6) console.log('OJO: pasa el límite de 16 MB del visor')

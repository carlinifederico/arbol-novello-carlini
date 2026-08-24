/* Baja las dos familias de Google Fonts y las deja incrustadas en fonts/inline.css.
 *
 * Hace falta porque Chrome headless, al imprimir a PDF, no siempre llega a
 * resolver las fuentes por red: el PDF salía sin las tipografías embebidas.
 * Con el @font-face en base64 no hay red de por medio y quedan adentro del
 * archivo, que es lo que hace que el texto se vea igual en cualquier máquina.
 *
 * Se queda sólo con los cortes latinos: el CSS de Google trae también griego,
 * cirílico y vietnamita, y eso multiplicaría el peso sin que se use una letra.
 */
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs'
import { execFileSync } from 'node:child_process'

const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
const CSS = 'https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,400;9..144,500;9..144,600&family=Inter+Tight:wght@400;500;600&display=swap'

if (!existsSync('fonts')) mkdirSync('fonts')
const baja = (url, out) => { execFileSync('curl', ['-sS', '-A', UA, url, '-o', out]); return readFileSync(out) }

baja(CSS, 'fonts/css.txt')
const css = readFileSync('fonts/css.txt', 'utf8')

// cada bloque @font-face con su comentario de subconjunto delante
const bloques = css.split(/\/\* /).slice(1)
let out = '', n = 0, bytes = 0
for (const b of bloques) {
  const sub = b.slice(0, b.indexOf(' */'))
  if (!/^latin/.test(sub)) continue              // latin y latin-ext, nada más
  const cuerpo = b.slice(b.indexOf('*/') + 2)
  const url = (cuerpo.match(/url\((https:\/\/fonts\.gstatic\.com\/[^)]+)\)/) || [])[1]
  if (!url) continue
  const archivo = 'fonts/' + url.split('/').pop()
  const buf = existsSync(archivo) ? readFileSync(archivo) : baja(url, archivo)
  bytes += buf.length; n++
  out += cuerpo.replace(/url\(https:\/\/[^)]+\)/,
    `url(data:font/woff2;base64,${buf.toString('base64')})`).trim() + '\n'
}
writeFileSync('fonts/inline.css', out)
console.log(`fonts/inline.css · ${n} cortes latinos · ${(bytes / 1024).toFixed(0)} KB de woff2`)

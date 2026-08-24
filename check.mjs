/** Chequeo del sitio: referencias de parentesco válidas y sin datos personales filtrados. */
import { readFileSync } from 'node:fs'

const html = readFileSync('index.html', 'utf8')

const m = html.match(/const P=(\{[\s\S]*?\n\});/)
if (!m) { console.log('No se encontró el objeto P'); process.exit(1) }
const P = eval('(' + m[1] + ')')

let bad = 0
for (const [k, v] of Object.entries(P)) {
  for (const p of v.pa ?? []) if (!P[p]) { bad++; console.log(`PADRE INEXISTENTE  ${k} -> ${p}`) }
  for (const s of v.sib ?? []) if (!P[s]) { bad++; console.log(`HERMANO INEXISTENTE  ${k} -> ${s}`) }
}

// las raíces del selector tienen que existir
for (const r of [...html.matchAll(/data-root="(\w+)"/g)].map((x) => x[1])) {
  if (!P[r]) { bad++; console.log(`RAÍZ INEXISTENTE  ${r}`) }
}

// ciclos: nadie puede ser su propio antepasado
for (const start of Object.keys(P)) {
  const seen = new Set()
  const stack = [start]
  while (stack.length) {
    const id = stack.pop()
    if (seen.has(id)) { bad++; console.log(`CICLO detectado en ${start} (${id})`); break }
    seen.add(id)
    stack.push(...(P[id]?.pa ?? []))
  }
}

// nada personal de gente viva
const leaks = [
  [/\b\d{2}\.\d{3}\.\d{3}\b/g, 'documento'],
  [/CUIL|CRLFRC/g, 'identificador fiscal'],
  [/Zapiola \d+|Gascón \d+|Concejal Acosta \d+|Aráoz \d+/g, 'domicilio'],
]
for (const [re, label] of leaks) {
  const hit = html.match(re)
  if (hit) { bad++; console.log(`FUGA (${label}): ${[...new Set(hit)].join(', ')}`) }
}

const open = Object.values(P).filter((p) => p.open).length
const hyp = Object.values(P).filter((p) => p.hyp).length
console.log(`personas: ${Object.keys(P).length} · fronteras: ${open} · vínculos hipotéticos: ${hyp} · errores: ${bad}`)
process.exit(bad ? 1 : 0)

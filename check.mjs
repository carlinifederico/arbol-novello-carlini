/** Chequeo del árbol: referencias válidas, sin ciclos, sin datos personales filtrados. */
import { readFileSync } from 'node:fs'

const datos = readFileSync('datos.js', 'utf8')
const html = readFileSync('index.html', 'utf8')
const P = eval('(' + datos.match(/const P=(\{[\s\S]*\});/)[1] + ')')

let bad = 0
for (const [k, v] of Object.entries(P)) {
  for (const p of v.pa ?? []) if (!P[p]) { bad++; console.log(`PADRE INEXISTENTE  ${k} -> ${p}`) }
  for (const s of v.sib ?? []) if (!P[s]) { bad++; console.log(`HERMANO INEXISTENTE  ${k} -> ${s}`) }
}

// ciclos genealógicos
for (const start of Object.keys(P)) {
  const seen = new Set(); const stack = [start]
  while (stack.length) {
    const id = stack.pop()
    if (seen.has(id)) { bad++; console.log(`CICLO en ${start} (${id})`); break }
    seen.add(id); stack.push(...(P[id]?.pa ?? []))
  }
}

// nadie suelto: todos deben conectar con el resto del árbol
const adj = new Map(Object.keys(P).map((k) => [k, new Set()]))
for (const [k, v] of Object.entries(P)) for (const p of v.pa ?? []) { adj.get(k).add(p); adj.get(p).add(k) }
const seen = new Set(['antonio']); const q = ['antonio']
while (q.length) for (const n of adj.get(q.pop()) ?? []) if (!seen.has(n)) { seen.add(n); q.push(n) }
const sueltos = Object.keys(P).filter((k) => !seen.has(k))
if (sueltos.length) console.log(`sin conexión con el árbol principal: ${sueltos.map((k) => P[k].n).join(', ')}`)

for (const [re, label] of [
  [/\b\d{2}\.\d{3}\.\d{3}\b/g, 'documento'],
  [/CUIL|CRLFRC/g, 'identificador fiscal'],
  [/Zapiola \d+|Gascón \d+|Concejal Acosta \d+|Aráoz \d+/g, 'domicilio'],
]) {
  const hit = (datos + html).match(re)
  if (hit) { bad++; console.log(`FUGA (${label}): ${[...new Set(hit)].join(', ')}`) }
}

const c = (f) => Object.values(P).filter(f).length
console.log(`personas: ${Object.keys(P).length} · documentadas: ${c((p) => p.c?.length && !p.t)} · testimonio: ${c((p) => p.t)} · hipótesis: ${c((p) => p.hyp)} · fronteras: ${c((p) => p.open)} · errores: ${bad}`)
process.exit(bad ? 1 : 0)

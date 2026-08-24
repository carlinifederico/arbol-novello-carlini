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

/* --- Las generaciones: el mismo modelo que usa el dibujo, verificado aparte ---
   Tres reglas que tienen que cumplirse a la vez, y que se rompieron una por una
   hasta dar con el modelo correcto:
     1. cada hijo va exactamente una generación después de sus padres
     2. los dos padres de un hijo comparten generación
     3. los hermanos comparten generación
   Además los años deben avanzar: ninguna generación puede empezar antes que la
   anterior. */
{
  const ids = Object.keys(P)
  const pa = (id) => (P[id]?.pa ?? []).filter((x) => P[x])
  const ch = (id) => ids.filter((k) => (P[k].pa ?? []).includes(id))
  const uf = {}; ids.forEach((i) => (uf[i] = i))
  const find = (x) => (uf[x] === x ? x : (uf[x] = find(uf[x])))
  const une = (a, b) => { const ra = find(a), rb = find(b); if (ra !== rb) uf[ra] = rb }
  ids.forEach((id) => { const p = pa(id); for (let i = 1; i < p.length; i++) une(p[0], p[i]) })
  ids.forEach((id) => { const c = ch(id); for (let i = 1; i < c.length; i++) une(c[0], c[i]) })

  const out = {}; ids.forEach((i) => (out[find(i)] ??= new Set()))
  ids.forEach((id) => { const p = pa(id); if (!p.length) return
    const a = find(p[0]), b = find(id); if (a !== b) out[a].add(b) })

  const g = {}; Object.keys(out).forEach((k) => (g[k] = 0))
  for (let it = 0; it < 80; it++) {
    let moved = false
    for (const k of Object.keys(out)) for (const h of out[k]) if (g[h] < g[k] + 1) { g[h] = g[k] + 1; moved = true }
    for (const k of Object.keys(out)) { if (!out[k].size) continue
      const m = Math.min(...[...out[k]].map((h) => g[h])) - 1
      if (m > g[k]) { g[k] = m; moved = true } }
    if (!moved) break
  }
  const gen = {}; ids.forEach((i) => (gen[i] = g[find(i)]))

  ids.forEach((id) => pa(id).forEach((p) => {
    if (gen[id] !== gen[p] + 1) { bad++; console.log(`GENERACIÓN  ${P[p].n} (g${gen[p]}) -> ${P[id].n} (g${gen[id]})`) }
  }))
  ids.forEach((id) => {
    const c = ch(id); if (new Set(c.map((x) => gen[x])).size > 1) {
      bad++; console.log(`HERMANOS EN DISTINTA GENERACIÓN: ${c.map((x) => P[x].n).join(', ')}`) }
  })

  const yr = (id) => { const m = P[id].d?.match(/\d{4}/); return m ? +m[0] : null }
  const rango = {}
  ids.forEach((i) => { const y = yr(i); if (y == null) return
    ;(rango[gen[i]] ??= []).push(y) })
  const gs = Object.keys(rango).map(Number).sort((a, b) => a - b)
  for (let i = 1; i < gs.length; i++) {
    const antes = Math.min(...rango[gs[i - 1]]), ahora = Math.min(...rango[gs[i]])
    if (ahora < antes) { bad++; console.log(`AÑOS AL REVÉS: gen ${gs[i]} empieza en ${ahora}, antes que gen ${gs[i - 1]} en ${antes}`) }
  }
  console.log(`generaciones: ${gs.length} · ` + gs.map((k) => `g${k} ${Math.min(...rango[k])}–${Math.max(...rango[k])}`).join(' · '))
}
process.exit(bad ? 1 : 0)

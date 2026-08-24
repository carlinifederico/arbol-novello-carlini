/* Suma al árbol lo que aportó el acta n. 65 de Latisana, 1813. */
import { readFileSync, writeFileSync } from 'node:fs'

let d = readFileSync('datos.js', 'utf8')

const ANDREA = `andreaCag:{n:"Andrea Cagnolini",d:"~1779",b:"friuli",pa:["giuseppeCagPadre"],
  note:"El acta de nacimiento de su hija Elisabetta, de 1813, lo describe entero: treinta y cuatro años, POSSIDENTE —propietario, no campesino— y domiciliado en el Borgo dell'Annunziata de Latisana. Firmó el acta de puño y letra, cosa que encaja con su condición y que la mayoría de los presentantes de ese mismo registro no podía hacer: varias actas vecinas terminan con la fórmula «si dichiararono illetterati». Y sobre todo figura como «Andrea del fu Giuseppe Cagnolini», o sea que nombra a su propio padre.",
  f:[["Nacimiento","~1779","Derivado de los treinta y cuatro años declarados en junio de 1813."],
     ["Condición","Possidente"],
     ["Domicilio","Borgo dell'Annunziata, Latisana"],
     ["Sabía escribir","Firmó el acta de su hija"]],
  img:[["registros/latisana-nacimientos-1813-acta65-cagnolini.jpg","Latisana, Nati 1813, acta n. 65. Nombra a Andrea, a su padre Giuseppe, y a Marianna con su padre Angelo."],["registros/latisana-indice-1813-cagnolini.jpg","La tavola alfabetica de 1813, donde apareció la pista: «Cagnolini Elisabetta Catterina · Latisana · 11 giugno · atto 65»."]],
  url:"https://antenati.cultura.gov.it/ark:/12657/an_ua657391",
  c:[["Latisana 1813, Nati, atto n. 65","il Signor Andrea del fu Giuseppe Cagnolini, d'anni trentaquattro, possidente, domiciliato in questo Capoluogo nel Borgo dell'Annunziata"],
     ["Latisana, Morti 1879-1888"]]},
giuseppeCagPadre:{n:"Giuseppe Cagnolini",d:"~1750",b:"friuli",
  note:"La persona más antigua de todo el árbol. Aparece en el acta de 1813 de su nieta como «il fu Giuseppe», o sea que ya había muerto para entonces. De él no se sabe nada más todavía: su matrimonio caería alrededor de 1775, dentro de los registros parroquiales de Latisana, que no están indexados por nombre.",
  c:[["Latisana 1813, Nati, atto n. 65","Andrea del fu Giuseppe Cagnolini"]]},
angeloDonate:{n:"Angelo Donate",d:"~1752",b:"friuli",
  note:"Padre de Marianna. También «del fu» en 1813: ya había muerto. El apellido figura como Donate en el acta napoleónica y como Donati en los registros posteriores — la misma inestabilidad ortográfica de siempre.",
  c:[["Latisana 1813, Nati, atto n. 65","della Signora Marianna del fu Angelo Donate"]]},`

const MARIANNA = `mariannaDon:{n:"Marianna Donati",d:"~1782",b:"friuli",pa:["angeloDonate"],
  note:"«Marianna del fu Angelo Donate», treinta y un años en 1813, y también possidente por derecho propio — algo que no era habitual consignar de una mujer en un acta de la época.",
  f:[["Nacimiento","~1782","Derivado de los treinta y un años declarados en junio de 1813."],
     ["Condición","Possidente"],
     ["Variante del apellido","Donate en 1813, Donati después"]],
  c:[["Latisana 1813, Nati, atto n. 65","della Signora Marianna del fu Angelo Donate, d'anni trentuno, possidente"]]},`

const ELISABETTA = `elisabettaCag:{n:"Elisabetta Catterina Cagnolini",d:"1813 – 1881",b:"friuli",pa:["andreaCag","mariannaDon"],
  note:"Casada con Gio Batta Toppani. Una hija suya se llamó Santa Toppani: el nombre circula por las dos ramas de la familia mucho antes de llegar a Santa Cagnolini.",
  f:[["Nacimiento","10 de junio de 1813, a las cinco de la mañana, en el domicilio familiar del Borgo dell'Annunziata"],
     ["Nombres completos","Elisabetta e Catterina, según el acta"],
     ["Defunción","16 de junio de 1881"]],
  url:"https://antenati.cultura.gov.it/ark:/12657/an_ua657391",
  c:[["Latisana 1813, Nati, atto n. 65","un infante di sesso femminino, nata nel di lui domicilio il giorno di jeri alle ore cinque antemeridiane, cui furon posti li nomi di Elisabetta e Catterina"],
     ["Latisana, Morti, defunción 16-jun-1881"]]},`

const reemplazos = [
  [/andreaCag:\{[\s\S]*?\n(?=mariannaDon:)/, ANDREA + '\n'],
  [/mariannaDon:\{[\s\S]*?\n(?=carloCag:)/, MARIANNA + '\n'],
  [/elisabettaCag:\{[\s\S]*?\n(?=angeloCag:)/, ELISABETTA + '\n'],
]
for (const [re, con] of reemplazos) {
  if (!re.test(d)) { console.log('NO COINCIDE:', re.source.slice(0, 30)); process.exit(1) }
  d = d.replace(re, con)
}
writeFileSync('datos.js', d)

const P = eval('(' + d.match(/const P=(\{[\s\S]*\});/)[1] + ')')
console.log('personas:', Object.keys(P).length)
console.log('Andrea → padre:', (P.andreaCag.pa ?? []).join(', '))
console.log('Marianna → padre:', (P.mariannaDon.pa ?? []).join(', '))
console.log('nuevos:', ['giuseppeCagPadre', 'angeloDonate'].filter((k) => P[k]).join(', '))

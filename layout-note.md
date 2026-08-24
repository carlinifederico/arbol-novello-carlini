# Nota de diseño — por qué el árbol dejó de tener raíz

La primera versión mostraba **un pedigrí con raíz**: elegías una persona y el dibujo subía a sus
padres y abuelos. Es la forma clásica y es legible, pero tiene un defecto estructural que fue
apareciendo pedido tras pedido:

- Los hermanos Carlini estaban cargados y no se veían.
- Los hermanos de Liliana estaban cargados y no se veían.
- Los hermanos de Giovanni Fichera y los de Agata Castorina, lo mismo.

No era un problema de datos: en un pedigrí **los colaterales no entran por definición**. Cada vez
que se sumaba un tío o un hermano había que agregar otro "punto de entrada" al selector, y aun así
nunca se veía la familia junta.

## Lo que hace ahora

Un **layout global por generaciones**. No hay raíz: se dibuja todo el grafo de una vez.

1. **Generación de cada persona** = camino más largo desde cualquier antepasado sin padres
   conocidos. Así los primos quedan alineados aunque una rama tenga más generaciones documentadas
   que la otra.
2. **Orden dentro de cada generación** por recorrido en profundidad desde los troncos, de modo que
   los hermanos y sus descendencias queden contiguos y las líneas no se crucen de más.
3. **Barrido de baricentro**: cada persona se acomoda hacia el promedio de sus padres, y después se
   resuelven los solapamientos. Dos pasadas alcanzan para que el dibujo se ordene solo.

El árbol termina donde termina la familia: Antonio, Felipe y Facundo.

## Los cuatro estados de una persona

El color dice de qué rama viene. El **borde** dice qué tan firme es lo que sabemos:

| Estado | Cómo se ve | Qué significa |
|---|---|---|
| Documentado | borde sólido | hay un acta que lo prueba |
| Testimonio familiar | borde punteado gris | lo cuenta la familia, no hay papel todavía |
| Hipótesis | borde punteado ámbar + rótulo | deducción razonada, sin confirmar |
| Frontera | caja ámbar | ahí se corta la documentación |

Y los **vínculos** hipotéticos se dibujan punteados y rotulados, distintos de los documentados.
Esa distinción es lo único que separa un árbol genealógico de una lista de nombres plausibles.

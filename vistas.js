/* Las otras dos vistas: por dónde se movió la familia, y qué se aprendió.
   Se dibujan sobre el mismo lienzo del árbol, así que comparten pan y zoom. */

/* ── Lugares, con sus coordenadas reales ──
   No hay mapa de fondo —cargar tiles sería traer un servidor externo— así que
   se proyectan las coordenadas de verdad sobre dos recuadros. Las distancias
   relativas dentro de cada país son correctas; entre países, no: el océano se
   dibuja como un puente, que es lo que fue. */
const LUGARES = [
  // Friuli
  {id:'latisana', n:'Latisana',                lat:45.774, lon:13.001, pais:'it', rama:'friuli',
   nota:'Aquí nacen Luigi Novello y Liliana De Faccio, los dos en 1929.'},
  {id:'sgn',      n:'San Giorgio di Nogaro',   lat:45.828, lon:13.219, pais:'it', rama:'friuli',
   nota:'La familia De Faccio vive acá en 1953. Es donde se casan Luigi y Liliana.'},
  {id:'codroipo', n:'Codroipo',                lat:45.961, lon:12.976, pais:'it', rama:'friuli',
   nota:'De acá es la única Ida Morello indexada en toda la provincia. Sin confirmar.'},
  // Sicilia
  {id:'giarre',   n:'Giarre',                  lat:37.727, lon:15.184, pais:'it', rama:'sicilia',
   nota:'Nace Giovanni Fichera en 1869, jornalero del campo.'},
  {id:'acireale', n:'Acireale',                lat:37.612, lon:15.166, pais:'it', rama:'sicilia',
   nota:'Los Castorina y los Privitera. Acá se casan Giovanni y Agata en 1895, y acá está la Vía Galatea.'},
  {id:'genova',   n:'Génova',                  lat:44.406, lon:8.946,  pais:'it', rama:'puerto',
   nota:'El puerto de salida. Antonino Fichera embarcó solo; su mujer lo siguió dos años después.'},
  // Argentina
  {id:'baires',   n:'Puerto de Buenos Aires',  lat:-34.599, lon:-58.373, pais:'ar', rama:'puerto',
   nota:'Hotel de Inmigrantes. Los libros de desembarco 1882-1960 están digitalizados en CEMLA.'},
  {id:'bellavista',n:'Bella Vista',            lat:-34.573, lon:-58.686, pais:'ar', rama:'friuli',
   nota:'Los Novello. Luigi vivía en Las Heras y Lafinur ya en 1953, antes de casarse en Italia.'},
  {id:'mdp',      n:'Mar del Plata',           lat:-38.005, lon:-57.542, pais:'ar', rama:'sicilia',
   nota:'Los Fichera. Antonino fue dirigente gremial de la construcción y murió en un accidente de obra.'},
  {id:'sanmiguel',n:'San Miguel',              lat:-34.543, lon:-58.712, pais:'ar', rama:'comun',
   nota:'Donde las dos ramas se juntan: Aníbal y Patricia se casan en 1978.'},
];

/* ── Los movimientos, con lo que se sabe y lo que no ── */
const RUTAS = [
  {de:'giarre', a:'acireale', año:'1895', quien:'Giovanni Fichera',
   texto:'Se casa con Agata Castorina el 25 de julio. Ocho kilómetros de costa jónica, al pie del Etna.', firme:true},
  {de:'acireale', a:'genova', año:'~1920', quien:'Antonino Fichera',
   texto:'Cruza Italia entera hasta el puerto del norte. Mil quinientos kilómetros.', firme:false},
  {de:'genova', a:'baires', año:'~1920', quien:'Antonino Fichera',
   texto:'Viaja solo. La mujer lo sigue dos años después. El buque que recuerda la familia se llamaba «Francia», pero no pudo confirmarse que existiera en esa ruta.', firme:false},
  {de:'baires', a:'mdp', año:'~1920', quien:'Los Fichera',
   texto:'Se instalan en la ciudad que construyeron los sicilianos de esa misma costa.', firme:false},
  {de:'latisana', a:'sgn', año:'1953', quien:'Luigi Novello',
   texto:'Vuelve de Argentina a casarse con Liliana. Veinte kilómetros entre los dos pueblos.', firme:true},
  {de:'sgn', a:'baires', año:'1953', quien:'Luigi y Liliana',
   texto:'El acta de matrimonio se emite «per uso emigrazione» y ya lo registra como residente en Bella Vista: se había ido antes y volvió sólo para casarse.', firme:true},
  {de:'baires', a:'bellavista', año:'1953', quien:'Luigi y Liliana',
   texto:'Nunca se naturalizaron argentinos. Eso es lo que mantiene intacta la línea de ciudadanía hasta hoy.', firme:true},
  {de:'mdp', a:'sanmiguel', año:'1978', quien:'Aníbal Carlini',
   texto:'La rama siciliana se cruza con la friulana: se casa con Patricia Novello el 27 de octubre.', firme:true},
  {de:'bellavista', a:'sanmiguel', año:'1978', quien:'Patricia Novello',
   texto:'Dos migraciones que arrancaron a mil quinientos kilómetros una de otra terminan en el mismo partido.', firme:true},
];

/* ── Conclusiones: lo que se buscó, lo que se encontró, y lo que no está ── */
const HALLAZGOS = [
  {tipo:'hallazgo', t:'Los Cagnolini sí son de Latisana',
   b:'De 602 resultados, los de coincidencia exacta están todos en Latisana, y permiten reconstruir tres generaciones desde Andrea Cagnolini y Marianna Donati. Aparece además Santa Pinzani, con hijos entre 1867 y 1880: una nieta suya nacida hacia 1900 se habría llamado, por costumbre, Santa Cagnolini.'},
  {tipo:'hallazgo', t:'Sicilia llega hasta ~1810',
   b:'El acta civil de defunción de Antonino Castorina (1905) y el registro parroquial de su matrimonio (1860) coinciden en nombrar a sus padres: Salvatore Castorina y Angela Motta. El párroco escribió «Angilberga Motto» y el oficial civil «Angela Motta» — la misma persona, dos grafías. Por su generación, Angela Motta es la candidata natural a ser la antepasada de ~1812 a la que llegó Juan Lucero por su cuenta.'},
  {tipo:'hallazgo', t:'La regla onomástica confirma la reconstrucción',
   b:'La costumbre siciliana manda: primer varón por el abuelo paterno, segundo por el materno. Los abuelos eran Salvatore Castorina y Francesco Privitera; los hijos se llaman Salvatore y Francesco. Y en la otra rama, los hermanos que el testimonio familiar recordaba como Rosario y Antonino son exactamente los nombres que la regla predice. Que se cumpla sola, sin que nadie la forzara, es la mejor prueba de que la cadena está bien armada.'},
  {tipo:'hallazgo', t:'Agata viaja cuatro generaciones',
   b:'Agata Leonardi (~1818) → Agata Castorina (~1873) → y Haydée, que según el testimonio familiar fue bautizada Agata. El nombre baja por la rama femenina sin interrupción. Por eso la partida hay que pedirla a nombre de Agata Fichera, no de Haydée: todas las búsquedas por «Haydée» estaban condenadas de entrada.'},
  {tipo:'negativo', t:'Los Novello no estaban en Latisana',
   b:'En el índice decenal de matrimonios 1892-1901 el listado salta de Neri Virginia a Odorico Giovanni. En el de nacimientos, de Neri Teresa Maria a Olivier Antonio. Sin Novello, ni ninguna variante. Giovanni Novello no nació en Latisana y sus padres no se casaron ahí: la familia llegó después de 1902.'},
  {tipo:'negativo', t:'Tampoco en la provincia de Udine',
   b:'2.186 registros Novello en la provincia, repartidos en Manzano, San Vito di Fagagna, Santa Maria la Longa, Pozzuolo, Martignacco, Cividale — ninguno en Latisana. A nivel nacional el apellido se concentra en el Véneto, que empieza cruzando el Tagliamento, a cinco kilómetros de Latisana.'},
  {tipo:'muro', t:'El hueco 1901–1929',
   b:'Antenati termina en 1900. FamilySearch, para Udine, en 1911. Y lo que la familia ya tiene arranca en 1929. Los tres documentos que faltan —el nacimiento de Giovanni, el de Santa y el matrimonio de Giovanni con Ida— caen justo adentro. Ningún archivo online lo cubre: sólo los comuni y el Archivio di Stato, por correspondencia.'},
  {tipo:'muro', t:'Demasiados homónimos, no pocos registros',
   b:'La línea Fichera se frena en Rosario, y no por falta de papeles. En Acireale hay al menos cinco Rosario Fichera contemporáneos, cada uno casado con una María distinta; en Giarre, cuatro nacidos entre 1836 y 1844 con cuatro pares de padres diferentes. Al nuestro sólo lo distingue el apellido de su mujer, Bonaventura. Colgarle los padres del Rosario equivocado sería peor que dejar el árbol corto. Lo mismo pasa con los Castorina de Acireale.'},
  {tipo:'muro', t:'Los hermanos de Liliana',
   b:'Ivonne, Vilma, Franca y Giorgio nacieron entre 1925 y 1945, según lo que indican sus propios nombres — Vilma y Franca se popularizan en los años 30 y 40, e Ivonne es la forma francesa, llamativa bajo un régimen que italianizaba los nombres extranjeros. Ese rango cae de lleno en el hueco. Los registros argentinos tampoco tienen nada: los «De Faccio» que aparecen son «de Faccio» como partícula de casada.'},
  {tipo:'negativo', t:'El candidato de 1902 queda eliminado por su propia acta',
   b:'En la provincia de Venezia aparece un Giovanni Giuseppe Novello nacido el 4 de septiembre de 1902, hijo de Pietro Novello e Ida Dona. El nombre y el año calzaban perfecto. Pero su propia acta de defunción lo cierra: murió el 14 de junio de 1909, de siete años. No es el nuestro.'},
  {tipo:'hallazgo', t:'Sí hay Novello cruzando el río',
   b:'La hipótesis del Véneto se confirma en el lugar correcto. En Portogruaro —el comune inmediatamente al otro lado del Tagliamento desde Latisana, a cinco kilómetros— hay varias familias Novello entre 1878 y 1911: Andrea Novello con Elvira Turchetto, Andrea con Elisa Franchetto, Luigi con Orsola Pinaro, Pietro con Iolanda Gordini. Es exactamente el vecindario del que vendría una familia que después aparece en Latisana.'},
  {tipo:'muro', t:'Pero Giovanni no está indexado ahí tampoco',
   b:'En Portogruaro y San Michele al Tagliamento sólo figuran dos Giovanni Novello: uno nacido en 1878, veinticuatro años antes que el nuestro, y otro de 1892 que murió a los pocos meses. La colección de Venezia llega hasta 1930, así que un nacimiento de 1902 debería estar en rango: si no aparece, es que esos años no están indexados por nombre. Hay que navegar los registros de Portogruaro imagen por imagen, como se hizo con Latisana.'},
  {tipo:'proximo', t:'Y conviene dudar de la edad',
   b:'Los 52 años de Giovanni salen de una declaración en el acta de nacimiento de su nieta, en 1954. Las edades declaradas en actas son notoriamente aproximadas, y basta que se hubiera equivocado por cinco años para que toda la ventana de búsqueda esté corrida. Antes de barrer más registros conviene fijar su fecha con un documento propio: la lista di leva, o su acta de defunción argentina.'},
  {tipo:'proximo', t:'La vía que no depende de índices',
   b:'Las liste di leva del Archivio di Stato di Udine cubren hasta la clase 1944. La entrada de la clase 1902 nombraría al padre de Giovanni Novello y el apellido de soltera de su madre, más descripción física y oficio. El ruolo matricolare es aún mejor: anota residencia en el exterior, así que podría registrar literalmente su emigración a Argentina.'},
  {tipo:'proximo', t:'Un solo documento en vez de cinco partidas',
   b:'Para los hermanos De Faccio conviene pedir un stato di famiglia storico, que lista todo el hogar en una página con las fechas de nacimiento de cada hijo. A Latisana y a San Giorgio di Nogaro: la familia se mudó entre 1929 y 1953, y el registro puede estar en cualquiera de los dos. De paso resolvería a Santa Cagnolini.'},
  {tipo:'proximo', t:'El registro napoleónico de Latisana',
   b:'Andrea Cagnolini y Marianna Donati tuvieron hijos en 1808, 1813 y 1822. Los dos primeros caen dentro del stato civile napoleonico de Latisana, que SÍ está en Antenati: 51 registros, serie 657280. Esas actas describirían a Andrea con edad y oficio, y podrían nombrar a sus propios padres — es decir, la generación de 1750. Hay que navegarlas imagen por imagen, que es exactamente la técnica que destrabó el caso Cagnolini.'},
  {tipo:'proximo', t:'El libro de la Vía Galatea',
   b:'En la biblioteca de un museo de Acireale hay un libro sobre las familias de la calle donde vivían los Fichera, casi con seguridad la Biblioteca Zelantea de la Accademia degli Zelanti e dei Dafnici. Nadie lo consultó todavía; probablemente sea el mayor atajo de toda esta rama.'},
  {tipo:'proximo', t:'El acta de matrimonio Carlini × Fichera',
   b:'Sigue siendo el documento llave de la rama paterna: nombra a los cuatro abuelos y los dos lugares de nacimiento italianos. Mar del Plata, ~1945-1952. Y una corrección de enfoque: CARLINI no es apellido siciliano — se concentra en Marche, Umbría, Lazio, Emilia y Toscana. Buscarlo en Catania fue buscar en la provincia equivocada.'},
];

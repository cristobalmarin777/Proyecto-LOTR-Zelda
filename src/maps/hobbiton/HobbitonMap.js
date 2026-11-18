/**
 * HobbitonMap — Reconstrucción Jugable de HOBBITON (La Comarca) a Escala Cartográfica 1:5
 * basada en la topografía oficial de Hobbiton Movie Set (Matamata / Cartografía de La Comarca).
 *
 * ESCALA CARTOGRÁFICA 1:5:
 *  - Dimensiones reales de referencia del recinto de Hobbiton: 12.800 x 8.960 unidades (800m x 560m).
 *  - Reducción lineal uniforme 1:5 -> 2.560 x 1.792 píxeles (80 columnas x 56 filas de tiles de 32x32).
 *
 * DISTRIBUCIÓN GEOGRÁFICA FIEL AL MAPA DE REFERENCIA:
 *  1. NORTE CENTRAL (La Colina / The Hill):
 *     - Bolsón Cerrado (Bag End) en la cumbre norte (col 34, fila 4), coronado por el Gran Roble.
 *  2. LADERA BAJO LA COLINA (Bolsón de Tirada / Bagshot Row):
 *     - Hilera curva descendente de Smials hobbit tradicionales (incluyendo el Nº 3 de Sam Gamyi,
 *       el Smial Verde Clásico de la Referencia A y los Smials humildes y artesanales).
 *  3. VALLE CENTRAL (El Campo de la Fiesta y El Árbol de la Fiesta / Party Field & Party Tree):
 *     - Directamente al pie de la colina de Bolsón Cerrado (cols 27..39, filas 19..27),
 *       con el majestuoso Árbol de la Fiesta y el Pabellón del 111.º Cumpleaños.
 *  4. LADERA NORESTE / ESTE (Colinas Residenciales y Senderos de Hobbiton):
 *     - Viviendas hobbit acomodadas (Puerta Azul Real, Puerta de Roble) integradas en las laderas curvas.
 *  5. EL LAGO Y EL RÍO "EL AGUA" (The Water):
 *     - Fluye y se ensancha en el centro-sur del valle (filas 31..40), dividiendo las colinas
 *       norteñas de la ribera de Delagua y la Posada.
 *  6. EL PUENTE DE PIEDRA DE DOBLE ARCO Y EL VIEJO MOLINO (Sandyman's Mill):
 *     - En el estrechamiento occidental del lago (cols 19..25, filas 30..36), conectando el sendero
 *       del Campo de la Fiesta con la ribera sur.
 *  7. RIBERA SUROESTE (Posada El Dragón Verde / The Green Dragon Inn):
 *     - Cruzando el Puente de Piedra hacia el suroeste, frente al agua (cols 9..16, filas 38..43).
 *  8. CAMPOS AGRÍCOLAS Y CASAS RURALES DEL SUR (Referencia B):
 *     - Granjas de piedra, entramado de madera y tejados de paja dorada (Granja en L de la Referencia B,
 *       Cabañas Rurales y Graneros Auxiliares) junto a los huertos y cercos de madera.
 *  9. FRONTERA ORIENTAL (Bosque Viejo y Campamento Orco):
 *     - En el extremo sureste (cols 60..77), manteniendo toda la acción, combate y misiones del juego.
 */
import { TILE, SOLID_TILES } from '../../assets/SpriteAtlas.js';
import { BuildingCatalog } from '../../assets/buildings/BuildingCatalog.js';
import { EnvironmentAssets } from '../../assets/environment/EnvironmentAssets.js';

export class HobbitonMap {
  constructor() {
    // Dimensiones de referencia originales: 12800 x 8960 -> Escala 1:5 = 2560 x 1792 px (80x56 tiles)
    this.referenceWidth = 12800;
    this.referenceHeight = 8960;
    this.scaleRatio = 0.2; // 1:5 exacto

    this.cols = 80;
    this.rows = 56;
    this.tileSize = 32;
    this.width = this.cols * this.tileSize;   // 2560 px
    this.height = this.rows * this.tileSize;  // 1792 px

    this.catalog = new BuildingCatalog();
    this.envAssets = new EnvironmentAssets();

    this.grid = [];
    this.buildings = [];      // Edificios instanciados con Y-sorting y colisión propia
    this.sceneryProps = [];   // Árboles, arbustos y farolas con Y-sorting
    this.elevationLedges = []; // Terrazas/acantilados de tierra como en la Referencia B
    this.npcs = [];
    this.chests = [];
    this.signs = [];
    this.enemySpawns = [];

    // Puntos de interés geográficos para el HUD / Mapa Cartográfico 1:5
    this.landmarks = [
      { id: 'bag_end', name: 'Bolsón Cerrado (Bag End)', col: 35, row: 6 },
      { id: 'bagshot_row', name: 'Bolsón de Tirada (Bagshot Row)', col: 25, row: 13 },
      { id: 'party_tree', name: 'El Árbol de la Fiesta', col: 34, row: 21 },
      { id: 'party_field', name: 'La Plaza de la Fiesta', col: 34, row: 25 },
      { id: 'old_mill', name: 'El Viejo Molino', col: 20, row: 29 },
      { id: 'stone_bridge', name: 'El Puente de Piedra', col: 23, row: 35 },
      { id: 'the_water', name: 'El Lago de Hobbiton (El Agua)', col: 38, row: 35 },
      { id: 'green_dragon', name: 'Posada El Dragón Verde', col: 13, row: 41 },
      { id: 'rural_farms', name: 'Granjas Rurales y Campos', col: 36, row: 46 },
    ];

    this.buildLevel();
  }

  buildLevel() {
    // 1. Pradera verde natural de base
    for (let r = 0; r < this.rows; r++) {
      this.grid.push(new Array(this.cols).fill(TILE.GRASS));
    }

    // 2. Borde perimetral de bosque
    for (let c = 0; c < this.cols; c++) {
      this.grid[0][c] = TILE.TREE;
      this.grid[this.rows - 1][c] = TILE.TREE;
    }
    for (let r = 0; r < this.rows; r++) {
      this.grid[r][0] = TILE.TREE;
      this.grid[r][this.cols - 1] = TILE.TREE;
    }

    // 3. Frontera del Bosque Viejo al Este (cols 63..78) para mantener el combate y la misión
    for (let r = 2; r < this.rows - 2; r++) {
      for (let c = 63; c < this.cols - 1; c++) {
        const edgeJitter = Math.round(Math.sin(r * 0.4) * 2);
        if (c >= 64 + edgeJitter) {
          this.grid[r][c] = TILE.DARK_FOREST;
        }
      }
    }

    // 4. El Lago de Hobbiton y el Río "El Agua" (forma orgánica atravesando de oeste a este, filas 32..39)
    for (let c = 1; c < 64; c++) {
      const centerRow = Math.round(35 + Math.sin(c * 0.11) * 2.2);
      // El lago se ensancha en el centro (frente al Campo de la Fiesta, cols 27..48)
      const halfWidth = c >= 27 && c <= 49 ? 3.5 + Math.sin((c - 27) * 0.14) * 1.6 : 1.8;
      const rStart = Math.max(2, Math.floor(centerRow - halfWidth));
      const rEnd = Math.min(this.rows - 3, Math.ceil(centerRow + halfWidth));
      for (let r = rStart; r <= rEnd; r++) {
        this.grid[r][c] = TILE.WATER;
      }
    }

    // 5. Trazado de Caminos Curvos y Senderos Naturales (Sin cuadrículas rígidas)
    // A. Sendero serpenteante desde Bolsón Cerrado bajando por Bolsón de Tirada hasta la Plaza de la Fiesta
    this.paintCurvedPath([
      [35, 9], [31, 11], [26, 13], [24, 16], [27, 20], [32, 23], [34, 26],
    ], 2, TILE.DIRT_PATH);

    // B. Sendero de las Colinas Orientales (conecta Bolsón Cerrado con los Smials del Este y baja al lago)
    this.paintCurvedPath([
      [36, 9], [43, 11], [50, 14], [54, 19], [52, 25], [44, 28], [34, 26],
    ], 2, TILE.DIRT_PATH);

    // C. Camino desde la Plaza de la Fiesta hacia el Viejo Molino y el Puente de Piedra
    this.paintCurvedPath([
      [32, 26], [26, 28], [23, 31], [23, 39],
    ], 2, TILE.DIRT_PATH);

    // D. El Puente de Piedra de Doble Arco sobre El Agua (cols 22..24, filas 32..38)
    for (let r = 32; r <= 38; r++) {
      this.grid[r][22] = TILE.COBBLESTONE;
      this.grid[r][23] = TILE.BRIDGE;
      this.grid[r][24] = TILE.COBBLESTONE;
    }

    // E. Camino de la Ribera Sur: desde el Puente hacia la Posada El Dragón Verde (Oeste) y las Granjas Rurales (Este)
    this.paintCurvedPath([
      [23, 39], [18, 41], [13, 43], [9, 44],
    ], 2, TILE.DIRT_PATH);

    this.paintCurvedPath([
      [23, 39], [29, 42], [37, 44], [47, 45], [56, 43], [62, 36],
    ], 2, TILE.DIRT_PATH);

    // F. Segundo puente rústico oriental que cruza hacia el Bosque Viejo y el Gran Camino del Este
    for (let r = 31; r <= 37; r++) {
      this.grid[r][57] = TILE.BRIDGE;
      this.grid[r][58] = TILE.BRIDGE;
    }
    this.paintCurvedPath([
      [52, 25], [57, 29], [57, 38], [64, 38], [72, 42],
    ], 2, TILE.DIRT_PATH);

    // 6. La Plaza de la Fiesta (Party Field) — Explanada abierta con flores y hierba cuidada
    for (let r = 21; r <= 27; r++) {
      for (let c = 29; c <= 39; c++) {
        if ((r + c) % 5 === 0) {
          this.grid[r][c] = TILE.FLOWERS;
        }
      }
    }

    // 7. Huertos y Campos Agrícolas junto a las Casas Rurales del Sur
    this.paintRect(46, 26, 50, 33, TILE.CROP_FIELD);
    this.paintRect(47, 42, 51, 49, TILE.CROP_FIELD);
    // Cercos rústicos de madera rodeando los huertos de manera orgánica
    for (let c = 25; c <= 34; c++) {
      if (c !== 29 && c !== 30) this.grid[45][c] = TILE.FENCE;
    }
    for (let c = 41; c <= 50; c++) {
      if (c !== 45 && c !== 46) this.grid[46][c] = TILE.FENCE;
    }

    // 8. Terrazas de elevación / Pequeños barrancos de tierra (como en la parte inferior de la Referencia B)
    this.elevationLedges = [
      { x: 26 * 32, y: 10 * 32, w: 18 * 32, h: 22 },
      { x: 16 * 32, y: 17 * 32, w: 12 * 32, h: 20 },
      { x: 42 * 32, y: 16 * 32, w: 14 * 32, h: 20 },
      { x: 30 * 32, y: 49 * 32, w: 11 * 32, h: 22 },
    ];

    // =========================================================================
    // 9. DISTRIBUCIÓN DE VIVIENDAS DE HOBBITON (ESCALA 1:5 DEL MAPA OFICIAL)
    // =========================================================================

    // --- ZONA 1: LA COLINA (BOLSÓN CERRADO / BAG END) ---
    this.placeBuilding('bag_end', 35 * 32, 6.2 * 32, {
      title: 'Bolsón Cerrado (Bag End)',
      resident: 'Hogar de Bilbo y Frodo Bolsón',
      dialog: [
        '«En un agujero en el suelo, vivía un hobbit. No un agujero húmedo, sucio, repugnante... era un agujero-hobbit, y eso significa comodidad.»',
        'La icónica puerta circular verde esmeralda brilla con su pomo de latón en el centro exacto. Sobre la colina se alza el Gran Roble.',
      ],
    });

    // --- ZONA 2: BOLSÓN DE TIRADA (BAGSHOT ROW — Ladera escalonada bajo Bolsón Cerrado) ---
    this.placeBuilding('smial_sam', 24.5 * 32, 11.8 * 32, {
      title: 'Nº 3 de Bolsón de Tirada',
      resident: 'Hogar de Samsagaz Gamyi y el Viejo Tío Gamyi',
      dialog: [
        'Hogar de la familia Gamyi. El jardín rebosa de flores amarillas, patatas y calabazas recién regadas por Sam.',
      ],
    });

    this.placeBuilding('smial_green_classic', 17.5 * 32, 14.5 * 32, {
      title: 'Smial del Jardín Florido (Referencia A)',
      resident: 'Familia Cavada de Hobbiton',
      dialog: [
        'Una vivienda hobbit tradicional excavada en la colina, con sus escalones de losas grises, ventanas circulares en X y macetas en flor.',
      ],
    });

    this.placeBuilding('smial_humble_red', 12.5 * 32, 19.5 * 32, {
      title: 'Smial del Sendero Oeste',
      resident: 'Hogar de la familia Dospiés',
      dialog: [
        'Un pequeño y acogedor agujero hobbit de puerta carmesí orientado hacia la pradera occidental.',
      ],
    });

    // --- ZONA 3: LADERA ORIENTAL Y COLINAS DE HOBBITON ---
    this.placeBuilding('smial_wealthy_blue', 46.5 * 32, 10.5 * 32, {
      title: 'Smial de la Colina Oriental',
      resident: 'Familia Ceñidor',
      dialog: [
        'Una amplia vivienda hobbit de puerta azul real con vistas panorámicas a todo el valle de Hobbiton y al lago.',
      ],
    });

    this.placeBuilding('smial_oak_brown', 53.5 * 32, 16.5 * 32, {
      title: 'Smial del Robledal',
      resident: 'Taller del Tonelero de Hobbiton',
      dialog: [
        'La puerta circular de roble barnizado huele a madera recién tallada y hierba para pipa de la Cuaderna del Sur.',
      ],
    });

    this.placeBuilding('smial_green_classic', 49.5 * 32, 23.5 * 32, {
      title: 'Smial del Mirador del Lago',
      resident: 'Familia Madriguera',
      dialog: [
        'Desde los escalones de piedra de este smial se escucha el murmullo del río El Agua y la música de la Plaza de la Fiesta.',
      ],
    });

    this.placeBuilding('smial_humble_red', 41.5 * 32, 19.5 * 32, {
      title: 'Smial de la Ladera Media',
      resident: 'Familia Tejonera',
      dialog: [
        'Un agujero hobbit modesto rodeado de flores silvestres a medio camino entre Bolsón Cerrado y el Árbol de la Fiesta.',
      ],
    });

    // --- ZONA 4: EL CAMPO DE LA FIESTA Y EL ÁRBOL DE LA FIESTA (VALLE CENTRAL) ---
    this.placeBuilding('party_tree', 34.5 * 32, 20.2 * 32, {
      title: 'El Árbol de la Fiesta (The Party Tree)',
      resident: 'Corazón de Hobbiton',
      dialog: [
        'Bajo las enormes ramas de este árbol centenario, Bilbo Bolsón pronunció su famoso discurso de despedida en su 111.º cumpleaños.',
      ],
    });

    this.placeBuilding('party_tent', 29.0 * 32, 23.8 * 32, {
      title: 'Pabellón del Banquete de Cumpleaños',
      resident: 'Campo de la Fiesta',
      dialog: [
        'Las mesas siguen repletas de pasteles de miel, queso curado y jarras de cerveza fresca. ¡Te sientes lleno de energía!',
      ],
      healsPlayer: true,
    });

    // --- ZONA 5: EL VIEJO MOLINO Y EL PUENTE DE PIEDRA ---
    this.placeBuilding('old_mill', 19.2 * 32, 28.8 * 32, {
      title: 'El Viejo Molino de Arenas (Sandyman’s Mill)',
      resident: 'Ted Arenas, el Molinero',
      dialog: [
        'La gran rueda hidráulica gira impulsada por la corriente de El Agua, moliendo el trigo de los campos de La Comarca.',
      ],
    });

    // --- ZONA 6: RIBERA SUROESTE — POSADA EL DRAGÓN VERDE ---
    this.placeBuilding('green_dragon_inn', 12.8 * 32, 40.2 * 32, {
      title: 'Posada El Dragón Verde (The Green Dragon Inn)',
      resident: 'Taberna tradicional de Delagua y Hobbiton',
      dialog: [
        '«¡Puedes buscar por todas partes, pero no hallarás mejor cerveza que la de El Dragón Verde!»',
        'El calor de la chimenea de piedra y una jarra fresca restauran todos tus corazones de vida.',
      ],
      healsPlayer: true,
    });

    // --- ZONA 7: CASAS RURALES DE PIEDRA, MADERA Y TEJADO DE PAJA (REFERENCIA B) ---
    this.placeBuilding('rural_l_house', 36.5 * 32, 42.8 * 32, {
      title: 'Granja del Prado Sur (Referencia B)',
      resident: 'Granja de la familia Coto',
      dialog: [
        'Construcción rural tradicional de piedra y entramado de madera con tejado de paja dorada en L, chimenea de mampostería y escalera apoyada en el alero.',
      ],
    });

    this.placeBuilding('rural_cottage', 27.5 * 32, 43.2 * 32, {
      title: 'Cabaña del Puente Sur',
      resident: 'Casa del Guarda del Puente',
      dialog: [
        'Una acogedora cabaña de piedra y techo de paja situada junto al camino que viene del Puente de Doble Arco.',
      ],
    });

    this.placeBuilding('rural_stone_barn', 32.5 * 32, 48.8 * 32, {
      title: 'Granero de Piedra y Paja',
      resident: 'Almacén de Cosechas de los Coto',
      dialog: [
        'Un sólido granero auxiliar de piedra rústica y techo de paja donde se guardan las calabazas y el grano.',
      ],
    });

    this.placeBuilding('rural_cottage', 49.5 * 32, 43.0 * 32, {
      title: 'Alquería del Camino Este',
      resident: 'Granja del Granjero Maggot',
      dialog: [
        '¡Cuidado con los perros del Granjero Maggot si intentas llevarte sus setas o calabazas sin permiso!',
      ],
    });

    this.placeBuilding('rural_l_house', 8.5 * 32, 28.5 * 32, {
      title: 'Granja del Molino Oeste',
      resident: 'Vivienda de los Molineros',
      dialog: [
        'Casa rural con entramado de roble y tejado de paja dorada a orillas del arroyo occidental.',
      ],
    });

    // =========================================================================
    // 10. VEGETACIÓN Y ELEMENTOS AMBIENTALES CON Y-SORTING (Árboles, Arbustos, Farolas)
    // =========================================================================
    const oakPositions = [
      [29, 6], [41, 6], [20, 9], [14, 12], [29, 15], [40, 14], [56, 11],
      [15, 23], [24, 24], [44, 23], [56, 22], [10, 35], [16, 46], [23, 47],
      [40, 48], [53, 47], [46, 39],
    ];
    for (const [col, row] of oakPositions) {
      this.placeProp('shire_oak', col * 32, row * 32);
    }

    // Árboles otoñales rojizos/dorados (como el que flanquea la casa rural en la Referencia B)
    const autumnPositions = [
      [33.2, 43.5], [24.8, 43.6], [6.2, 29.0], [15.0, 15.2], [44.0, 11.2], [47.0, 43.5],
    ];
    for (const [col, row] of autumnPositions) {
      this.placeProp('autumn_tree', col * 32, row * 32);
    }

    // Arbustos en flor y farolas de camino
    const bushPositions = [
      [32, 9.5], [38, 9.5], [22, 13], [27, 13], [31, 21], [37, 21],
      [16, 41], [10, 41], [39, 44], [34, 44], [52, 18], [48, 25],
    ];
    for (const [col, row] of bushPositions) {
      this.placeProp('flower_bush', col * 32, row * 32);
    }

    const lanternPositions = [
      [34, 10], [26, 14], [32, 24], [22, 31], [22, 39], [15, 42], [35, 44], [56, 30],
    ];
    for (const [col, row] of lanternPositions) {
      this.placeProp('wooden_post_lantern', col * 32, row * 32);
    }

    // Hierba alta cortable y flores silvestres repartidas orgánicamente
    const flowerPatches = [
      [10, 10], [11, 10], [28, 11], [39, 11], [19, 17], [46, 14],
      [18, 43], [31, 41], [42, 42], [53, 41],
    ];
    for (const [col, row] of flowerPatches) {
      if (this.grid[row] && this.grid[row][col] === TILE.GRASS) {
        this.grid[row][col] = TILE.FLOWERS;
      }
    }

    this.paintRect(16, 26, 18, 29, TILE.TALL_GRASS);
    this.paintRect(26, 44, 28, 47, TILE.TALL_GRASS);
    this.paintRect(48, 17, 50, 21, TILE.TALL_GRASS);
    this.paintRect(19, 60, 23, 63, TILE.TALL_GRASS);

    // =========================================================================
    // 11. FRONTERA ORIENTAL: BOSQUE VIEJO Y CAMPAMENTO ORCO (JUGABILIDAD Y COMBATE)
    // =========================================================================
    this.paintRect(38, 66, 45, 75, TILE.DIRT_PATH);
    this.grid[41][71] = TILE.CAMPFIRE_ASH;

    // Obstáculos naturales en el Bosque Viejo
    const forestTrees = [
      [8, 66], [9, 66], [14, 70], [15, 70], [22, 67], [23, 67],
      [29, 72], [30, 72], [48, 68], [49, 68],
    ];
    for (const [r, c] of forestTrees) {
      this.grid[r][c] = TILE.TREE;
    }

    // =========================================================================
    // 12. NPCs DE HOBBITON
    // =========================================================================
    this.npcs = [
      {
        id: 'gandalf',
        name: 'Gandalf el Gris',
        col: 35,
        row: 10,
        hatColor: '#52627a',
        cloakColor: '#768496',
        dialog: [
          '¡Bienvenido a Hobbiton, mi querido joven aventurero! Nos encontramos justo frente a Bolsón Cerrado, en lo alto de La Colina.',
          'Observa cómo se extiende el valle: abajo tienes Bolsón de Tirada (Bagshot Row), el Árbol de la Fiesta y el Lago de El Agua.',
          'Cruzando el Puente de Piedra de Doble Arco junto al Viejo Molino llegarás a la Posada El Dragón Verde y a las Granjas Rurales.',
          'MISIÓN PRINCIPAL: Cuando hayas explorado Hobbiton, cruza el puente oriental hacia el Bosque Viejo (Este) y derrota al Capitán Uruk-hai.',
        ],
      },
      {
        id: 'sam',
        name: 'Samsagaz Gamyi',
        col: 25,
        row: 14,
        hatColor: '#8c5a2b',
        cloakColor: '#4b7a34',
        dialog: [
          '¡Buenos días! Este es el Nº 3 de Bolsón de Tirada, mi hogar y el de mi viejo Tío Gamyi.',
          'Si bajas por el sendero curvo llegarás al Árbol de la Fiesta, y más allá está el Viejo Molino donde guardé un cofre con un Arco Élfico.',
        ],
      },
      {
        id: 'bilbo',
        name: 'Bilbo Bolsón',
        col: 34,
        row: 23,
        hatColor: '#6e4726',
        cloakColor: '#8c2d38',
        dialog: [
          '¡Estoy ultimando los preparativos bajo el Árbol de la Fiesta! ¿Has visto qué bien lucen los farolillos y el pabellón?',
          'Recuerda que puedes pulsar [C] en cualquier momento para abrir el Catálogo de Arquitectura de Hobbiton y el Mapa Cartográfico 1:5.',
        ],
      },
      {
        id: 'rosie',
        name: 'Rosita Coto (Posada El Dragón Verde)',
        col: 13,
        row: 43,
        hatColor: '#d96b82',
        cloakColor: '#b84058',
        isHealer: true,
        dialog: [
          '¡Bienvenido a la Posada El Dragón Verde, a orillas del lago de Delagua!',
          'Toma una pinta fresca junto a la chimenea de piedra. ¡He restaurado todos tus corazones al máximo!',
        ],
      },
      {
        id: 'farmer_maggot',
        name: 'Granjero Coto',
        col: 36,
        row: 45,
        hatColor: '#a37b37',
        cloakColor: '#6b4922',
        dialog: [
          'En la ribera sur preferimos las casas rurales de piedra, entramado de roble y buen techo de paja dorada.',
          'Al este de nuestras tierras comienza el Bosque Viejo. ¡Ten cuidado con las arañas y los exploradores orcos!',
        ],
      },
    ];

    // =========================================================================
    // 13. COFRES DEL TESORO Y CARTELES DE ORIENTACIÓN
    // =========================================================================
    this.chests = [
      {
        id: 'chest_mill',
        col: 17,
        row: 31,
        opened: false,
        rewardType: 'bow_upgrade',
        title: 'Arco Corto de la Comarca + 15 Flechas',
        description: 'Hallado junto al Viejo Molino de Arenas. ¡Equípalo y dispara flechas con [Q]!',
      },
      {
        id: 'chest_rural_farm',
        col: 33,
        row: 51,
        opened: false,
        rewardType: 'potion_pack',
        title: '2 Frascos de Miruvor + 25 Monedas de Plata',
        description: 'Guardados junto al Granero de Piedra de las Granjas del Sur.',
      },
      {
        id: 'chest_east_smial',
        col: 55,
        row: 18,
        opened: false,
        rewardType: 'heart_container',
        title: 'Reliquia Hobbit (+1 Corazón Máximo)',
        description: '¡Tu salud máxima ha aumentado permanentemente y tus corazones se han restaurado!',
      },
      {
        id: 'chest_orc_camp',
        col: 74,
        row: 41,
        opened: false,
        rewardType: 'sword_temper',
        title: 'Hoja Élfica Templada (Dardo Brillante)',
        description: '¡El daño de tu espada ha aumentado permanentemente!',
      },
    ];

    this.signs = [
      {
        col: 33,
        row: 10,
        text: '⬆️ La Colina: BOLSÓN CERRADO (Bag End) | ↙️ BOLSÓN DE TIRADA (Bagshot Row) | ⬇️ EL ÁRBOL DE LA FIESTA',
      },
      {
        col: 25,
        row: 30,
        text: '⬅️ EL VIEJO MOLINO DE ARENAS | ⬇️ PUENTE DE PIEDRA DE DOBLE ARCO -> POSADA EL DRAGÓN VERDE',
      },
      {
        col: 35,
        row: 43,
        text: '🏡 GRANJAS RURALES DEL SUR (Arquitectura de piedra, entramado de madera y techo de paja) | ➡️ Este: Frontera del Bosque Viejo',
      },
      {
        col: 60,
        row: 36,
        text: '⚠️ PELIGRO: Frontera Oriental de La Comarca. Más allá de este puente acechan los Orcos y el Capitán Uruk-hai.',
      },
    ];

    // =========================================================================
    // 14. ENEMIGOS (En la Frontera Oriental / Bosque Viejo para no invadir las calles de Hobbiton)
    // =========================================================================
    this.enemySpawns = [
      { type: 'spider', col: 65, row: 14 },
      { type: 'orc', col: 68, row: 19 },
      { type: 'spider', col: 64, row: 27 },
      { type: 'orc', col: 66, row: 35 },
      { type: 'spider', col: 71, row: 32 },
      { type: 'orc', col: 67, row: 42 },
      { type: 'spider', col: 64, row: 47 },
      { type: 'uruk', col: 71, row: 41, isMiniBoss: true },
    ];
  }

  /**
   * Instancia un edificio del catálogo centrado horizontalmente en (worldX, worldY)
   */
  placeBuilding(catalogId, centerX, baseY, meta = {}) {
    const def = this.catalog.get(catalogId);
    if (!def) return;

    const topLeftX = Math.round(centerX - def.width / 2);
    const topLeftY = Math.round(baseY - def.sortYOffset);

    this.buildings.push({
      uid: `${catalogId}_${this.buildings.length}`,
      catalogId,
      def,
      x: topLeftX,
      y: topLeftY,
      sortY: topLeftY + def.sortYOffset,
      collisionBox: {
        x: topLeftX + def.collider.x,
        y: topLeftY + def.collider.y,
        w: def.collider.w,
        h: def.collider.h,
      },
      doorPoint: def.doorOffset
        ? {
            x: topLeftX + def.doorOffset.x,
            y: topLeftY + def.doorOffset.y,
          }
        : null,
      meta,
    });
  }

  placeProp(propId, centerX, baseY) {
    const def = this.envAssets.props[propId];
    if (!def) return;
    const topLeftX = Math.round(centerX - def.width / 2);
    const topLeftY = Math.round(baseY - def.sortYOffset);

    this.sceneryProps.push({
      propId,
      def,
      x: topLeftX,
      y: topLeftY,
      sortY: topLeftY + def.sortYOffset,
      collisionBox: {
        x: topLeftX + def.collider.x,
        y: topLeftY + def.collider.y,
        w: def.collider.w,
        h: def.collider.h,
      },
    });
  }

  paintCurvedPath(waypoints, radiusTiles = 1, tileId = TILE.DIRT_PATH) {
    for (let i = 0; i < waypoints.length - 1; i++) {
      const [c1, r1] = waypoints[i];
      const [c2, r2] = waypoints[i + 1];
      const steps = Math.max(Math.abs(c2 - c1), Math.abs(r2 - r1)) * 2;
      for (let s = 0; s <= steps; s++) {
        const t = steps === 0 ? 0 : s / steps;
        // Ligera curvatura sinusoidal para aspecto de sendero rural orgánico
        const wave = Math.sin(t * Math.PI) * 0.6;
        const cc = Math.round(c1 + (c2 - c1) * t + wave);
        const rr = Math.round(r1 + (r2 - r1) * t);
        this.paintRect(rr - radiusTiles + 1, cc - radiusTiles + 1, rr + radiusTiles - 1, cc + radiusTiles - 1, tileId);
      }
    }
  }

  paintRect(r1, c1, r2, c2, tileId) {
    for (let r = r1; r <= r2; r++) {
      for (let c = c1; c <= c2; c++) {
        if (r >= 1 && r < this.rows - 1 && c >= 1 && c < this.cols - 1) {
          if (this.grid[r][c] !== TILE.WATER && this.grid[r][c] !== TILE.BRIDGE) {
            this.grid[r][c] = tileId;
          }
        }
      }
    }
  }

  getTileAtPixel(px, py) {
    const col = Math.floor(px / this.tileSize);
    const row = Math.floor(py / this.tileSize);
    if (row < 0 || row >= this.rows || col < 0 || col >= this.cols) {
      return TILE.TREE;
    }
    return this.grid[row][col];
  }

  /**
   * Comprueba colisiones tanto con los tiles sólidos del terreno (agua, cercos, bosque denso)
   * como con los footprints de las viviendas de Hobbiton y los troncos de árboles con Y-sorting.
   */
  isRectBlocked(cx, cy, halfW, halfH) {
    const left = cx - halfW;
    const right = cx + halfW;
    const top = cy - halfH;
    const bottom = cy + halfH;

    // 1. Verificar las 4 esquinas contra la cuadrícula de tiles
    const corners = [
      [left, top],
      [right, top],
      [left, bottom],
      [right, bottom],
    ];
    for (const [px, py] of corners) {
      const tile = this.getTileAtPixel(px, py);
      if (SOLID_TILES.has(tile)) {
        return true;
      }
    }

    // 2. Verificar contra los colliders sólidos de todas las viviendas de Hobbiton
    for (const b of this.buildings) {
      const box = b.collisionBox;
      if (
        left < box.x + box.w &&
        right > box.x &&
        top < box.y + box.h &&
        bottom > box.y
      ) {
        return true;
      }
    }

    // 3. Verificar contra los troncos y arbustos de decoración con Y-sorting
    for (const p of this.sceneryProps) {
      const box = p.collisionBox;
      if (
        left < box.x + box.w &&
        right > box.x &&
        top < box.y + box.h &&
        bottom > box.y
      ) {
        return true;
      }
    }

    return false;
  }
}

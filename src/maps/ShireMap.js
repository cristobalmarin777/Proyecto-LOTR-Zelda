/**
 * ShireMap — Región inicial de LA COMARCA con la reconstrucción de HOBBITON a Escala Cartográfica 1:5
 * integrada en el mundo abierto procedural de la actualización, manteniendo la estética de árboles
 * de la actualización (TILE.TREE pixel art rectangular en capas).
 *
 * ESCALA CARTOGRÁFICA 1:5:
 *  - Recinto original de referencia de Hobbiton: 12.800 x 8.960 -> Escala 1:5 = 2.560 x 1.792 px (80x56 tiles).
 *  - Coordenadas de inicio del jugador frente a Bolsón Cerrado (Bag End): col 35, fila 9.
 *  - Mantiene todos los NPCs (incluyendo a Haldor el Armero y su Forja), cofres con ventana de botín,
 *    carteles, sistema de viviendas con Y-Sorting (Referencias A y B + Especiales) y la frontera del Bosque Viejo.
 */
import { TILE, SOLID_TILES } from '../assets/SpriteAtlas.js';
import { BuildingCatalog } from '../assets/buildings/BuildingCatalog.js';

export class ShireMap {
  constructor() {
    this.referenceWidth = 12800;
    this.referenceHeight = 8960;
    this.scaleRatio = 0.2; // Escala 1:5 exacta

    this.cols = 80;
    this.rows = 56;
    this.tileSize = 32;
    this.width = this.cols * this.tileSize;   // 2560 px
    this.height = this.rows * this.tileSize;  // 1792 px

    this.spawnCol = 35;
    this.spawnRow = 9.2;

    this.catalog = new BuildingCatalog();

    this.grid = [];
    this.buildings = [];
    this.elevationLedges = [];
    this.npcs = [];
    this.chests = [];
    this.signs = [];
    this.enemySpawns = [];

    this.landmarks = [
      { id: 'bag_end', name: 'Bolsón Cerrado (Bag End)', col: 35, row: 6 },
      { id: 'bagshot_row', name: 'Bolsón de Tirada (Bagshot Row)', col: 25, row: 13 },
      { id: 'party_tree', name: 'El Árbol de la Fiesta', col: 34, row: 21 },
      { id: 'party_field', name: 'La Plaza de la Fiesta', col: 34, row: 25 },
      { id: 'old_mill', name: 'El Viejo Molino y Forja', col: 20, row: 29 },
      { id: 'stone_bridge', name: 'El Puente de Piedra', col: 23, row: 35 },
      { id: 'the_water', name: 'El Lago de Hobbiton (El Agua)', col: 38, row: 35 },
      { id: 'green_dragon', name: 'Posada El Dragón Verde', col: 13, row: 41 },
      { id: 'rural_farms', name: 'Granjas Rurales y Campos', col: 36, row: 46 },
    ];

    this.buildLevel();
  }

  buildLevel() {
    // 1. Pradera verde base
    for (let r = 0; r < this.rows; r++) {
      this.grid.push(new Array(this.cols).fill(TILE.GRASS));
    }

    // 2. Borde perimetral (WorldGenerator ignora la fila/columna 0 y cols-1/rows-1 para conectar con el mundo infinito)
    for (let c = 0; c < this.cols; c++) {
      this.grid[0][c] = TILE.TREE;
      this.grid[this.rows - 1][c] = TILE.TREE;
    }
    for (let r = 0; r < this.rows; r++) {
      this.grid[r][0] = TILE.TREE;
      this.grid[r][this.cols - 1] = TILE.TREE;
    }

    // 3. Frontera del Bosque Viejo al Este (cols 63..78)
    for (let r = 1; r < this.rows - 1; r++) {
      for (let c = 63; c < this.cols - 1; c++) {
        const edgeJitter = Math.round(Math.sin(r * 0.4) * 2);
        if (c >= 64 + edgeJitter) {
          this.grid[r][c] = TILE.DARK_FOREST;
        }
      }
    }

    // 4. El Lago de Hobbiton y el Río "El Agua" (atraviesa el valle de oeste a este, filas 32..39)
    for (let c = 1; c < 64; c++) {
      const centerRow = Math.round(35 + Math.sin(c * 0.11) * 2.2);
      const halfWidth = c >= 27 && c <= 49 ? 3.5 + Math.sin((c - 27) * 0.14) * 1.6 : 1.8;
      const rStart = Math.max(2, Math.floor(centerRow - halfWidth));
      const rEnd = Math.min(this.rows - 3, Math.ceil(centerRow + halfWidth));
      for (let r = rStart; r <= rEnd; r++) {
        this.grid[r][c] = TILE.WATER;
      }
    }

    // 5. Senderos curvos orgánicos (fieles a la cartografía de Hobbiton 1:5)
    // A. De Bolsón Cerrado por Bolsón de Tirada hasta la Plaza de la Fiesta
    this.paintCurvedPath([
      [35, 9], [31, 11], [26, 13], [24, 16], [27, 20], [32, 23], [34, 26],
    ], 2, TILE.DIRT_PATH);

    // B. Sendero de las Colinas Orientales
    this.paintCurvedPath([
      [36, 9], [43, 11], [50, 14], [54, 19], [52, 25], [44, 28], [34, 26],
    ], 2, TILE.DIRT_PATH);

    // C. De la Plaza de la Fiesta al Viejo Molino y Puente de Piedra
    this.paintCurvedPath([
      [32, 26], [26, 28], [23, 31], [23, 39],
    ], 2, TILE.DIRT_PATH);

    // D. Puente de Piedra de Doble Arco (cols 22..24, filas 32..38)
    for (let r = 32; r <= 38; r++) {
      this.grid[r][22] = TILE.COBBLESTONE;
      this.grid[r][23] = TILE.BRIDGE;
      this.grid[r][24] = TILE.COBBLESTONE;
    }

    // E. Camino de la Ribera Sur hacia la Posada El Dragón Verde (Oeste) y las Granjas Rurales (Este) y salidas al mundo exterior
    this.paintCurvedPath([
      [23, 39], [18, 41], [13, 43], [6, 44], [1, 44],
    ], 2, TILE.DIRT_PATH);

    this.paintCurvedPath([
      [23, 39], [29, 42], [37, 44], [47, 45], [56, 43], [62, 36],
    ], 2, TILE.DIRT_PATH);

    // Salida sur hacia el mundo abierto
    this.paintCurvedPath([
      [37, 44], [37, 54],
    ], 2, TILE.DIRT_PATH);

    // F. Puente oriental hacia el Bosque Viejo y salida este hacia Bree / Mundo Abierto
    for (let r = 31; r <= 37; r++) {
      this.grid[r][57] = TILE.BRIDGE;
      this.grid[r][58] = TILE.BRIDGE;
    }
    this.paintCurvedPath([
      [52, 25], [57, 29], [57, 38], [64, 38], [72, 41], [78, 41],
    ], 2, TILE.DIRT_PATH);

    // 6. La Plaza de la Fiesta (Party Field)
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
    for (let c = 25; c <= 34; c++) {
      if (c !== 29 && c !== 30) this.grid[45][c] = TILE.FENCE;
    }
    for (let c = 41; c <= 50; c++) {
      if (c !== 45 && c !== 46) this.grid[46][c] = TILE.FENCE;
    }

    // 8. Terrazas naturales de elevación (Referencia B)
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
        '«En un agujero en el suelo, vivía un hobbit... era un agujero-hobbit, y eso significa comodidad.»',
        'La puerta circular verde esmeralda brilla con su pomo de latón en el centro exacto.',
      ],
    });

    // --- ZONA 2: BOLSÓN DE TIRADA (BAGSHOT ROW) ---
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

    // --- ZONA 4: EL CAMPO DE LA FIESTA Y EL ÁRBOL DE LA FIESTA ---
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
    // 10. ÁRBOLES DE HOBBITON — ESTÉTICA 100% DE LA ACTUALIZACIÓN (TILE.TREE)
    // =========================================================================
    const updateTreeCoords = [
      // Colinas del Norte y Bolsón Cerrado
      [28, 5], [29, 6], [41, 5], [42, 6], [20, 8], [21, 9], [14, 11], [15, 12],
      // Entre Bolsón de Tirada y las laderas
      [29, 15], [30, 15], [40, 14], [56, 11], [57, 12], [10, 16], [9, 17],
      // Alrededores del Campo de la Fiesta y el Lago
      [15, 23], [16, 24], [24, 24], [44, 23], [45, 24], [56, 22], [10, 34],
      // Ribera Sur, Posada El Dragón Verde y Granjas Rurales
      [6, 39], [7, 40], [17, 45], [18, 46], [23, 47], [24, 47],
      [33, 43], [40, 48], [41, 48], [47, 43], [53, 47], [54, 48], [46, 39],
      // Bosque Viejo al Este
      [66, 8], [66, 9], [70, 14], [70, 15], [67, 22], [67, 23],
      [72, 29], [72, 30], [68, 48], [68, 49], [74, 20], [75, 21],
    ];
    for (const [col, row] of updateTreeCoords) {
      if (row > 0 && row < this.rows - 1 && col > 0 && col < this.cols - 1) {
        this.grid[row][col] = TILE.TREE;
      }
    }

    // Rocas del Bosque Viejo
    const rocks = [
      [63, 12], [63, 13], [65, 25], [69, 34], [73, 45], [74, 45],
    ];
    for (const [col, row] of rocks) {
      this.grid[row][col] = TILE.ROCK;
    }

    // Flores y Hierba alta cortable (bordes de senderos al estilo Zelda ALTTP / Referencia)
    const flowerPatches = [
      [10, 10], [11, 10], [28, 11], [32, 8], [37, 8], [39, 11], [33, 12], [29, 13],
      [19, 17], [25, 18], [30, 22], [36, 22], [46, 14], [51, 16],
      [18, 43], [21, 40], [31, 41], [42, 42], [53, 41],
    ];
    for (const [col, row] of flowerPatches) {
      if (this.grid[row] && this.grid[row][col] === TILE.GRASS) {
        this.grid[row][col] = TILE.FLOWERS;
      }
    }

    this.paintRect(8, 28, 10, 31, TILE.TALL_GRASS);
    this.paintRect(11, 38, 13, 41, TILE.TALL_GRASS);
    this.paintRect(16, 26, 18, 29, TILE.TALL_GRASS);
    this.paintRect(26, 44, 28, 47, TILE.TALL_GRASS);
    this.paintRect(48, 17, 50, 21, TILE.TALL_GRASS);
    this.paintRect(19, 60, 23, 62, TILE.TALL_GRASS);

    // 11. Campamento Orco en la frontera oriental (cols 67..75, filas 38..44)
    this.paintRect(38, 67, 44, 75, TILE.DIRT_PATH);
    this.grid[41][71] = TILE.CAMPFIRE_ASH;

    // 12. NPCs de Hobbiton (incluyendo a Haldor el Armero de la actualización)
    this.npcs = [
      {
        id: 'gandalf',
        name: 'Gandalf el Gris',
        col: 35,
        row: 10,
        hatColor: '#52627a',
        cloakColor: '#768496',
        dialog: [
          '¡Ah, joven montaraz! Nos encontramos frente a Bolsón Cerrado, en lo alto de La Colina de Hobbiton (Escala 1:5).',
          'Abajo se extienden Bolsón de Tirada, el Árbol de la Fiesta, el Viejo Molino, el Puente de Piedra y la Posada El Dragón Verde.',
          'MISIÓN PRINCIPAL: Cruza el puente oriental hacia el Bosque Viejo (Este), derrota al Capitán Uruk-hai en su campamento y recupera el Mapa de Arnor.',
          'Recuerda: pulsa [M] para abrir el Atlas del Viajero con Niebla de Guerra y [C] para ver el Catálogo Arquitectónico de Hobbiton.',
        ],
      },
      {
        id: 'sam',
        name: 'Sam Gamyi',
        col: 25,
        row: 14,
        hatColor: '#8c5a2b',
        cloakColor: '#4b7a34',
        dialog: [
          '¡Buenos días, señor! Este es el Nº 3 de Bolsón de Tirada, mi hogar.',
          'He guardado un cofre con un Arco Corto y flechas junto al Viejo Molino de Agua, al suroeste del Árbol de la Fiesta. ¡Ábrelo con [E]!',
        ],
      },
      {
        id: 'shire_smith',
        name: 'Haldor el Armero',
        col: 22,
        row: 29,
        hatColor: '#667078',
        cloakColor: '#704b2b',
        isMerchant: true,
        dialog: [],
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
          '¡Bienvenido a la Posada El Dragón Verde, frente al lago de El Agua!',
          'He vendado tus heridas y servido una pinta fresca. ¡Tus corazones de vida han sido restaurados al máximo!',
        ],
      },
      {
        id: 'farmer_maggot',
        name: 'Granjero Maggot',
        col: 37,
        row: 45,
        hatColor: '#a37b37',
        cloakColor: '#6b4922',
        dialog: [
          '¡Esos malditos trasgos rondan al este de nuestras Granjas Rurales!',
          'Si sigues el camino hacia el este o el sur saldrás de Hobbiton hacia las tierras salvajes de Eriador y las cuevas.',
        ],
      },
    ];

    // 13. Cofres del escenario
    this.chests = [
      {
        id: 'chest_mill',
        col: 17,
        row: 31,
        opened: false,
        rewardType: 'bow_upgrade',
        title: 'Arco Corto de la Comarca + 15 Flechas',
        description: '¡Ahora puedes equipar el Arco en el inventario [I] y disparar flechas con [Q]!',
      },
      {
        id: 'chest_gardens',
        idName: 'Cofre de las Granjas',
        col: 33,
        row: 51,
        opened: false,
        rewardType: 'potion_pack',
        title: '2 Panes de Lembas / Pociones de Miruvor + 25 Monedas',
        description: 'Restauran corazones cuando las usas con [Q].',
      },
      {
        id: 'chest_forest_north',
        col: 55,
        row: 18,
        opened: false,
        rewardType: 'heart_container',
        title: 'Contenedor de Corazón Dúnedain (+1 Corazón Máximo)',
        description: '¡Tu salud máxima ha aumentado permanentemente y te has curado al completo!',
      },
      {
        id: 'chest_orc_camp',
        col: 74,
        row: 41,
        opened: false,
        rewardType: 'sword_temper',
        title: 'Hoja Élfica Templada (Dardo Brillante)',
        description: '¡El daño de tu ataque con espada ha aumentado permanentemente!',
      },
    ];

    // 14. Carteles informativos
    this.signs = [
      {
        col: 33,
        row: 10,
        text: '⬆️ La Colina: BOLSÓN CERRADO (Bag End) | ↙️ BOLSÓN DE TIRADA (Bagshot Row) | ⬇️ EL ÁRBOL DE LA FIESTA',
      },
      {
        col: 25,
        row: 30,
        text: '⬅️ EL VIEJO MOLINO Y FORJA DE HALDOR | ⬇️ PUENTE DE PIEDRA -> POSADA EL DRAGÓN VERDE',
      },
      {
        col: 35,
        row: 43,
        text: '🏡 GRANJAS RURALES DEL SUR (Tejados de paja y entramado de madera) | ➡️ Este: Frontera del Bosque Viejo',
      },
      {
        col: 60,
        row: 37,
        text: '⚠️ PELIGRO: Frontera del Bosque Viejo. Más allá de este puente se extiende el mundo abierto y el campamento Uruk-hai.',
      },
    ];

    // 15. Spawns de Enemigos en la frontera oriental de La Comarca
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

  paintCurvedPath(waypoints, radiusTiles = 1, tileId = TILE.DIRT_PATH) {
    for (let i = 0; i < waypoints.length - 1; i++) {
      const [c1, r1] = waypoints[i];
      const [c2, r2] = waypoints[i + 1];
      const steps = Math.max(Math.abs(c2 - c1), Math.abs(r2 - r1)) * 2;
      for (let s = 0; s <= steps; s++) {
        const t = steps === 0 ? 0 : s / steps;
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
        if (r >= 0 && r < this.rows && c >= 0 && c < this.cols) {
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

  isBuildingBlocked(cx, cy, halfW, halfH) {
    const left = cx - halfW;
    const right = cx + halfW;
    const top = cy - halfH;
    const bottom = cy + halfH;

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
    return false;
  }

  isRectBlocked(cx, cy, halfW, halfH) {
    const points = [
      [cx - halfW, cy - halfH],
      [cx + halfW, cy - halfH],
      [cx - halfW, cy + halfH],
      [cx + halfW, cy + halfH],
    ];
    for (const [px, py] of points) {
      const tile = this.getTileAtPixel(px, py);
      if (SOLID_TILES.has(tile)) {
        return true;
      }
    }
    return this.isBuildingBlocked(cx, cy, halfW, halfH);
  }
}

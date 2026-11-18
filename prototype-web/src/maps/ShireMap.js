/**
 * ShireMap — Diseño de niveles para la REGIÓN 1: LA COMARCA (48x34 tiles = 1536x1088 px).
 * Incluye:
 *  - Bolsón Cerrado (Noroeste) + Casa del Protagonista y Jardines
 *  - Pueblo de Delagua, Huertos Hobbit y Posada del Dragón Verde (Suroeste)
 *  - Río El Agua cruzando de Norte a Sur con dos puentes
 *  - El Viejo Molino de Arenas (Centro-Norte)
 *  - El Bosque Viejo y Campamento de Exploradores Orcos (Este / Sureste)
 *  - Camino del Este hacia Bree (Salida bloqueada hasta derrotar al Capitán Uruk-hai)
 */
import { TILE, SOLID_TILES } from '../assets/SpriteAtlas.js';

export class ShireMap {
  constructor() {
    this.cols = 48;
    this.rows = 34;
    this.tileSize = 32;
    this.width = this.cols * this.tileSize;
    this.height = this.rows * this.tileSize;

    this.grid = [];
    this.npcs = [];
    this.chests = [];
    this.signs = [];
    this.enemySpawns = [];

    this.buildLevel();
  }

  buildLevel() {
    // 1. Inicializar todo con pradera verde
    for (let r = 0; r < this.rows; r++) {
      const row = new Array(this.cols).fill(TILE.GRASS);
      this.grid.push(row);
    }

    // 2. Borde perimetral de árboles frondosos
    for (let c = 0; c < this.cols; c++) {
      this.grid[0][c] = TILE.TREE;
      this.grid[this.rows - 1][c] = TILE.TREE;
    }
    for (let r = 0; r < this.rows; r++) {
      this.grid[r][0] = TILE.TREE;
      this.grid[r][this.cols - 1] = TILE.TREE;
    }

    // 3. Bosques densos en el Este (El Bosque Viejo / Frontera de los Orcos)
    for (let r = 1; r < this.rows - 1; r++) {
      for (let c = 31; c < this.cols - 1; c++) {
        this.grid[r][c] = TILE.DARK_FOREST;
      }
    }

    // 4. Río "El Agua" (cruza de norte a sur alrededor de la columna 24-26)
    for (let r = 1; r < this.rows - 1; r++) {
      const bend = Math.round(Math.sin(r * 0.25) * 1.2);
      const riverCol = 25 + bend;
      this.grid[r][riverCol] = TILE.WATER;
      this.grid[r][riverCol + 1] = TILE.WATER;
    }

    // 5. Caminos principales de tierra (Bolsón Cerrado -> Delagua -> Puente -> Bosque Viejo -> Camino de Bree)
    this.paintRect(8, 2, 9, 24, TILE.DIRT_PATH); // Camino horizontal norte
    this.paintRect(8, 12, 24, 13, TILE.DIRT_PATH); // Bajada a Delagua
    this.paintRect(16, 4, 17, 45, TILE.DIRT_PATH); // Gran Camino del Este
    this.paintRect(24, 8, 25, 22, TILE.DIRT_PATH); // Camino sur de las granjas
    this.paintRect(9, 28, 28, 29, TILE.DIRT_PATH); // Sendero del Bosque Viejo

    // 6. Puentes sobre El Agua
    this.paintRect(8, 23, 9, 28, TILE.BRIDGE); // Puente del Molino (Norte)
    this.paintRect(16, 23, 17, 28, TILE.BRIDGE); // Puente de Delagua (Centro)

    // 7. Colina de Bolsón Cerrado (Smial del Protagonista y Bilbo, Noroeste)
    this.paintRect(3, 3, 5, 10, TILE.HOBBIT_WALL);
    this.grid[5][6] = TILE.HOBBIT_DOOR;
    this.paintRect(6, 6, 8, 7, TILE.COBBLESTONE);
    // Vallas del jardín de Bolsón Cerrado
    for (let c = 2; c <= 11; c++) {
      if (c !== 6 && c !== 7) this.grid[7][c] = TILE.FENCE;
    }
    this.grid[4][2] = TILE.FLOWERS;
    this.grid[6][4] = TILE.FLOWERS;
    this.grid[6][9] = TILE.FLOWERS;

    // 8. Segundo Smial Hobbit (Casa de Sam Gamyi, Oeste)
    this.paintRect(12, 3, 13, 8, TILE.HOBBIT_WALL);
    this.grid[13][5] = TILE.HOBBIT_DOOR;
    this.paintRect(14, 5, 16, 6, TILE.DIRT_PATH);

    // 9. Posada "El Dragón Verde" y Mercado de Delagua (Centro-Oeste)
    this.paintRect(11, 15, 13, 21, TILE.HOBBIT_WALL);
    this.grid[13][18] = TILE.HOBBIT_DOOR;
    this.paintRect(14, 17, 15, 19, TILE.COBBLESTONE);

    // 10. El Viejo Molino junto al río (Norte-Centro)
    this.paintRect(3, 20, 5, 23, TILE.MILL_BASE);
    this.grid[5][21] = TILE.HOBBIT_DOOR;

    // 11. Huertos de calabazas de Maggot (Suroeste)
    this.paintRect(20, 4, 23, 10, TILE.CROP_FIELD);
    this.paintRect(20, 15, 23, 21, TILE.CROP_FIELD);
    for (let c = 3; c <= 11; c++) {
      if (c !== 7) this.grid[19][c] = TILE.FENCE;
    }

    // 12. Decoración de Flores, Hierba Alta y Árboles en La Comarca
    const flowerSpots = [
      [3, 13], [4, 14], [10, 4], [10, 9], [18, 14], [26, 6], [27, 18], [15, 22],
    ];
    flowerSpots.forEach(([r, c]) => {
      this.grid[r][c] = TILE.FLOWERS;
    });

    const tallGrassPatches = [
      [9, 15, 10, 19],
      [26, 8, 29, 16],
      [4, 29, 7, 33],
      [19, 29, 23, 33],
    ];
    tallGrassPatches.forEach(([r1, c1, r2, c2]) => {
      this.paintRect(r1, c1, r2, c2, TILE.TALL_GRASS);
    });

    // Árboles y rocas que forman laberintos naturales en el Bosque Viejo (Este)
    const treeClusters = [
      [2, 16], [2, 17], [6, 15], [10, 22], [19, 12], [27, 4], [28, 5], [29, 21],
      // Murallas de bosque en el Este
      [3, 35], [4, 35], [5, 35], [6, 35],
      [11, 32], [12, 32], [13, 32],
      [12, 38], [13, 38], [14, 38],
      [19, 34], [20, 34], [21, 34],
      [23, 39], [24, 39], [25, 39],
      [7, 42], [8, 42], [9, 42],
      [28, 33], [29, 33], [30, 33],
    ];
    treeClusters.forEach(([r, c]) => {
      this.grid[r][c] = TILE.TREE;
    });

    const rocks = [
      [3, 28], [4, 28], [14, 31], [18, 31], [22, 27], [26, 36], [27, 36],
      [10, 40], [11, 40], [20, 43], [21, 43],
    ];
    rocks.forEach(([r, c]) => {
      this.grid[r][c] = TILE.ROCK;
    });

    // 13. Campamento de Orcos en el claro sureste del Bosque Viejo
    this.paintRect(25, 38, 29, 44, TILE.DIRT_PATH);
    this.grid[27][41] = TILE.CAMPFIRE_ASH;

    // 14. Definir NPCs de La Comarca
    this.npcs = [
      {
        id: 'gandalf',
        name: 'Gandalf el Gris',
        col: 8,
        row: 7,
        hatColor: '#52627a',
        cloakColor: '#768496',
        dialog: [
          '¡Ah, joven montaraz! Menos mal que estás despierto en Bolsón Cerrado.',
          'Exploradores Orcos y Arañas del Bosque Viejo han cruzado el Río El Agua hacia el este.',
          'MISIÓN PRINCIPAL: Cruza el puente hacia el Bosque Viejo, derrota al Capitán Uruk-hai en su campamento al sureste y recupera el Mapa de Arnor.',
          'Recuerda: pulsa [ESPACIO] para blandir tu espada, [Q] para usar el objeto equipado y [I] para abrir tu inventario.',
        ],
      },
      {
        id: 'sam',
        name: 'Sam Gamyi',
        col: 6,
        row: 14,
        hatColor: '#8c5a2b',
        cloakColor: '#4b7a34',
        dialog: [
          '¡Buenos días, señor! He visto criaturas feas rondando cerca del Viejo Molino al norte.',
          'He guardado un cofre con un Arco Élfico y flechas junto al Molino de Agua. ¡Ábrelo pulsando [E]!',
        ],
      },
      {
        id: 'rosie',
        name: 'Rosita Coto (Posada El Dragón Verde)',
        col: 18,
        row: 14,
        hatColor: '#d96b82',
        cloakColor: '#b84058',
        isHealer: true,
        dialog: [
          '¡Bienvenido a la Posada El Dragón Verde de Delagua!',
          'He vendado tus heridas y servido una pinta fresca. ¡Tus corazones de vida han sido restaurados al máximo!',
        ],
      },
      {
        id: 'farmer_maggot',
        name: 'Granjero Maggot',
        col: 11,
        row: 21,
        hatColor: '#a37b37',
        cloakColor: '#6b4922',
        dialog: [
          '¡Esos malditos trasgos han pisoteado mis calabazas premiadas!',
          'Al otro lado del puente del este empieza el Bosque Viejo. No entres sin antes recoger pociones y el arco.',
        ],
      },
      {
        id: 'shire_smith',
        name: 'Haldor el Armero',
        col: 15,
        row: 10,
        hatColor: '#667078',
        cloakColor: '#704b2b',
        isMerchant: true,
        dialog: [],
      },
    ];

    // 15. Cofres del escenario
    this.chests = [
      {
        id: 'chest_mill',
        col: 21,
        row: 6,
        opened: false,
        rewardType: 'bow_upgrade',
        title: 'Arco Corto de la Comarca + 15 Flechas',
        description: '¡Ahora puedes equipar el Arco en el inventario [I] y disparar flechas con [Q]!',
      },
      {
        id: 'chest_gardens',
        idName: 'Cofre de Maggot',
        col: 4,
        row: 25,
        opened: false,
        rewardType: 'potion_pack',
        title: '2 Panes de Lembas / Pociones de Miruvor + 25 Monedas',
        description: 'Restauran corazones cuando las usas con [Q].',
      },
      {
        id: 'chest_forest_north',
        col: 39,
        row: 4,
        opened: false,
        rewardType: 'heart_container',
        title: 'Contenedor de Corazón Dúnedain (+1 Corazón Máximo)',
        description: '¡Tu salud máxima ha aumentado permanentemente y te has curado al completo!',
      },
      {
        id: 'chest_orc_camp',
        col: 44,
        row: 27,
        opened: false,
        rewardType: 'sword_temper',
        title: 'Hoja Élfica Templada (Dardo Brillante)',
        description: '¡El daño de tu ataque con espada ha aumentado permanentemente!',
      },
    ];

    // 16. Carteles informativos
    this.signs = [
      {
        col: 13,
        row: 9,
        text: '⬅️ Oeste: Colina de Bolsón Cerrado | ⬇️ Sur: Pueblo de Delagua y Posada El Dragón Verde | ➡️ Este: Puente del Agua',
      },
      {
        col: 29,
        row: 15,
        text: '⚠️ PELIGRO: Frontera del Bosque Viejo. Se han avistado Arañas Gigantes y Exploradores Orcos al este del río.',
      },
      {
        col: 45,
        row: 16,
        text: '➡️ Gran Camino del Este hacia BREE y las RUINAS DE ARNOR (Se desbloquea tras derrotar al Capitán Uruk-hai del campamento sureste).',
      },
    ];

    // 17. Spawns de Enemigos (3 tipos: Orco Explorador, Araña del Bosque Viejo, Capitán Uruk-hai)
    this.enemySpawns = [
      // Escaramuzadores cerca del río y praderas del este
      { type: 'orc', col: 19, row: 9 },
      { type: 'spider', col: 17, row: 26 },
      { type: 'orc', col: 22, row: 28 },

      // Bosque Viejo Norte
      { type: 'spider', col: 32, row: 6 },
      { type: 'spider', col: 36, row: 8 },
      { type: 'orc', col: 41, row: 6 },

      // Camino central del Bosque Viejo
      { type: 'orc', col: 33, row: 16 },
      { type: 'spider', col: 37, row: 19 },
      { type: 'orc', col: 42, row: 15 },

      // Campamento Orco del Sureste (Custodiado por el Capitán Uruk-hai)
      { type: 'orc', col: 36, row: 26 },
      { type: 'spider', col: 35, row: 30 },
      { type: 'uruk', col: 41, row: 27, isMiniBoss: true },
    ];
  }

  paintRect(r1, c1, r2, c2, tileId) {
    for (let r = r1; r <= r2; r++) {
      for (let c = c1; c <= c2; c++) {
        if (r >= 0 && r < this.rows && c >= 0 && c < this.cols) {
          this.grid[r][c] = tileId;
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
    return false;
  }
}

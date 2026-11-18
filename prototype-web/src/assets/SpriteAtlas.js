/**
 * SpriteAtlas — Generador procedural de Pixel Art 16-bit (estilo SNES / Zelda ALTTP).
 * Genera tilesets de 32x32 y sprites de personajes/enemigos en memoria en alta nitidez pixelada.
 */

export const TILE = {
  GRASS: 0,
  TALL_GRASS: 1,
  FLOWERS: 2,
  DIRT_PATH: 3,
  COBBLESTONE: 4,
  WATER: 5,
  BRIDGE: 6,
  TREE: 7,
  FENCE: 8,
  ROCK: 9,
  HOBBIT_WALL: 10,
  HOBBIT_DOOR: 11,
  CROP_FIELD: 12,
  DARK_FOREST: 13,
  MILL_BASE: 14,
  CAMPFIRE_ASH: 15,
};

export const SOLID_TILES = new Set([
  TILE.WATER,
  TILE.TREE,
  TILE.FENCE,
  TILE.ROCK,
  TILE.HOBBIT_WALL,
  TILE.MILL_BASE,
]);

function makeCanvas(w, h) {
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  const ctx = c.getContext('2d');
  ctx.imageSmoothingEnabled = false;
  return { c, ctx };
}

function px(ctx, x, y, w, h, color) {
  ctx.fillStyle = color;
  ctx.fillRect(x, y, w, h);
}

export class SpriteAtlas {
  constructor() {
    this.tiles = {};
    this.waterFrames = [];
    this.generateTiles();
  }

  generateTiles() {
    // 0: GRASS (Pradera de La Comarca)
    this.tiles[TILE.GRASS] = this.createGrassTile('#478932', '#529b3b', '#3a7527');

    // 1: TALL_GRASS (Hierba alta explorable)
    this.tiles[TILE.TALL_GRASS] = this.createTallGrassTile();

    // 2: FLOWERS (Flores silvestres de Delagua)
    this.tiles[TILE.FLOWERS] = this.createFlowerTile();

    // 3: DIRT_PATH (Camino de tierra de La Comarca)
    this.tiles[TILE.DIRT_PATH] = this.createDirtTile();

    // 4: COBBLESTONE (Empedrado antiguo / Puente)
    this.tiles[TILE.COBBLESTONE] = this.createCobbleTile();

    // 5: WATER (Río El Agua con 2 frames de animación)
    this.waterFrames = [this.createWaterTile(0), this.createWaterTile(1)];
    this.tiles[TILE.WATER] = this.waterFrames[0];

    // 6: BRIDGE (Puente de madera sobre el río)
    this.tiles[TILE.BRIDGE] = this.createBridgeTile();

    // 7: TREE (Árbol frondoso estilo Zelda ALTTP)
    this.tiles[TILE.TREE] = this.createTreeTile(false);

    // 8: FENCE (Valla de madera hobbit)
    this.tiles[TILE.FENCE] = this.createFenceTile();

    // 9: ROCK (Peñasco de piedra)
    this.tiles[TILE.ROCK] = this.createRockTile();

    // 10: HOBBIT_WALL (Colina / Smial Hobbit con techo de hierba y fachada)
    this.tiles[TILE.HOBBIT_WALL] = this.createHobbitWallTile();

    // 11: HOBBIT_DOOR (Puerta redonda verde/amarilla de Bolsón Cerrado)
    this.tiles[TILE.HOBBIT_DOOR] = this.createHobbitDoorTile();

    // 12: CROP_FIELD (Huerto hobbit con calabazas)
    this.tiles[TILE.CROP_FIELD] = this.createCropTile();

    // 13: DARK_FOREST (Suelo del Bosque Viejo al este)
    this.tiles[TILE.DARK_FOREST] = this.createGrassTile('#2b5228', '#335f2f', '#1f3f1d');

    // 14: MILL_BASE (Muro de piedra del Viejo Molino)
    this.tiles[TILE.MILL_BASE] = this.createMillWallTile();

    // 15: CAMPFIRE_ASH (Tierra quemada de campamento orco)
    this.tiles[TILE.CAMPFIRE_ASH] = this.createCampTile();
  }

  createGrassTile(base, light, dark) {
    const { c, ctx } = makeCanvas(32, 32);
    px(ctx, 0, 0, 32, 32, base);
    // Detalles de briznas 16-bit
    const blades = [
      [4, 6], [18, 4], [26, 12], [8, 22], [22, 26], [14, 15],
    ];
    blades.forEach(([x, y]) => {
      px(ctx, x, y, 2, 2, light);
      px(ctx, x + 2, y + 2, 2, 2, dark);
    });
    return c;
  }

  createTallGrassTile() {
    const { c, ctx } = makeCanvas(32, 32);
    ctx.drawImage(this.tiles[TILE.GRASS], 0, 0);
    for (let y = 4; y < 28; y += 8) {
      for (let x = 4; x < 28; x += 8) {
        px(ctx, x, y + 2, 6, 4, '#295b1a');
        px(ctx, x + 1, y, 2, 5, '#63b546');
        px(ctx, x + 4, y + 1, 2, 4, '#79c95b');
      }
    }
    return c;
  }

  createFlowerTile() {
    const { c, ctx } = makeCanvas(32, 32);
    ctx.drawImage(this.tiles[TILE.GRASS], 0, 0);
    const flowers = [
      { x: 6, y: 7, col: '#ffd84d' },
      { x: 20, y: 10, col: '#ff7088' },
      { x: 11, y: 22, col: '#ffffff' },
      { x: 24, y: 24, col: '#ffd84d' },
    ];
    flowers.forEach((f) => {
      px(ctx, f.x, f.y + 2, 4, 3, '#2d631e');
      px(ctx, f.x, f.y, 4, 4, f.col);
      px(ctx, f.x + 1, f.y + 1, 2, 2, '#d97b16');
    });
    return c;
  }

  createDirtTile() {
    const { c, ctx } = makeCanvas(32, 32);
    px(ctx, 0, 0, 32, 32, '#b98f58');
    const pebbles = [
      [3, 5, '#9d7440'], [14, 8, '#cfb576'], [25, 4, '#9d7440'],
      [8, 19, '#cfb576'], [19, 23, '#8a6232'], [27, 17, '#cfb576'],
      [5, 27, '#9d7440'], [15, 15, '#a57c48'],
    ];
    pebbles.forEach(([x, y, col]) => px(ctx, x, y, 3, 2, col));
    return c;
  }

  createCobbleTile() {
    const { c, ctx } = makeCanvas(32, 32);
    px(ctx, 0, 0, 32, 32, '#5a5f66');
    const stones = [
      [1, 1, 14, 14], [17, 1, 14, 14],
      [1, 17, 9, 14], [12, 17, 19, 14],
    ];
    stones.forEach(([x, y, w, h]) => {
      px(ctx, x, y, w, h, '#878d96');
      px(ctx, x + 1, y + 1, w - 3, h - 3, '#9da4ad');
    });
    return c;
  }

  createWaterTile(frame) {
    const { c, ctx } = makeCanvas(32, 32);
    px(ctx, 0, 0, 32, 32, '#235789');
    const shift = frame * 4;
    px(ctx, (4 + shift) % 28, 7, 10, 2, '#5698d4');
    px(ctx, (16 - shift + 28) % 28, 17, 12, 2, '#7ab8eb');
    px(ctx, (8 + shift) % 28, 26, 9, 2, '#5698d4');
    return c;
  }

  createBridgeTile() {
    const { c, ctx } = makeCanvas(32, 32);
    px(ctx, 0, 0, 32, 32, '#694221');
    for (let x = 0; x < 32; x += 8) {
      px(ctx, x, 0, 7, 32, '#8b5a2b');
      px(ctx, x + 1, 2, 5, 28, '#9c6836');
    }
    // Barandillas superior e inferior
    px(ctx, 0, 0, 32, 4, '#4d2e14');
    px(ctx, 0, 28, 32, 4, '#4d2e14');
    return c;
  }

  createTreeTile() {
    const { c, ctx } = makeCanvas(32, 32);
    ctx.drawImage(this.tiles[TILE.GRASS], 0, 0);
    // Sombra
    px(ctx, 4, 24, 24, 6, 'rgba(0,0,0,0.28)');
    // Tronco
    px(ctx, 11, 18, 10, 11, '#5c3a1e');
    px(ctx, 13, 18, 4, 11, '#784e2b');
    // Copa frondosa 16-bit (3 niveles)
    px(ctx, 3, 4, 26, 18, '#1e4d1b');
    px(ctx, 5, 2, 22, 16, '#2e6f28');
    px(ctx, 7, 4, 18, 11, '#44913b');
    px(ctx, 9, 5, 10, 6, '#62b356');
    return c;
  }

  createFenceTile() {
    const { c, ctx } = makeCanvas(32, 32);
    ctx.drawImage(this.tiles[TILE.GRASS], 0, 0);
    px(ctx, 4, 24, 24, 5, 'rgba(0,0,0,0.22)');
    // Postes
    px(ctx, 4, 8, 6, 20, '#5e3c1b');
    px(ctx, 22, 8, 6, 20, '#5e3c1b');
    px(ctx, 5, 9, 4, 18, '#8c5c30');
    px(ctx, 23, 9, 4, 18, '#8c5c30');
    // Travesaños
    px(ctx, 0, 12, 32, 4, '#7a4e26');
    px(ctx, 0, 20, 32, 4, '#7a4e26');
    return c;
  }

  createRockTile() {
    const { c, ctx } = makeCanvas(32, 32);
    ctx.drawImage(this.tiles[TILE.GRASS], 0, 0);
    px(ctx, 4, 24, 24, 6, 'rgba(0,0,0,0.3)');
    px(ctx, 4, 8, 24, 18, '#4a4e54');
    px(ctx, 6, 6, 20, 16, '#6c727a');
    px(ctx, 8, 8, 14, 10, '#8d949e');
    px(ctx, 10, 9, 6, 4, '#b0b7c2');
    return c;
  }

  createHobbitWallTile() {
    const { c, ctx } = makeCanvas(32, 32);
    // Techo de pradera verde arriba y muro acogedor de ladrillo/madera abajo
    px(ctx, 0, 0, 32, 12, '#3d782b');
    px(ctx, 0, 10, 32, 4, '#5ba843');
    px(ctx, 0, 14, 32, 18, '#d9c29c');
    // Vigas de roble
    px(ctx, 0, 14, 32, 3, '#5c3a1e');
    px(ctx, 0, 29, 32, 3, '#5c3a1e');
    // Ventana redonda hobbit
    px(ctx, 10, 17, 12, 11, '#4a2e16');
    px(ctx, 12, 19, 8, 7, '#f5d469');
    px(ctx, 15, 19, 2, 7, '#4a2e16');
    px(ctx, 12, 22, 8, 2, '#4a2e16');
    return c;
  }

  createHobbitDoorTile() {
    const { c, ctx } = makeCanvas(32, 32);
    px(ctx, 0, 0, 32, 10, '#3d782b');
    px(ctx, 0, 10, 32, 22, '#d9c29c');
    // Marco redondo de madera
    px(ctx, 5, 8, 22, 24, '#4e2f16');
    // Puerta redonda verde esmeralda (estilo Bolsón Cerrado)
    px(ctx, 7, 10, 18, 22, '#2d7a3e');
    px(ctx, 9, 12, 14, 18, '#3a944e');
    // Pomo dorado en el centro exacto
    px(ctx, 15, 19, 3, 3, '#ffd700');
    return c;
  }

  createCropTile() {
    const { c, ctx } = makeCanvas(32, 32);
    px(ctx, 0, 0, 32, 32, '#5c3d22');
    for (let y = 3; y < 30; y += 8) {
      px(ctx, 2, y, 28, 4, '#472d17');
    }
    // Calabazas y coles hobbit
    px(ctx, 6, 6, 6, 6, '#e67e22');
    px(ctx, 8, 4, 2, 2, '#2ecc71');
    px(ctx, 20, 18, 6, 6, '#e67e22');
    px(ctx, 22, 16, 2, 2, '#2ecc71');
    px(ctx, 18, 6, 6, 6, '#58b347');
    px(ctx, 7, 19, 6, 6, '#58b347');
    return c;
  }

  createMillWallTile() {
    const { c, ctx } = makeCanvas(32, 32);
    px(ctx, 0, 0, 32, 32, '#6e655c');
    for (let y = 0; y < 32; y += 8) {
      const offset = (y / 8) % 2 === 0 ? 0 : 8;
      for (let x = offset; x < 32; x += 16) {
        px(ctx, x + 1, y + 1, 14, 6, '#8c8275');
      }
    }
    return c;
  }

  createCampTile() {
    const { c, ctx } = makeCanvas(32, 32);
    px(ctx, 0, 0, 32, 32, '#3d332a');
    px(ctx, 4, 4, 24, 24, '#2c241d');
    // Rocas de hoguera y brasas
    px(ctx, 8, 10, 16, 14, '#595959');
    px(ctx, 11, 12, 10, 10, '#d35400');
    px(ctx, 13, 14, 6, 6, '#f1c40f');
    return c;
  }
}

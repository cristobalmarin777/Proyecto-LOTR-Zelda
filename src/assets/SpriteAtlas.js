/**
 * SpriteAtlas — Generador procedural de Pixel Art 16-bit (estilo SNES / Zelda ALTTP).
 * Actualizado con las texturas de camino ocre dorado, pasto vibrante con brotes,
 * hierba alta frondosa en abanico (4 hojas con raíces oscuras), flores silvestres
 * (margaritas blancas, espigas rosadas/lavanda y flores naranjas/azules) y
 * bordes de autotiling dentado de césped sobre los senderos de tierra.
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

const GRASS_LIKE_TILES = new Set([
  TILE.GRASS,
  TILE.TALL_GRASS,
  TILE.FLOWERS,
  TILE.TREE,
  TILE.FENCE,
  TILE.ROCK,
  TILE.DARK_FOREST,
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
    this.grassVariants = [];
    this.flowerVariants = [];
    this.dirtEdges = {};
    this.generateTiles();
  }

  generateTiles() {
    // 0: GRASS (Pasto verde vivo estilo Zelda ALTTP / Referencia adjunta, con 4 variantes sutiles)
    this.grassVariants = [
      this.createGrassVariant(0, '#58a832', '#68ba3e', '#448a24'),
      this.createGrassVariant(1, '#58a832', '#68ba3e', '#448a24'),
      this.createGrassVariant(2, '#58a832', '#68ba3e', '#448a24'),
      this.createGrassVariant(3, '#58a832', '#68ba3e', '#448a24'),
    ];
    this.tiles[TILE.GRASS] = this.grassVariants[0];

    // 1: TALL_GRASS (Matas frondosas de hierba alta en abanico con puntas arqueadas, Referencia adjunta)
    this.tiles[TILE.TALL_GRASS] = this.createTallGrassTile();

    // 2: FLOWERS (3 variantes: margaritas blancas, espigas rosadas/lavanda y ramilletes naranjas/azules)
    this.flowerVariants = [
      this.createFlowerVariant(0),
      this.createFlowerVariant(1),
      this.createFlowerVariant(2),
    ];
    this.tiles[TILE.FLOWERS] = this.flowerVariants[0];

    // 3: DIRT_PATH (Camino de tierra arena dorada cálida con textura granulada sutil)
    this.tiles[TILE.DIRT_PATH] = this.createDirtTile();
    this.generateDirtGrassEdges();

    // 4: COBBLESTONE (Empedrado antiguo / Puente)
    this.tiles[TILE.COBBLESTONE] = this.createCobbleTile();

    // 5: WATER (Río El Agua con 2 frames de animación)
    this.waterFrames = [this.createWaterTile(0), this.createWaterTile(1)];
    this.tiles[TILE.WATER] = this.waterFrames[0];

    // 6: BRIDGE (Puente de madera sobre el río)
    this.tiles[TILE.BRIDGE] = this.createBridgeTile();

    // 7: TREE (Árbol frondoso estilo Zelda ALTTP de la actualización sobre el nuevo pasto)
    this.tiles[TILE.TREE] = this.createTreeTile();

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
    this.tiles[TILE.DARK_FOREST] = this.createGrassVariant(1, '#2d5e29', '#397334', '#1f451c');

    // 14: MILL_BASE (Muro de piedra del Viejo Molino)
    this.tiles[TILE.MILL_BASE] = this.createMillWallTile();

    // 15: CAMPFIRE_ASH (Tierra quemada de campamento orco)
    this.tiles[TILE.CAMPFIRE_ASH] = this.createCampTile();
  }

  /**
   * Pasto base vibrante con textura sutil y pequeños brotes de 2-3 hojas (Referencia adjunta)
   */
  createGrassVariant(variantIdx, base, light, dark) {
    const { c, ctx } = makeCanvas(32, 32);
    px(ctx, 0, 0, 32, 32, base);

    // Motas suaves de luz en el césped para evitar aspecto plano
    const highlights = [
      [3, 4], [14, 2], [26, 7], [7, 15], [20, 14], [28, 22], [5, 26], [17, 27],
    ];
    for (const [hx, hy] of highlights) {
      const ox = (hx + variantIdx * 5) % 30;
      const oy = (hy + variantIdx * 7) % 30;
      px(ctx, ox, oy, 2, 1, light);
    }

    // En las variantes 1 y 2 añadimos un pequeño brote de hierba (tuft de 3 briznas como los que salpican el pasto en la imagen)
    if (variantIdx === 1 || variantIdx === 2) {
      const tx = variantIdx === 1 ? 10 : 18;
      const ty = variantIdx === 1 ? 18 : 11;
      this.drawSmallGrassSprout(ctx, tx, ty, dark);
    } else if (variantIdx === 3) {
      this.drawSmallGrassSprout(ctx, 7, 10, dark);
      this.drawSmallGrassSprout(ctx, 21, 23, dark);
    }

    return c;
  }

  /**
   * Pequeño brote de 3 hojas finas que adorna el pasto abierto en la imagen de referencia
   */
  drawSmallGrassSprout(ctx, x, y, shadowCol = '#2a6624') {
    // Sombra en la base
    px(ctx, x + 1, y + 5, 6, 2, shadowCol);
    // Hoja izquierda inclinada
    px(ctx, x, y + 2, 2, 3, '#2f7532');
    px(ctx, x - 1, y + 1, 2, 2, '#4ba346');
    // Hoja central alta
    px(ctx, x + 3, y, 2, 5, '#3b8c3b');
    px(ctx, x + 3, y - 1, 2, 2, '#6fd160');
    // Hoja derecha inclinada
    px(ctx, x + 6, y + 2, 2, 3, '#2f7532');
    px(ctx, x + 7, y + 1, 2, 2, '#4ba346');
  }

  /**
   * Hierba Alta Frondosa (TALL_GRASS) — Fiel a la imagen de referencia:
   * Matas densas en abanico con base verde pino oscuro, hojas anchas verde esmeralda/menta
   * y puntas arqueadas iluminadas que se solapan con volumen 16-bit.
   */
  createTallGrassTile() {
    const { c, ctx } = makeCanvas(32, 32);
    ctx.drawImage(this.grassVariants[0], 0, 0);

    // Dos filas escalonadas de matas tupidas para que al juntar varios tiles formen un macizo continuo
    this.drawLushGrassClump(ctx, 8, 13);
    this.drawLushGrassClump(ctx, 24, 14);
    this.drawLushGrassClump(ctx, 16, 27);
    this.drawLushGrassClump(ctx, 3, 28);
    this.drawLushGrassClump(ctx, 29, 28);

    return c;
  }

  drawLushGrassClump(ctx, cx, baseY) {
    // 1. Sombra profunda en la raíz de la mata
    px(ctx, cx - 7, baseY - 2, 14, 3, '#1d4d1a');
    px(ctx, cx - 6, baseY - 4, 12, 3, '#235e24');

    // 2. Hoja exterior izquierda (curvada a la izquierda)
    px(ctx, cx - 7, baseY - 8, 3, 6, '#2b7333');
    px(ctx, cx - 9, baseY - 11, 3, 4, '#469c4b');
    px(ctx, cx - 10, baseY - 12, 2, 2, '#78cf72');

    // 3. Hoja media-izquierda (alta y arqueada)
    px(ctx, cx - 4, baseY - 10, 3, 8, '#2b7333');
    px(ctx, cx - 5, baseY - 14, 3, 5, '#4ca850');
    px(ctx, cx - 6, baseY - 15, 2, 2, '#8ae082');

    // 4. Hoja central-derecha (la más esbelta)
    px(ctx, cx, baseY - 11, 3, 9, '#25662d');
    px(ctx, cx + 1, baseY - 15, 3, 5, '#54b356');
    px(ctx, cx + 2, baseY - 16, 2, 2, '#92e88a');

    // 5. Hoja exterior derecha (curvada a la derecha)
    px(ctx, cx + 4, baseY - 8, 3, 6, '#25662d');
    px(ctx, cx + 6, baseY - 11, 3, 4, '#469c4b');
    px(ctx, cx + 8, baseY - 12, 2, 2, '#78cf72');
  }

  /**
   * Flores Silvestres (FLOWERS) — 3 variantes inspiradas directamente en la imagen de referencia:
   *  - Variante 0: Margaritas blancas con centro dorado y hojas verdes en la base.
   *  - Variante 1: Espigas verticales de flores rosadas/lavanda (lupinos).
   *  - Variante 2: Ramillete de florecillas rojo-naranja y campanilla azul celeste.
   */
  createFlowerVariant(variantIdx) {
    const { c, ctx } = makeCanvas(32, 32);
    ctx.drawImage(this.grassVariants[0], 0, 0);

    if (variantIdx === 0) {
      // Margaritas blancas con centro amarillo/naranja
      this.drawDaisyCluster(ctx, 9, 12);
      this.drawDaisyCluster(ctx, 22, 24);
    } else if (variantIdx === 1) {
      // Espigas verticales rosadas/lavanda (como las del borde del camino en la imagen)
      this.drawLupineSpikes(ctx, 14, 21);
      this.drawSmallGrassSprout(ctx, 22, 10);
    } else {
      // Ramillete de florecillas naranjas/corales y flor azul celeste
      this.drawOrangeSprig(ctx, 11, 18);
      this.drawBlueBellFlower(ctx, 23, 25);
    }

    return c;
  }

  drawDaisyCluster(ctx, cx, cy) {
    // Hojas de base
    px(ctx, cx - 4, cy + 3, 9, 3, '#28662b');
    px(ctx, cx - 3, cy + 1, 7, 3, '#3b8c3b');
    // Flor principal blanca en cruz
    px(ctx, cx - 2, cy - 4, 5, 5, '#ffffff');
    px(ctx, cx - 3, cy - 3, 7, 3, '#f0f7f4');
    px(ctx, cx - 1, cy - 3, 3, 3, '#f5a623');
    px(ctx, cx, cy - 2, 1, 1, '#ffe066');
    // Segunda margarita pequeña al lado
    px(ctx, cx + 4, cy, 4, 4, '#ffffff');
    px(ctx, cx + 5, cy + 1, 2, 2, '#f5a623');
  }

  drawLupineSpikes(ctx, cx, baseY) {
    // Mata de hojas en la base
    px(ctx, cx - 6, baseY - 2, 13, 3, '#235c26');
    px(ctx, cx - 5, baseY - 5, 11, 4, '#367d39');
    // 3 tallos verticales con capullos rosa/magenta y puntas claras
    const stems = [-4, 0, 4];
    for (const dx of stems) {
      const h = dx === 0 ? 11 : 9;
      px(ctx, cx + dx, baseY - h, 2, h - 2, '#2d6e31');
      // Pétalos escalonados en la espiga
      px(ctx, cx + dx - 1, baseY - h + 3, 4, 2, '#c94b86');
      px(ctx, cx + dx - 1, baseY - h + 1, 4, 2, '#eb6ca8');
      px(ctx, cx + dx, baseY - h - 1, 2, 2, '#ff9ed0');
    }
  }

  drawOrangeSprig(ctx, cx, baseY) {
    // Tallos finos ramificados
    px(ctx, cx - 3, baseY - 2, 7, 3, '#28662b');
    px(ctx, cx - 1, baseY - 9, 2, 8, '#388036');
    px(ctx, cx - 4, baseY - 7, 3, 2, '#388036');
    px(ctx, cx + 1, baseY - 8, 3, 2, '#388036');
    // Motas de flores rojo-naranja brillante
    const buds = [
      [-5, -9], [-2, -11], [1, -12], [4, -9], [-3, -6], [3, -6],
    ];
    for (const [bx, by] of buds) {
      px(ctx, cx + bx, baseY + by, 2, 2, '#eb5628');
      px(ctx, cx + bx, baseY + by, 1, 1, '#ff9c40');
    }
  }

  drawBlueBellFlower(ctx, cx, baseY) {
    px(ctx, cx - 2, baseY - 2, 5, 3, '#266129');
    px(ctx, cx, baseY - 7, 2, 6, '#388036');
    px(ctx, cx - 2, baseY - 9, 5, 4, '#4589e6');
    px(ctx, cx - 1, baseY - 10, 3, 3, '#78b7ff');
  }

  /**
   * Camino de Tierra / Arena Ocre Dorada (DIRT_PATH) — Fiel a la imagen de referencia:
   * Base ocre dorada cálida (#e8b55a) con patrón orgánico sutil de ondas y granos suaves (#dfa84b y #f2c36b).
   */
  createDirtTile() {
    const { c, ctx } = makeCanvas(32, 32);
    px(ctx, 0, 0, 32, 32, '#e8b55a');

    // Textura orgánica suave de tierra apisonada (ondas pixeladas de bajo contraste como en la referencia)
    for (let y = 0; y < 32; y += 2) {
      for (let x = 0; x < 32; x += 2) {
        const wave = Math.sin(x * 0.35 + y * 0.25) + Math.cos((x - y) * 0.3);
        if (wave > 0.85) {
          px(ctx, x, y, 2, 2, '#f2c36b');
        } else if (wave < -0.75) {
          px(ctx, x, y, 2, 2, '#dba346');
        }
      }
    }

    // Pequeños detalles de gravilla cálida
    const grains = [
      [5, 6, '#cf9638'], [19, 4, '#f7cc79'], [26, 13, '#cf9638'],
      [9, 20, '#f7cc79'], [22, 24, '#cf9638'], [14, 14, '#d69d3e'],
      [4, 27, '#f7cc79'], [28, 28, '#cf9638'],
    ];
    for (const [gx, gy, col] of grains) {
      px(ctx, gx, gy, 2, 2, col);
    }
    return c;
  }

  /**
   * Genera las tiras de transición dentada de césped que muerden el borde del camino
   * (exactamente como el borde de briznas verdes con sombra oscura de la imagen de referencia).
   */
  generateDirtGrassEdges() {
    const grassBase = '#58a832';
    const grassLight = '#68ba3e';
    const grassShadow = '#295418';

    // Borde Norte (el pasto de arriba proyecta briznas dentadas hacia abajo sobre la tierra)
    {
      const { c, ctx } = makeCanvas(32, 8);
      const teeth = [4, 5, 3, 2, 4, 6, 4, 2, 3, 5, 4, 3, 5, 6, 3, 4];
      for (let i = 0; i < 16; i++) {
        const x = i * 2;
        const h = teeth[i];
        px(ctx, x, 0, 2, h, grassBase);
        px(ctx, x, 0, 2, 1, grassLight);
        px(ctx, x, h, 2, 2, grassShadow);
      }
      this.dirtEdges.N = c;
    }

    // Borde Sur (el pasto de abajo asoma briznas hacia arriba sobre la tierra)
    {
      const { c, ctx } = makeCanvas(32, 8);
      const teeth = [3, 5, 6, 4, 2, 4, 5, 3, 2, 5, 6, 4, 3, 5, 4, 3];
      for (let i = 0; i < 16; i++) {
        const x = i * 2;
        const h = teeth[i];
        px(ctx, x, 8 - h - 1, 2, 2, grassShadow);
        px(ctx, x, 8 - h, 2, h, grassBase);
        px(ctx, x, 8 - Math.max(1, h - 1), 2, 1, grassLight);
      }
      this.dirtEdges.S = c;
    }

    // Borde Oeste (izquierda)
    {
      const { c, ctx } = makeCanvas(8, 32);
      const teeth = [4, 5, 3, 2, 5, 4, 3, 5, 6, 3, 2, 4, 5, 3, 4, 5];
      for (let i = 0; i < 16; i++) {
        const y = i * 2;
        const w = teeth[i];
        px(ctx, 0, y, w, 2, grassBase);
        px(ctx, w, y, 2, 2, grassShadow);
      }
      this.dirtEdges.W = c;
    }

    // Borde Este (derecha)
    {
      const { c, ctx } = makeCanvas(8, 32);
      const teeth = [3, 5, 4, 3, 5, 6, 3, 2, 4, 5, 3, 4, 5, 2, 4, 3];
      for (let i = 0; i < 16; i++) {
        const y = i * 2;
        const w = teeth[i];
        px(ctx, 8 - w - 1, y, 2, 2, grassShadow);
        px(ctx, 8 - w, y, w, 2, grassBase);
      }
      this.dirtEdges.E = c;
    }
  }

  /**
   * Dibuja un tile del terreno aplicando variedades deterministas de pasto/flores
   * y los bordes dentados estilo Zelda ALTTP cuando un camino (DIRT_PATH) colinda con pasto.
   */
  drawTerrainTile(ctx, map, col, row, screenX, screenY) {
    const tileId = map.getTile ? map.getTile(col, row) : map.grid[row][col];
    const hash = Math.abs((col * 73856093) ^ (row * 19349663));

    if (tileId === TILE.GRASS) {
      // Selección determinista para que la pradera tenga pequeños brotes de hierba sin repetir patrón
      const vIdx = hash % 7 === 0 ? 1 : hash % 11 === 0 ? 2 : hash % 19 === 0 ? 3 : 0;
      ctx.drawImage(this.grassVariants[vIdx], screenX, screenY);
      return;
    }

    if (tileId === TILE.FLOWERS) {
      const fIdx = hash % this.flowerVariants.length;
      ctx.drawImage(this.flowerVariants[fIdx], screenX, screenY);
      return;
    }

    const img = this.tiles[tileId] || this.tiles[TILE.GRASS];
    ctx.drawImage(img, screenX, screenY);

    // Si es camino de tierra, superponer los bordes dentados de césped en los lados que tocan pasto
    if (tileId === TILE.DIRT_PATH) {
      const getNeighbor = (c, r) => (map.getTile ? map.getTile(c, r) : map.grid?.[r]?.[c] ?? TILE.GRASS);
      if (GRASS_LIKE_TILES.has(getNeighbor(col, row - 1))) {
        ctx.drawImage(this.dirtEdges.N, screenX, screenY);
      }
      if (GRASS_LIKE_TILES.has(getNeighbor(col, row + 1))) {
        ctx.drawImage(this.dirtEdges.S, screenX, screenY + 24);
      }
      if (GRASS_LIKE_TILES.has(getNeighbor(col - 1, row))) {
        ctx.drawImage(this.dirtEdges.W, screenX, screenY);
      }
      if (GRASS_LIKE_TILES.has(getNeighbor(col + 1, row))) {
        ctx.drawImage(this.dirtEdges.E, screenX + 24, screenY);
      }
    }
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
    px(ctx, 0, 0, 32, 4, '#4d2e14');
    px(ctx, 0, 28, 32, 4, '#4d2e14');
    return c;
  }

  createTreeTile() {
    const { c, ctx } = makeCanvas(32, 32);
    ctx.drawImage(this.tiles[TILE.GRASS], 0, 0);
    // Sombra
    px(ctx, 4, 24, 24, 6, 'rgba(0,0,0,0.28)');
    // Tronco (estética de la actualización)
    px(ctx, 11, 18, 10, 11, '#5c3a1e');
    px(ctx, 13, 18, 4, 11, '#784e2b');
    // Copa frondosa 16-bit en bloques escalonados (estética de la actualización)
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
    px(ctx, 4, 8, 6, 20, '#5e3c1b');
    px(ctx, 22, 8, 6, 20, '#5e3c1b');
    px(ctx, 5, 9, 4, 18, '#8c5c30');
    px(ctx, 23, 9, 4, 18, '#8c5c30');
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
    px(ctx, 0, 0, 32, 12, '#3d782b');
    px(ctx, 0, 10, 32, 4, '#5ba843');
    px(ctx, 0, 14, 32, 18, '#d9c29c');
    px(ctx, 0, 14, 32, 3, '#5c3a1e');
    px(ctx, 0, 29, 32, 3, '#5c3a1e');
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
    px(ctx, 5, 8, 22, 24, '#4e2f16');
    px(ctx, 7, 10, 18, 22, '#2d7a3e');
    px(ctx, 9, 12, 14, 18, '#3a944e');
    px(ctx, 15, 19, 3, 3, '#ffd700');
    return c;
  }

  createCropTile() {
    const { c, ctx } = makeCanvas(32, 32);
    px(ctx, 0, 0, 32, 32, '#5c3d22');
    for (let y = 3; y < 30; y += 8) {
      px(ctx, 2, y, 28, 4, '#472d17');
    }
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
    px(ctx, 8, 10, 16, 14, '#595959');
    px(ctx, 11, 12, 10, 10, '#d35400');
    px(ctx, 13, 14, 6, 6, '#f1c40f');
    return c;
  }
}

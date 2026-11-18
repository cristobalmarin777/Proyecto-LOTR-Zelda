/**
 * WorldGenerator — Mundo procedural determinista por semilla.
 *
 * La Comarca continúa siendo la zona inicial diseñada a mano, pero fuera de
 * ella el terreno se calcula al consultarlo: no existe una cuadrícula global
 * que cargar en memoria. La semilla garantiza que una coordenada siempre
 * genera el mismo terreno en una partida.
 */
import { TILE, SOLID_TILES } from '../assets/SpriteAtlas.js';
import { ShireMap } from './ShireMap.js';

const CHUNK_SIZE = 32;
const ATLAS_CHUNKS = 9;

export class WorldGenerator {
  constructor(seed = 19771029) {
    this.seed = seed >>> 0;
    this.tileSize = 32;
    this.isInfinite = true;
    this.modifiedTiles = new Map();
    this.openedMapChests = new Set();

    // Conservamos el contenido narrativo del prototipo como región inicial.
    this.shire = new ShireMap();
    this.npcs = this.shire.npcs;
    this.chests = this.shire.chests;
    this.signs = this.shire.signs;
    this.enemySpawns = this.shire.enemySpawns;
  }

  getChunkAtPixel(px, py) {
    return {
      x: Math.floor(px / (this.tileSize * CHUNK_SIZE)),
      y: Math.floor(py / (this.tileSize * CHUNK_SIZE)),
    };
  }

  getAtlasZoneAtChunk(chunkX, chunkY) {
    return {
      x: Math.floor(chunkX / ATLAS_CHUNKS),
      y: Math.floor(chunkY / ATLAS_CHUNKS),
    };
  }

  getAtlasZoneKey(zoneX, zoneY) {
    return `${zoneX},${zoneY}`;
  }

  getMapChestForZone(zoneX, zoneY) {
    const localX = 1 + Math.floor(this.random(zoneX, zoneY, 321) * (ATLAS_CHUNKS - 2));
    const localY = 1 + Math.floor(this.random(zoneX, zoneY, 322) * (ATLAS_CHUNKS - 2));
    const chunkX = zoneX * ATLAS_CHUNKS + localX;
    const chunkY = zoneY * ATLAS_CHUNKS + localY;
    const key = this.getAtlasZoneKey(zoneX, zoneY);
    return {
      id: `atlas_${key}`,
      zoneKey: key,
      zoneX,
      zoneY,
      col: chunkX * CHUNK_SIZE + 16,
      row: chunkY * CHUNK_SIZE + 16,
      opened: this.openedMapChests.has(key),
      title: `Carta regional ${zoneX}, ${zoneY}`,
    };
  }

  getMapChestsForArea(startCol, startRow, endCol, endRow) {
    const startZoneX = Math.floor(startCol / (CHUNK_SIZE * ATLAS_CHUNKS));
    const endZoneX = Math.floor(endCol / (CHUNK_SIZE * ATLAS_CHUNKS));
    const startZoneY = Math.floor(startRow / (CHUNK_SIZE * ATLAS_CHUNKS));
    const endZoneY = Math.floor(endRow / (CHUNK_SIZE * ATLAS_CHUNKS));
    const chests = [];
    for (let y = startZoneY; y <= endZoneY; y++) {
      for (let x = startZoneX; x <= endZoneX; x++) {
        const chest = this.getMapChestForZone(x, y);
        if (!chest.opened && chest.col >= startCol && chest.col <= endCol && chest.row >= startRow && chest.row <= endRow) {
          chests.push(chest);
        }
      }
    }
    return chests;
  }

  openMapChest(zoneKey) {
    this.openedMapChests.add(zoneKey);
  }

  getPoiForChunk(chunkX, chunkY) {
    // No superponer interiores procedurales sobre la zona artesanal inicial.
    if (chunkX >= 0 && chunkX <= 1 && chunkY >= 0 && chunkY <= 1) return null;
    const biome = this.getBiome(chunkX * CHUNK_SIZE + 16, chunkY * CHUNK_SIZE + 16);
    const roll = this.random(chunkX, chunkY, 1100);
    let type = null;
    if (biome === 'MISTY_FOOTHILLS' && roll < 0.22) type = this.random(chunkX, chunkY, 1101) < 0.48 ? 'mine_dwarven' : 'mine_abandoned';
    else if ((biome === 'OLD_FOREST' || biome === 'BARROW_DOWNS') && roll < 0.12) type = 'cave';
    else if (biome === 'ERIADOR' && roll < 0.055) type = 'cave';
    if (!type) return null;
    return {
      id: `poi_${chunkX}_${chunkY}`,
      chunkX, chunkY, type, biome,
      col: chunkX * CHUNK_SIZE + 16,
      row: chunkY * CHUNK_SIZE + 16,
      seed: Math.floor(this.random(chunkX, chunkY, 1102) * 0xffffffff),
    };
  }

  getPoisForArea(startCol, startRow, endCol, endRow) {
    const startChunkX = Math.floor(startCol / CHUNK_SIZE);
    const endChunkX = Math.floor(endCol / CHUNK_SIZE);
    const startChunkY = Math.floor(startRow / CHUNK_SIZE);
    const endChunkY = Math.floor(endRow / CHUNK_SIZE);
    const pois = [];
    for (let y = startChunkY; y <= endChunkY; y++) for (let x = startChunkX; x <= endChunkX; x++) {
      const poi = this.getPoiForChunk(x, y);
      if (poi && poi.col >= startCol && poi.col <= endCol && poi.row >= startRow && poi.row <= endRow) pois.push(poi);
    }
    return pois;
  }

  getEnemySpawnsForChunk(chunkX, chunkY) {
    // La zona artesanal inicial ya contiene sus propios encuentros.
    if (chunkX >= 0 && chunkX <= 1 && chunkY >= 0 && chunkY <= 1) return [];

    const biome = this.getBiome(chunkX * CHUNK_SIZE + 16, chunkY * CHUNK_SIZE + 16);
    const distanceThreat = Math.floor(Math.hypot(chunkX, chunkY) / 6);
    const biomeThreat = biome === 'MISTY_FOOTHILLS' ? 2 : biome === 'BARROW_DOWNS' ? 1 : 0;
    const threat = Math.min(5, distanceThreat + biomeThreat);
    const countByBiome = { SHIRE: 1, OLD_FOREST: 3, BREE_LAND: 2, BARROW_DOWNS: 3, ERIADOR: 2, MISTY_FOOTHILLS: 3 };
    const count = countByBiome[biome] || 2;
    const spawns = [];
    for (let i = 0; i < count; i++) {
      let col = chunkX * CHUNK_SIZE + 4 + Math.floor(this.random(chunkX, chunkY, 500 + i) * 24);
      let row = chunkY * CHUNK_SIZE + 4 + Math.floor(this.random(chunkX, chunkY, 600 + i) * 24);
      // Reintenta un suelo transitable para no crear enemigos dentro de árboles o rocas.
      for (let attempt = 0; attempt < 8 && SOLID_TILES.has(this.getTile(col, row)); attempt++) {
        col = chunkX * CHUNK_SIZE + 4 + Math.floor(this.random(chunkX, chunkY, 700 + i * 9 + attempt) * 24);
        row = chunkY * CHUNK_SIZE + 4 + Math.floor(this.random(chunkX, chunkY, 800 + i * 9 + attempt) * 24);
      }
      if (SOLID_TILES.has(this.getTile(col, row))) continue;
      const roll = this.random(chunkX, chunkY, 900 + i);
      let type = 'orc';
      if (biome === 'OLD_FOREST') type = roll < 0.42 ? 'spider' : roll < 0.72 ? 'orc' : 'archer_orc';
      else if (biome === 'MISTY_FOOTHILLS') type = roll < 0.35 ? 'uruk' : 'orc';
      else if (biome === 'BARROW_DOWNS') type = roll < 0.52 ? 'spider' : 'orc';
      else if (roll < 0.28) type = 'spider';
      spawns.push({ type, col, row, key: `${chunkX},${chunkY}:${i}`, threat });
    }
    return spawns;
  }

  getGoblinCampForChunk(chunkX, chunkY) {
    if (chunkX >= 0 && chunkX <= 1 && chunkY >= 0 && chunkY <= 1) return null;
    const biome = this.getBiome(chunkX * CHUNK_SIZE + 16, chunkY * CHUNK_SIZE + 16);
    if (!['OLD_FOREST', 'ERIADOR', 'BARROW_DOWNS'].includes(biome) || this.random(chunkX, chunkY, 1500) > 0.115) return null;
    return {
      id: `goblin_camp_${chunkX}_${chunkY}`,
      chunkX,
      chunkY,
      col: chunkX * CHUNK_SIZE + 16,
      row: chunkY * CHUNK_SIZE + 16,
    };
  }

  getGoblinCampsForArea(startCol, startRow, endCol, endRow) {
    const camps = [];
    for (let row = Math.floor(startRow / CHUNK_SIZE); row <= Math.floor(endRow / CHUNK_SIZE); row++) {
      for (let col = Math.floor(startCol / CHUNK_SIZE); col <= Math.floor(endCol / CHUNK_SIZE); col++) {
        const camp = this.getGoblinCampForChunk(col, row);
        if (camp && camp.col >= startCol && camp.col <= endCol && camp.row >= startRow && camp.row <= endRow) camps.push(camp);
      }
    }
    return camps;
  }

  getGoblinSpawnsForChunk(chunkX, chunkY) {
    const camp = this.getGoblinCampForChunk(chunkX, chunkY);
    if (!camp) return [];
    const spawns = [];
    const count = 5 + Math.floor(this.random(chunkX, chunkY, 1501) * 4);
    for (let index = 0; index < count; index++) {
      const angle = this.random(chunkX, chunkY, 1510 + index) * Math.PI * 2;
      const radius = 2 + Math.floor(this.random(chunkX, chunkY, 1530 + index) * 5);
      spawns.push({
        type: 'goblin',
        col: camp.col + Math.round(Math.cos(angle) * radius),
        row: camp.row + Math.round(Math.sin(angle) * radius),
        key: `goblin:${chunkX},${chunkY}:${index}`,
        threat: 0,
      });
    }
    return spawns;
  }

  getElfSpawnsForChunk(chunkX, chunkY) {
    const biome = this.getBiome(chunkX * CHUNK_SIZE + 16, chunkY * CHUNK_SIZE + 16);
    if (biome !== 'OLD_FOREST' || this.random(chunkX, chunkY, 1400) > 0.26) return [];
    let col = chunkX * CHUNK_SIZE + 5 + Math.floor(this.random(chunkX, chunkY, 1401) * 22);
    let row = chunkY * CHUNK_SIZE + 5 + Math.floor(this.random(chunkX, chunkY, 1402) * 22);
    for (let attempt = 0; attempt < 8 && SOLID_TILES.has(this.getTile(col, row)); attempt++) {
      col = chunkX * CHUNK_SIZE + 5 + Math.floor(this.random(chunkX, chunkY, 1410 + attempt) * 22);
      row = chunkY * CHUNK_SIZE + 5 + Math.floor(this.random(chunkX, chunkY, 1420 + attempt) * 22);
    }
    if (SOLID_TILES.has(this.getTile(col, row))) return [];
    const roleRoll = this.random(chunkX, chunkY, 1403);
    const role = roleRoll < 0.34 ? 'scout' : roleRoll < 0.67 ? 'lembas' : 'quest';
    return [{ col, row, role, key: `elf:${chunkX},${chunkY}` }];
  }

  getTileAtPixel(px, py) {
    return this.getTile(Math.floor(px / this.tileSize), Math.floor(py / this.tileSize));
  }

  getTile(col, row) {
    const key = `${col},${row}`;
    if (this.modifiedTiles.has(key)) return this.modifiedTiles.get(key);

    // El cofre de cada carta se asienta siempre sobre terreno transitable.
    const zoneX = Math.floor(col / (CHUNK_SIZE * ATLAS_CHUNKS));
    const zoneY = Math.floor(row / (CHUNK_SIZE * ATLAS_CHUNKS));
    const mapChest = this.getMapChestForZone(zoneX, zoneY);
    if (col === mapChest.col && row === mapChest.row) return TILE.DIRT_PATH;
    const poi = this.getPoiForChunk(Math.floor(col / CHUNK_SIZE), Math.floor(row / CHUNK_SIZE));
    if (poi && Math.abs(col - poi.col) <= 1 && Math.abs(row - poi.row) <= 1) return TILE.DIRT_PATH;
    const camp = this.getGoblinCampForChunk(Math.floor(col / CHUNK_SIZE), Math.floor(row / CHUNK_SIZE));
    if (camp && Math.abs(col - camp.col) <= 4 && Math.abs(row - camp.row) <= 4) {
      return col === camp.col && row === camp.row ? TILE.CAMPFIRE_ASH : TILE.DIRT_PATH;
    }

    // Se usa el mapa hecho a mano en su interior, pero no su muro perimetral:
    // así se puede salir de La Comarca hacia un mundo que continúa.
    if (col > 0 && col < this.shire.cols - 1 && row > 0 && row < this.shire.rows - 1) {
      return this.shire.grid[row][col];
    }
    return this.generateTerrain(col, row);
  }

  setTile(col, row, tileId) {
    this.modifiedTiles.set(`${col},${row}`, tileId);
  }

  isRectBlocked(cx, cy, halfW, halfH) {
    const points = [
      [cx - halfW, cy - halfH], [cx + halfW, cy - halfH],
      [cx - halfW, cy + halfH], [cx + halfW, cy + halfH],
    ];
    return points.some(([px, py]) => SOLID_TILES.has(this.getTileAtPixel(px, py)));
  }

  getBiomeAtPixel(px, py) {
    return this.getBiome(Math.floor(px / this.tileSize), Math.floor(py / this.tileSize));
  }

  getBiomeNameAtPixel(px, py) {
    const names = {
      SHIRE: 'LA COMARCA',
      OLD_FOREST: 'BOSQUE VIEJO',
      BREE_LAND: 'TIERRAS DE BREE',
      BARROW_DOWNS: 'QUEBRADAS DE LOS TÚMULOS',
      ERIADOR: 'ERIADOR SALVAJE',
      MISTY_FOOTHILLS: 'ESTRIBACIONES NUBLADAS',
    };
    return names[this.getBiomeAtPixel(px, py)] || 'TIERRAS SIN CARTOGRAFIAR';
  }

  getBiome(col, row) {
    // Regiones ancla inspiradas en la geografía occidental de la Tierra Media.
    if (col < 31 && row > -24 && row < 48) return 'SHIRE';
    if (col >= 31 && col < 96 && row > -12 && row < 58) return 'OLD_FOREST';
    if (col >= 96 && col < 145 && row > -18 && row < 54) return 'BREE_LAND';
    if (row < -18 && col > 48 && col < 150) return 'BARROW_DOWNS';

    const elevation = this.fbm(col / 72, row / 72, 3);
    const moisture = this.fbm((col + 900) / 45, (row - 700) / 45, 2);
    if (elevation > 0.73) return 'MISTY_FOOTHILLS';
    if (moisture > 0.6) return 'OLD_FOREST';
    return 'ERIADOR';
  }

  generateTerrain(col, row) {
    const biome = this.getBiome(col, row);
    const detail = this.random(col, row, 17);
    const vegetation = this.random(col, row, 41);

    // Arroyos largos y reproducibles; se pueden bordear o cruzar en puentes
    // colocados posteriormente como puntos de interés.
    const riverLine = Math.abs(Math.sin(col * 0.075 + this.fbm(col / 30, row / 30, 2) * 5) - row * 0.002);
    if (biome !== 'MISTY_FOOTHILLS' && riverLine < 0.012) return TILE.WATER;

    if (biome === 'SHIRE') {
      if (vegetation < 0.025) return TILE.TREE;
      if (detail < 0.055) return TILE.FLOWERS;
      return vegetation > 0.82 ? TILE.TALL_GRASS : TILE.GRASS;
    }
    if (biome === 'OLD_FOREST') {
      if (vegetation < 0.18) return TILE.TREE;
      return vegetation > 0.79 ? TILE.TALL_GRASS : TILE.DARK_FOREST;
    }
    if (biome === 'BREE_LAND') {
      if (vegetation < 0.07) return TILE.TREE;
      return detail < 0.22 ? TILE.DIRT_PATH : TILE.GRASS;
    }
    if (biome === 'BARROW_DOWNS') {
      if (vegetation < 0.09) return TILE.ROCK;
      return detail < 0.16 ? TILE.COBBLESTONE : TILE.DIRT_PATH;
    }
    if (biome === 'MISTY_FOOTHILLS') {
      if (vegetation < 0.24) return TILE.ROCK;
      if (vegetation < 0.29) return TILE.TREE;
      return TILE.DIRT_PATH;
    }

    if (vegetation < 0.05) return TILE.TREE;
    if (detail < 0.08) return TILE.ROCK;
    return vegetation > 0.8 ? TILE.TALL_GRASS : TILE.GRASS;
  }

  random(x, y, salt = 0) {
    let n = Math.imul(x, 374761393) ^ Math.imul(y, 668265263) ^ Math.imul(this.seed + salt, 1442695041);
    n = Math.imul(n ^ (n >>> 13), 1274126177);
    return ((n ^ (n >>> 16)) >>> 0) / 4294967296;
  }

  valueNoise(x, y) {
    const x0 = Math.floor(x);
    const y0 = Math.floor(y);
    const tx = x - x0;
    const ty = y - y0;
    const smooth = (t) => t * t * (3 - 2 * t);
    const a = this.random(x0, y0, 91);
    const b = this.random(x0 + 1, y0, 91);
    const c = this.random(x0, y0 + 1, 91);
    const d = this.random(x0 + 1, y0 + 1, 91);
    const top = a + (b - a) * smooth(tx);
    const bottom = c + (d - c) * smooth(tx);
    return top + (bottom - top) * smooth(ty);
  }

  fbm(x, y, octaves) {
    let sum = 0;
    let amplitude = 0.5;
    let frequency = 1;
    for (let i = 0; i < octaves; i++) {
      sum += this.valueNoise(x * frequency, y * frequency) * amplitude;
      frequency *= 2;
      amplitude *= 0.5;
    }
    return sum / (1 - Math.pow(0.5, octaves));
  }
}

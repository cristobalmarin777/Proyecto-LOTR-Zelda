/**
 * DungeonMap — Interior procedural finito para cuevas y minas.
 * Las cuevas usan autómata celular; las minas unen salas mediante túneles.
 */
import { TILE, SOLID_TILES } from '../assets/SpriteAtlas.js';

export class DungeonMap {
  constructor({ type, seed, entrance, sourceBiome }) {
    this.type = type;
    this.seed = seed >>> 0;
    this.entrance = entrance;
    this.sourceBiome = sourceBiome;
    this.darkness = sourceBiome === 'OLD_FOREST' ? 0.76 : type === 'cave' ? 0.48 : 0.24;
    this.tileSize = 32;
    this.cols = 48;
    this.rows = 34;
    this.width = this.cols * this.tileSize;
    this.height = this.rows * this.tileSize;
    this.isInfinite = false;
    this.npcs = [];
    this.signs = [];
    this.grid = Array.from({ length: this.rows }, () => new Array(this.cols).fill(TILE.ROCK));
    this.exit = { col: 3, row: Math.floor(this.rows / 2) };

    if (type === 'cave') this.generateCave();
    else this.generateMine();
    this.populateContents();
  }

  random(x, y, salt = 0) {
    let n = Math.imul(x, 374761393) ^ Math.imul(y, 668265263) ^ Math.imul(this.seed + salt, 1442695041);
    n = Math.imul(n ^ (n >>> 13), 1274126177);
    return ((n ^ (n >>> 16)) >>> 0) / 4294967296;
  }

  generateCave() {
    for (let row = 1; row < this.rows - 1; row++) {
      for (let col = 1; col < this.cols - 1; col++) {
        this.grid[row][col] = this.random(col, row, 10) > 0.47 ? TILE.DIRT_PATH : TILE.ROCK;
      }
    }
    for (let generation = 0; generation < 4; generation++) {
      const next = this.grid.map((row) => [...row]);
      for (let row = 1; row < this.rows - 1; row++) {
        for (let col = 1; col < this.cols - 1; col++) {
          let rocks = 0;
          for (let y = -1; y <= 1; y++) for (let x = -1; x <= 1; x++) {
            if (x !== 0 || y !== 0) rocks += this.grid[row + y][col + x] === TILE.ROCK ? 1 : 0;
          }
          next[row][col] = rocks >= 5 ? TILE.ROCK : TILE.DIRT_PATH;
        }
      }
      this.grid = next;
    }
    this.carveRoom(1, this.exit.row - 2, 9, this.exit.row + 2);
    this.carveRoom(19, 10, 31, 24);
    this.carveCorridor(7, this.exit.row, 23, 17);
  }

  generateMine() {
    const rooms = [
      { x: 2, y: 13, w: 8, h: 8 },
      { x: 14, y: 5 + Math.floor(this.random(1, 1, 30) * 8), w: 10, h: 9 },
      { x: 28, y: 16 + Math.floor(this.random(2, 2, 31) * 6), w: 10, h: 8 },
      { x: 38, y: 7 + Math.floor(this.random(3, 3, 32) * 8), w: 7, h: 10 },
    ];
    rooms.forEach((room) => this.carveRoom(room.x, room.y, room.x + room.w, room.y + room.h));
    for (let i = 0; i < rooms.length - 1; i++) {
      const a = rooms[i];
      const b = rooms[i + 1];
      this.carveCorridor(a.x + Math.floor(a.w / 2), a.y + Math.floor(a.h / 2), b.x + Math.floor(b.w / 2), b.y + Math.floor(b.h / 2));
    }
    this.exit.row = 17;
    this.carveCorridor(this.exit.col, this.exit.row, 6, 17);
  }

  carveRoom(x1, y1, x2, y2) {
    for (let row = Math.max(1, y1); row < Math.min(this.rows - 1, y2); row++) {
      for (let col = Math.max(1, x1); col < Math.min(this.cols - 1, x2); col++) this.grid[row][col] = TILE.DIRT_PATH;
    }
  }

  carveCorridor(x1, y1, x2, y2) {
    const stepX = x1 <= x2 ? 1 : -1;
    for (let x = x1; x !== x2 + stepX; x += stepX) this.carveRoom(x, y1 - 1, x + 1, y1 + 2);
    const stepY = y1 <= y2 ? 1 : -1;
    for (let y = y1; y !== y2 + stepY; y += stepY) this.carveRoom(x2, y, x2 + 1, y + 1);
  }

  populateContents() {
    this.grid[this.exit.row][this.exit.col] = TILE.COBBLESTONE;
    const floors = [];
    for (let row = 2; row < this.rows - 2; row++) for (let col = 4; col < this.cols - 2; col++) {
      if (this.grid[row][col] === TILE.DIRT_PATH) floors.push({ col, row });
    }
    const chooseFloor = (salt) => floors[Math.floor(this.random(salt, salt * 2, 70) * floors.length)];
    const enemyCount = this.type === 'cave' ? 6 : 8;
    this.enemySpawns = Array.from({ length: enemyCount }, (_, index) => {
      const pos = chooseFloor(index + 1);
      const roll = this.random(index, 1, 80);
      const type = this.type === 'mine' && roll > 0.72 ? 'uruk' : roll > 0.52 ? 'orc' : 'spider';
      return { type, col: pos.col, row: pos.row, isMiniBoss: false };
    });
    const rewardType = this.type === 'mine' ? 'sword_temper' : 'potion_pack';
    const pos = chooseFloor(95);
    this.chests = [{
      id: `dungeon_${this.seed}`,
      col: pos.col,
      row: pos.row,
      opened: false,
      rewardType,
      title: this.type === 'mine' ? 'Herramientas de los Enanos' : 'Alijo de la Cueva',
      description: this.type === 'mine'
        ? 'Los útiles enanos han reforjado el filo de Dardo.'
        : 'Un alijo olvidado restaura tus provisiones de Miruvor.',
    }];
  }

  getTile(col, row) {
    if (row < 0 || row >= this.rows || col < 0 || col >= this.cols) return TILE.ROCK;
    return this.grid[row][col];
  }

  getTileAtPixel(px, py) {
    return this.getTile(Math.floor(px / this.tileSize), Math.floor(py / this.tileSize));
  }

  isRectBlocked(cx, cy, halfW, halfH) {
    return [[cx - halfW, cy - halfH], [cx + halfW, cy - halfH], [cx - halfW, cy + halfH], [cx + halfW, cy + halfH]]
      .some(([x, y]) => SOLID_TILES.has(this.getTileAtPixel(x, y)));
  }
}

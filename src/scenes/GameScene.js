/**
 * GameScene — Escena principal de juego (Etapa 1: La Comarca).
 * Orquesta el mapa, colisiones, combate en tiempo real, cámara, IA de enemigos,
 * cofres, diálogos con NPCs, progresión y misiones.
 */
import { SpriteAtlas, TILE } from '../assets/SpriteAtlas.js';
import { WorldGenerator } from '../maps/WorldGenerator.js';
import { DungeonMap } from '../maps/DungeonMap.js';
import { Player } from '../entities/Player.js';
import { Enemy } from '../entities/Enemy.js';
import { ArrowProjectile, EnemyArrowProjectile, LootDrop, FloatingText, ElfGuardian } from '../entities/WorldEntities.js';
import { CameraSystem } from '../systems/CameraSystem.js';
import { HUD } from '../ui/HUD.js';
import { sfx } from '../systems/SoundFX.js';
import { SaveSystem } from '../systems/SaveSystem.js';

export class GameScene {
  constructor(canvas, input) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.ctx.imageSmoothingEnabled = false;
    this.input = input;

    this.atlas = new SpriteAtlas();
    this.hud = new HUD();
    this.state = 'TITLE'; // 'TITLE' | 'PLAYING' | 'DIALOG' | 'INVENTORY' | 'PAUSED' | 'GAMEOVER'

    this.waterAnimTimer = 0;
    this.waterFrameIndex = 0;

    this.activeDialog = null;
    this.dialogPageIndex = 0;
    this.discoveredChunks = new Set();
    this.chartedZones = new Set();
    this.defeatedProceduralEnemies = new Set();
    this.defeatedOverworldEnemies = new Set();
    this.clearedDungeonChests = new Set();
    this.elfGifts = new Set();
    this.autoSaveTimer = 0;
    this.saveSystem = new SaveSystem();

    this.initWorld();
    this.loadProgress();
    this.bindUIButtons();
    window.addEventListener('beforeunload', () => this.saveProgress());
  }

  initWorld({ clearSave = false } = {}) {
    if (clearSave) this.saveSystem.clear();
    this.discoveredChunks?.clear();
    this.chartedZones?.clear();
    this.defeatedProceduralEnemies?.clear();
    this.defeatedOverworldEnemies?.clear();
    this.clearedDungeonChests?.clear();
    this.elfGifts?.clear();
    this.map = new WorldGenerator();
    // Iniciar al jugador frente a la Puerta Redonda de Bolsón Cerrado en el mapa 1:5 de Hobbiton
    const startCol = this.map.shire?.spawnCol ?? 35;
    const startRow = this.map.shire?.spawnRow ?? 9.2;
    this.player = new Player(startCol * 32, startRow * 32);
    this.camera = new CameraSystem(this.canvas.width, this.canvas.height, Infinity, Infinity);
    this.camera.follow(this.player, 1, true);

    this.enemies = this.map.enemySpawns.map(
      (sp, index) => {
        const enemy = new Enemy(sp.type, (sp.col + 0.5) * 32, (sp.row + 0.5) * 32, sp.isMiniBoss);
        enemy.isAuthored = true;
        enemy.worldAuthored = true;
        enemy.spawnKey = `authored:${index}`;
        return enemy;
      }
    );
    this.arrows = [];
    this.enemyArrows = [];
    this.lootDrops = [];
    this.floatingTexts = [];
    this.elves = [];

    this.questState = {
      talkedToGandalf: false,
      orcsDefeated: 0,
      urukDefeated: false,
      completed: false,
      objectiveText: 'Habla con Gandalf en Bolsón Cerrado o explora el Bosque Viejo (Este)',
      secondary: [
        { id: 'cartographer', title: 'Cartógrafo: encuentra una Carta Regional', completed: false },
        { id: 'delver', title: 'Bajo la piedra: explora una cueva o mina', completed: false },
      ],
    };
    this.discoverCurrentChunk();
  }

  bindUIButtons() {
    const titleOverlay = document.getElementById('title-overlay');
    const pauseOverlay = document.getElementById('pause-overlay');
    const gameoverOverlay = document.getElementById('gameover-overlay');

    document.getElementById('btn-start-game').addEventListener('click', () => {
      sfx.init();
      titleOverlay.classList.remove('active');
      this.state = 'PLAYING';
    });

    document.getElementById('btn-resume').addEventListener('click', () => {
      pauseOverlay.classList.remove('active');
      this.state = 'PLAYING';
    });

    document.getElementById('btn-restart').addEventListener('click', () => {
      pauseOverlay.classList.remove('active');
      this.initWorld({ clearSave: true });
      this.state = 'PLAYING';
    });

    document.getElementById('btn-retry').addEventListener('click', () => {
      gameoverOverlay.classList.remove('active');
      this.initWorld({ clearSave: true });
      this.state = 'PLAYING';
    });

    document.getElementById('btn-claim-loot').addEventListener('click', () => this.claimLoot());
    document.getElementById('btn-close-shop').addEventListener('click', () => this.closeShop());
  }

  update(dt) {
    // Animación del agua del Río El Agua
    this.waterAnimTimer += dt;
    if (this.waterAnimTimer >= 0.45) {
      this.waterAnimTimer = 0;
      this.waterFrameIndex = (this.waterFrameIndex + 1) % 2;
      this.atlas.tiles[TILE.WATER] = this.atlas.waterFrames[this.waterFrameIndex];
    }

    if (this.state === 'TITLE') {
      if (this.input.wasPressed('Enter') || this.input.wasPressed('Space')) {
        document.getElementById('btn-start-game').click();
      }
      return;
    }

    if (this.state === 'GAMEOVER') {
      if (this.input.wasPressed('Enter')) {
        document.getElementById('btn-retry').click();
      }
      return;
    }

    if (this.state === 'LOOT') {
      if (this.input.wasPressed('KeyE') || this.input.wasPressed('Enter') || this.input.wasPressed('Space')) this.claimLoot();
      return;
    }

    if (this.state === 'SHOP') {
      if (this.input.wasPressed('Escape')) this.closeShop();
      return;
    }

    // Tecla ESC para Pausar / Reanudar
    if (this.input.wasPressed('Escape')) {
      this.togglePause();
      return;
    }

    // Tecla I para Abrir / Cerrar Inventario
    if (this.input.wasPressed('KeyI') && (this.state === 'PLAYING' || this.state === 'INVENTORY')) {
      this.toggleInventory();
      return;
    }

    if (this.map.isInfinite && this.input.wasPressed('KeyM') && (this.state === 'PLAYING' || this.state === 'MAP')) {
      this.toggleWorldMap();
      return;
    }

    // Si estamos leyendo un diálogo con NPC, cartel o cofre
    if (this.state === 'DIALOG') {
      if (this.input.wasPressed('KeyE') || this.input.wasPressed('Space') || this.input.wasPressed('Enter')) {
        this.advanceDialog();
      }
      return;
    }

    if (this.state !== 'PLAYING') {
      return;
    }

    // Atajos rápidos 1 y 2 para cambiar entre Poción y Arco
    if (this.input.wasPressed('Digit1')) {
      this.player.equippedItemId = 'potion';
      this.spawnNotice('Equipado: Frasco de Miruvor [Q]', '#ffe07d');
    } else if (this.input.wasPressed('Digit2')) {
      this.player.equippedItemId = 'bow';
      this.spawnNotice('Equipado: Arco de la Comarca [Q]', '#ffe07d');
    }

    const worldCallbacks = {
      notify: (msg, color) => this.spawnNotice(msg, color),
      spawnArrow: (x, y, dir) => {
        this.arrows.push(new ArrowProjectile(x, y, dir));
      },
    };

    const prevHp = this.player.hp;
    this.player.update(dt, this.input, this.map, worldCallbacks);
    this.discoverCurrentChunk();
    this.syncProceduralEnemies();
    this.autoSaveTimer += dt;
    if (this.autoSaveTimer >= 8) {
      this.autoSaveTimer = 0;
      this.saveProgress();
    }
    if (this.player.hp < prevHp) {
      this.camera.shake(0.18, 6);
      this.spawnFloatingText(this.player.x, this.player.y - 16, `-${prevHp - this.player.hp} ❤️`, '#ff4d4d');
    }

    if (this.player.hp <= 0) {
      this.state = 'GAMEOVER';
      document.getElementById('gameover-overlay').classList.add('active');
      return;
    }

    // Comprobar colisiones de la espada del jugador contra enemigos y hierba alta
    const swordBox = this.player.getSwordHitbox();
    if (swordBox) {
      this.checkSwordHits(swordBox);
    }

    // Actualizar proyectiles (flechas)
    for (const arrow of this.arrows) {
      arrow.update(dt, this.map, this.enemies, (enemy) => this.handleEnemyDefeated(enemy));
    }
    this.arrows = this.arrows.filter((a) => !a.dead);

    // Actualizar enemigos y proyectiles hostiles de los arqueros orcos.
    for (const enemy of this.enemies) {
      enemy.update(dt, this.player, this.map, {
        spawnEnemyArrow: (x, y, targetX, targetY, damage) => this.enemyArrows.push(new EnemyArrowProjectile(x, y, targetX, targetY, damage)),
      });
      if (enemy.justStoleCoins > 0) {
        this.spawnFloatingText(enemy.x, enemy.y - 12, `-${enemy.justStoleCoins} Monedas`, '#ffd700');
        this.spawnNotice('¡Un duende ha robado tus monedas!', '#ff9e7d');
        enemy.justStoleCoins = 0;
        this.saveProgress();
      }
    }
    for (const arrow of this.enemyArrows) arrow.update(dt, this.map, this.player);
    this.enemyArrows = this.enemyArrows.filter((arrow) => !arrow.dead);

    for (const elf of this.elves) {
      elf.update(dt, this.enemies, this.map, (enemy) => this.handleElfDefeatedEnemy(enemy));
    }

    // Actualizar objetos del suelo y recogerlos al pasar por encima
    for (const drop of this.lootDrops) {
      drop.update(dt);
      if (Math.hypot(this.player.x - drop.x, this.player.y - drop.y) < 22) {
        this.collectLoot(drop);
      }
    }
    this.lootDrops = this.lootDrops.filter((d) => !d.collected);

    // Actualizar textos flotantes
    for (const ft of this.floatingTexts) {
      ft.update(dt);
    }
    this.floatingTexts = this.floatingTexts.filter((ft) => ft.life > 0);

    // Interacción con tecla E (NPCs, Cofres, Carteles)
    const nearbyTarget = this.findNearbyInteractable();
    if (nearbyTarget && this.input.wasPressed('KeyE')) {
      this.triggerInteraction(nearbyTarget);
    }

    // Cámara sigue al jugador
    this.camera.follow(this.player, dt);
  }

  checkSwordHits(box) {
    // 1. Cortar hierba alta (al estilo Zelda) con probabilidad de soltar monedas o corazones
    const centerCol = Math.floor((box.x + box.w / 2) / 32);
    const centerRow = Math.floor((box.y + box.h / 2) / 32);
    if (
      centerRow >= 0 &&
      this.map.getTile(centerCol, centerRow) === TILE.TALL_GRASS
    ) {
      this.map.setTile(centerCol, centerRow, TILE.GRASS);
      if (Math.random() < 0.35) {
        const dropKind = Math.random() < 0.65 ? 'coin' : 'heart';
        this.lootDrops.push(new LootDrop((centerCol + 0.5) * 32, (centerRow + 0.5) * 32, dropKind));
      }
    }

    // 2. Impactar enemigos dentro del arco de la espada
    for (const enemy of this.enemies) {
      if (enemy.dead || this.player.swingHitIds.has(enemy.id)) continue;

      const ex1 = enemy.x - enemy.halfW;
      const ex2 = enemy.x + enemy.halfW;
      const ey1 = enemy.y - enemy.halfH;
      const ey2 = enemy.y + enemy.halfH;

      const overlaps =
        box.x < ex2 && box.x + box.w > ex1 && box.y < ey2 && box.y + box.h > ey1;

      if (overlaps) {
        this.player.swingHitIds.add(enemy.id);
        const killed = enemy.takeHit(this.player.swordDamage, this.player.x, this.player.y);
        this.camera.shake(0.09, 3);
        this.spawnFloatingText(enemy.x, enemy.y - 14, `-${this.player.swordDamage}`, '#ffe066');
        if (killed) {
          this.handleEnemyDefeated(enemy);
        }
      }
    }
  }

  handleEnemyDefeated(enemy) {
    if (enemy.worldAuthored) this.defeatedOverworldEnemies.add(enemy.spawnKey);
    else if (enemy.spawnKey && !enemy.isAuthored) this.defeatedProceduralEnemies.add(enemy.spawnKey);
    this.player.gainXp(enemy.xpReward, {
      notify: (msg, col) => this.spawnNotice(msg, col),
    });
    this.spawnFloatingText(enemy.x, enemy.y - 24, `+${enemy.xpReward} XP`, '#80e5ff');

    this.questState.orcsDefeated += 1;

    if (enemy.isMiniBoss) {
      this.questState.urukDefeated = true;
      this.questState.completed = true;
      this.questState.objectiveText = '¡Campamento Orco liberado! Habla con Gandalf o explora La Comarca.';
      this.lootDrops.push(new LootDrop(enemy.x, enemy.y, 'arnor_map'));
      this.spawnNotice('¡CAPITÁN URUK-HAI DERROTADO!', '#ffd700');
    } else {
      // Botín aleatorio (Corazón, Moneda o Flechas)
      const roll = Math.random();
      if (roll < 0.45) {
        this.lootDrops.push(new LootDrop(enemy.x, enemy.y, 'coin'));
      } else if (roll < 0.78) {
        this.lootDrops.push(new LootDrop(enemy.x, enemy.y, 'heart'));
      } else {
        this.lootDrops.push(new LootDrop(enemy.x, enemy.y, 'arrows'));
      }
    }
    this.saveProgress();
  }

  collectLoot(drop) {
    drop.collected = true;
    if (drop.kind === 'coin') {
      this.player.coins += 5;
      sfx.pickupCoin();
      this.spawnFloatingText(drop.x, drop.y - 10, '+5 Monedas', '#ffd700');
    } else if (drop.kind === 'heart') {
      this.player.hp = Math.min(this.player.maxHp, this.player.hp + 1);
      sfx.pickupHeart();
      this.spawnFloatingText(drop.x, drop.y - 10, '+1 Corazón', '#ff6b81');
    } else if (drop.kind === 'arrows') {
      this.player.arrows += 5;
      sfx.pickupCoin();
      this.spawnFloatingText(drop.x, drop.y - 10, '+5 Flechas', '#a8e090');
    } else if (drop.kind === 'arnor_map') {
      const mapItem = this.player.inventory.find((i) => i.id === 'map_arnor');
      if (mapItem) {
        mapItem.unlocked = true;
        mapItem.qty = 1;
      }
      const sting = this.player.inventory.find((item) => item.id === 'sting');
      if (sting) sting.unlocked = true;
      sfx.chestOpen();
      this.startDialog('Reliquia Recuperada', [
        '¡Has obtenido el MAPA ANTIGUO DE ARNOR del Capitán Uruk-hai!',
        'Con la frontera del Bosque Viejo asegurada, La Comarca vuelve a estar a salvo.',
        'Puedes seguir explorando los secretos de La Comarca, abrir los 4 cofres o hablar con Gandalf.',
      ]);
    }
    this.saveProgress();
  }

  findNearbyInteractable() {
    const px = this.player.x;
    const py = this.player.y;

    for (const npc of this.map.npcs) {
      const nx = (npc.col + 0.5) * 32;
      const ny = (npc.row + 0.5) * 32;
      if (Math.hypot(px - nx, py - ny) < 44) {
        return { kind: 'npc', data: npc, label: `Hablar con ${npc.name}` };
      }
    }

    for (const elf of this.elves) {
      if (Math.hypot(px - elf.x, py - elf.y) < 44) return { kind: 'elf', data: elf, label: `Hablar con ${elf.name}` };
    }

    for (const chest of this.map.chests) {
      if (chest.opened) continue;
      const cx = (chest.col + 0.5) * 32;
      const cy = (chest.row + 0.5) * 32;
      if (Math.hypot(px - cx, py - cy) < 42) {
        return { kind: 'chest', data: chest, label: 'Abrir Cofre del Tesoro' };
      }
    }

    const mapChests = this.map.getMapChestsForArea?.(
      Math.floor(px / 32) - 2, Math.floor(py / 32) - 2,
      Math.floor(px / 32) + 2, Math.floor(py / 32) + 2
    ) || [];
    for (const chest of mapChests) {
      const cx = (chest.col + 0.5) * 32;
      const cy = (chest.row + 0.5) * 32;
      if (Math.hypot(px - cx, py - cy) < 42) {
        return { kind: 'map_chest', data: chest, label: 'Recuperar Carta Regional' };
      }
    }

    if (this.map.isInfinite) {
      const pois = this.map.getPoisForArea(
        Math.floor(px / 32) - 2, Math.floor(py / 32) - 2,
        Math.floor(px / 32) + 2, Math.floor(py / 32) + 2
      );
      for (const poi of pois) {
        const ex = (poi.col + 0.5) * 32;
        const ey = (poi.row + 0.5) * 32;
        if (Math.hypot(px - ex, py - ey) < 42) {
          const label = poi.type === 'mine_dwarven' ? 'Entrar a Mina Enana' : poi.type === 'mine_abandoned' ? 'Entrar a Mina Abandonada' : 'Entrar a Cueva';
          return { kind: 'poi', data: poi, label };
        }
      }
    } else {
      const ex = (this.map.exit.col + 0.5) * 32;
      const ey = (this.map.exit.row + 0.5) * 32;
      if (Math.hypot(px - ex, py - ey) < 42) return { kind: 'dungeon_exit', label: 'Regresar al exterior' };
    }

    for (const sign of this.map.signs) {
      const sx = (sign.col + 0.5) * 32;
      const sy = (sign.row + 0.5) * 32;
      if (Math.hypot(px - sx, py - sy) < 42) {
        return { kind: 'sign', data: sign, label: 'Leer Cartel de Camino' };
      }
    }

    // Puertas de las viviendas de Hobbiton (Escala 1:5)
    for (const b of this.map.buildings || []) {
      if (!b.doorPoint) continue;
      if (Math.hypot(px - b.doorPoint.x, py - b.doorPoint.y) < 38) {
        return {
          kind: 'building_door',
          data: b,
          label: `Inspeccionar ${b.meta.title || b.def.name}`,
        };
      }
    }

    return null;
  }

  triggerInteraction(target) {
    if (target.kind === 'npc') {
      const npc = target.data;
      if (npc.isMerchant) {
        this.openShop();
        return;
      }
      if (npc.id === 'gandalf') {
        this.questState.talkedToGandalf = true;
        if (!this.questState.completed) {
          this.questState.objectiveText = 'Cruza el puente al Este y derrota al Capitán Uruk-hai (Sureste)';
        } else {
          this.startDialog(npc.name, [
            '¡Extraordinario trabajo, mi joven amigo! Has derrotado al Capitán Uruk-hai y recuperado el Mapa de Arnor.',
            'Gracias a tu valor, Delagua y Bolsón Cerrado están a salvo por ahora.',
            'En la Etapa 2 y 3 partiremos por el Gran Camino del Este hacia Bree y las Ruinas de Arnor.',
          ]);
          return;
        }
      }
      if (npc.isHealer) {
        this.player.hp = this.player.maxHp;
        sfx.pickupHeart();
      }
      this.startDialog(npc.name, npc.dialog);
    } else if (target.kind === 'elf') {
      this.interactWithElf(target.data);
    } else if (target.kind === 'chest') {
      this.openLootMenu(target.data);
      return;
    } else if (target.kind === 'map_chest') {
      const chest = target.data;
      this.map.openMapChest(chest.zoneKey);
      this.chartedZones.add(chest.zoneKey);
      this.refreshSecondaryQuests();
      sfx.chestOpen();
      this.startDialog('🗺️ Carta Regional Recuperada', [
        `Has encontrado la carta de la región ${chest.zoneX}, ${chest.zoneY}.`,
        'Pulsa [M] para ver el terreno revelado. Las regiones vecinas siguen ocultas hasta encontrar sus cartas.',
      ]);
    } else if (target.kind === 'poi') {
      this.enterDungeon(target.data);
    } else if (target.kind === 'dungeon_exit') {
      this.leaveDungeon();
    } else if (target.kind === 'sign') {
      this.startDialog('🪧 Cartel de La Comarca', [target.data.text]);
    } else if (target.kind === 'building_door') {
      const b = target.data;
      if (b.meta.healsPlayer) {
        this.player.hp = this.player.maxHp;
        sfx.pickupHeart();
      }
      const speaker = `${b.meta.title || b.def.name} — ${b.meta.resident || b.def.category}`;
      const pages = b.meta.dialog || [b.def.description];
      this.startDialog(speaker, pages);
    }
    this.saveProgress();
  }

  interactWithElf(elf) {
    if (elf.role === 'lembas') {
      const alreadyGifted = this.elfGifts.has(elf.spawnKey);
      if (!alreadyGifted) {
        const potion = this.player.inventory.find((item) => item.id === 'potion');
        if (potion) potion.qty += 1;
        this.elfGifts.add(elf.spawnKey);
        this.startDialog(elf.name, ['Toma este Pan de Lembas. Equípalo en el inventario y úsalo con [Q] para recuperar tus fuerzas.']);
      } else {
        this.startDialog(elf.name, ['Que las estrellas guíen tus pasos. Ya he compartido mis provisiones contigo.']);
      }
    } else if (elf.role === 'scout') {
      const col = Math.floor(elf.x / 32);
      const row = Math.floor(elf.y / 32);
      const cave = this.map.getPoisForArea(col - 640, row - 640, col + 640, row + 640).find((poi) => poi.type === 'cave');
      const clue = cave ? `He visto una cueva en las coordenadas de mundo (${cave.col}, ${cave.row}). Busca su entrada entre los árboles.` : 'Las cuevas se ocultan donde el bosque calla. Explora los claros al norte y al este.';
      this.startDialog(elf.name, [clue]);
    } else {
      this.startDialog(elf.name, ['Los orcos profanan nuestros senderos. Pronto necesitaremos a alguien que limpie sus campamentos: esa será una misión secundaria.']);
    }
  }

  openLootMenu(chest) {
    this.pendingChest = chest;
    document.getElementById('loot-title').textContent = `🎁 ${chest.title}`;
    document.getElementById('loot-description').textContent = chest.description;
    document.getElementById('loot-reward').textContent = this.getRewardPreview(chest);
    document.getElementById('loot-overlay').classList.add('active');
    this.state = 'LOOT';
  }

  getRewardPreview(chest) {
    if (chest.rewardType === 'bow_upgrade') return '🏹 Arco de la Comarca + 15 flechas';
    if (chest.rewardType === 'potion_pack') return '🧪 2 frascos de Miruvor + 25 monedas';
    if (chest.rewardType === 'heart_container') return '❤️ Contenedor de corazón';
    if (chest.rewardType === 'sword_temper') return '⚔️ Arma antigua o mejora de filo';
    return chest.description;
  }

  claimLoot() {
    const chest = this.pendingChest;
    if (!chest) return;
    chest.opened = true;
    if (!this.map.isInfinite && this.map.entrance) {
      this.clearedDungeonChests.add(this.map.entrance.id);
      this.refreshSecondaryQuests();
    }
    sfx.chestOpen();
    let rewardText = chest.description;
    if (chest.rewardType === 'bow_upgrade') {
      const bow = this.player.inventory.find((item) => item.id === 'bow');
      if (bow) bow.unlocked = true;
      this.player.arrows += 15;
      this.player.equippedItemId = 'bow';
    } else if (chest.rewardType === 'potion_pack') {
      const potion = this.player.inventory.find((item) => item.id === 'potion');
      if (potion) potion.qty += 2;
      this.player.coins += 25;
    } else if (chest.rewardType === 'heart_container') {
      this.player.maxHp = Math.min(6, this.player.maxHp + 1);
      this.player.hp = this.player.maxHp;
    } else if (chest.rewardType === 'sword_temper') {
      const weapon = this.player.unlockNextWeapon();
      if (weapon) rewardText = `Has encontrado ${weapon.name}. Requiere nivel ${weapon.requiredLevel} y causa ${weapon.damage} de daño.`;
      else {
        this.player.weaponBonusDamage += 1;
        this.player.refreshWeaponDamage();
        rewardText = 'El filo de tu arma actual ha sido templado: +1 daño.';
      }
    }
    this.pendingChest = null;
    document.getElementById('loot-overlay').classList.remove('active');
    this.startDialog(`🎁 ${chest.title}`, [rewardText]);
    this.saveProgress();
  }

  openShop() {
    const stock = [
      { id: 'shire_leather', price: 35 },
      { id: 'barrow_blade', price: 60 },
      { id: 'sting', price: 110 },
      { id: 'ranger_sword', price: 180 },
    ];
    const grid = document.getElementById('shop-grid');
    grid.innerHTML = '';
    document.getElementById('shop-coins').textContent = `Monedas disponibles: ${this.player.coins}`;
    for (const offer of stock) {
      const item = this.player.inventory.find((candidate) => candidate.id === offer.id);
      if (!item) continue;
      const button = document.createElement('button');
      button.className = 'shop-item';
      button.disabled = item.unlocked || this.player.coins < offer.price;
      button.innerHTML = `<strong>${item.icon} ${item.name}</strong><br>Daño/DEF: ${item.damage ?? item.defense} · Nivel ${item.requiredLevel}<br>🪙 ${item.unlocked ? 'Ya adquirido' : offer.price}`;
      button.addEventListener('click', () => this.buyShopItem(offer.id, offer.price));
      grid.appendChild(button);
    }
    document.getElementById('shop-overlay').classList.add('active');
    this.state = 'SHOP';
  }

  buyShopItem(itemId, price) {
    const item = this.player.inventory.find((candidate) => candidate.id === itemId);
    if (!item || item.unlocked || this.player.coins < price) return;
    this.player.coins -= price;
    item.unlocked = true;
    this.openShop();
    this.spawnNotice(`Adquirido: ${item.name}`, '#78e9ff');
    this.saveProgress();
  }

  closeShop() {
    document.getElementById('shop-overlay').classList.remove('active');
    if (this.state === 'SHOP') this.state = 'PLAYING';
  }

  startDialog(speaker, pages) {
    this.state = 'DIALOG';
    this.activeDialog = { speaker, pages };
    this.dialogPageIndex = 0;
    this.hud.dialogBox.classList.remove('hidden');
    this.hud.dialogSpeaker.textContent = speaker;
    this.hud.dialogText.textContent = pages[0];
    sfx.dialogStep();
  }

  advanceDialog() {
    this.dialogPageIndex += 1;
    if (this.dialogPageIndex < this.activeDialog.pages.length) {
      this.hud.dialogText.textContent = this.activeDialog.pages[this.dialogPageIndex];
      sfx.dialogStep();
    } else {
      this.hud.dialogBox.classList.add('hidden');
      this.activeDialog = null;
      this.state = 'PLAYING';
    }
  }

  toggleInventory() {
    const invOverlay = document.getElementById('inventory-overlay');
    if (this.state === 'INVENTORY') {
      invOverlay.classList.remove('active');
      this.state = 'PLAYING';
    } else {
      this.state = 'INVENTORY';
      this.hud.renderInventoryModal(this.player, (itemId, itemType) => {
        if (itemType === 'weapon') {
          this.player.equipWeapon(itemId, { notify: (text, color) => this.spawnNotice(text, color) });
        } else if (itemType === 'armor') {
          this.player.equipArmor(itemId, { notify: (text, color) => this.spawnNotice(text, color) });
        } else {
          this.player.equippedItemId = itemId;
        }
        sfx.dialogStep();
      });
      invOverlay.classList.add('active');
    }
  }

  toggleWorldMap() {
    const overlay = document.getElementById('world-map-overlay');
    if (this.state === 'MAP') {
      overlay.classList.remove('active');
      this.state = 'PLAYING';
    } else {
      this.state = 'MAP';
      this.hud.renderWorldMap(this.map, this.player, this.discoveredChunks, this.chartedZones, this.enemies);
      overlay.classList.add('active');
    }
  }

  enterDungeon(poi) {
    this.overworldReturn = { map: this.map, x: this.player.x, y: this.player.y };
    const type = poi.type === 'cave' ? 'cave' : 'mine';
    this.map = new DungeonMap({ type, seed: poi.seed, entrance: poi, sourceBiome: poi.biome });
    if (this.clearedDungeonChests.has(poi.id)) this.map.chests.forEach((chest) => { chest.opened = true; });
    this.player.x = (this.map.exit.col + 3.5) * 32;
    this.player.y = (this.map.exit.row + 0.5) * 32;
    this.camera = new CameraSystem(this.canvas.width, this.canvas.height, this.map.width, this.map.height);
    this.camera.follow(this.player, 1, true);
    this.enemies = this.map.enemySpawns.map((sp) => {
      const enemy = new Enemy(sp.type, (sp.col + 0.5) * 32, (sp.row + 0.5) * 32, false);
      enemy.isAuthored = true;
      return enemy;
    });
    this.elves = [];
    this.arrows = [];
    this.enemyArrows = [];
    this.startDialog(type === 'mine' ? '⛏️ Mina Subterránea' : '🕳️ Cueva Profunda', [
      'Las sombras se agitan bajo la piedra. Encuentra el cofre y regresa por la entrada cuando estés preparado.',
    ]);
    this.refreshSecondaryQuests();
  }

  leaveDungeon() {
    if (!this.overworldReturn) return;
    const returnTo = this.overworldReturn;
    this.map = returnTo.map;
    this.player.x = returnTo.x;
    this.player.y = returnTo.y;
    this.camera = new CameraSystem(this.canvas.width, this.canvas.height, Infinity, Infinity);
    this.camera.follow(this.player, 1, true);
    this.enemies = this.map.enemySpawns.map((sp, index) => {
      const enemy = new Enemy(sp.type, (sp.col + 0.5) * 32, (sp.row + 0.5) * 32, sp.isMiniBoss);
      enemy.isAuthored = true;
      enemy.worldAuthored = true;
      enemy.spawnKey = `authored:${index}`;
      return enemy;
    }).filter((enemy) => !this.defeatedOverworldEnemies.has(enemy.spawnKey));
    this.elves = [];
    this.enemyArrows = [];
    this.overworldReturn = null;
    this.startDialog('Exterior', ['El aire de la Tierra Media vuelve a rodearte.']);
  }

  togglePause() {
    const pauseOverlay = document.getElementById('pause-overlay');
    const invOverlay = document.getElementById('inventory-overlay');
    if (this.state === 'INVENTORY') {
      invOverlay.classList.remove('active');
      this.state = 'PLAYING';
      return;
    }
    if (this.state === 'SHOP') {
      this.closeShop();
      return;
    }
    if (this.state === 'MAP') {
      document.getElementById('world-map-overlay').classList.remove('active');
      this.state = 'PLAYING';
      return;
    }
    if (this.state === 'PAUSED') {
      pauseOverlay.classList.remove('active');
      this.state = 'PLAYING';
    } else if (this.state === 'PLAYING') {
      this.state = 'PAUSED';
      pauseOverlay.classList.add('active');
    }
  }

  spawnFloatingText(x, y, text, color) {
    this.floatingTexts.push(new FloatingText(x, y, text, color));
  }

  spawnNotice(text, color = '#ffe066') {
    this.spawnFloatingText(this.player.x, this.player.y - 22, text, color);
  }

  render() {
    const ctx = this.ctx;
    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

    const { x: camX, y: camY } = this.camera.getRenderOffset();
    const viewLeft = camX - 240;
    const viewRight = camX + this.canvas.width + 240;
    const viewTop = camY - 240;
    const viewBottom = camY + this.canvas.height + 240;

    // 1. Dibujar tiles visibles de La Comarca y del mundo abierto
    const startCol = Math.floor(camX / 32);
    const endCol = Math.ceil((camX + this.canvas.width) / 32);
    const startRow = Math.floor(camY / 32);
    const endRow = Math.ceil((camY + this.canvas.height) / 32);

    for (let r = startRow; r <= endRow; r++) {
      for (let c = startCol; c <= endCol; c++) {
        this.atlas.drawTerrainTile(ctx, this.map, c, r, c * 32 - camX, r * 32 - camY);
      }
    }

    // 1b. Dibujar terrazas de elevación de Hobbiton (Referencia B)
    for (const ledge of this.map.elevationLedges || []) {
      if (ledge.x + ledge.w < viewLeft || ledge.x > viewRight) continue;
      this.drawElevationCliff(ctx, ledge.x - camX, ledge.y - camY, ledge.w, ledge.h);
    }

    // 2. Dibujar carteles de madera
    for (const sign of this.map.signs) {
      const sx = sign.col * 32 - camX;
      const sy = sign.row * 32 - camY;
      ctx.fillStyle = '#5c3a1e';
      ctx.fillRect(sx + 13, sy + 14, 6, 14);
      ctx.fillStyle = '#8c5c30';
      ctx.fillRect(sx + 5, sy + 6, 22, 12);
      ctx.fillStyle = '#d9c29c';
      ctx.fillRect(sx + 8, sy + 9, 16, 2);
      ctx.fillRect(sx + 8, sy + 13, 12, 2);
    }

    // 3. Dibujar cofres del tesoro
    for (const chest of this.map.chests) {
      const cx = chest.col * 32 - camX;
      const cy = chest.row * 32 - camY;
      ctx.fillStyle = 'rgba(0,0,0,0.35)';
      ctx.fillRect(cx + 4, cy + 24, 24, 5);
      ctx.fillStyle = chest.opened ? '#4a3520' : '#8c5319';
      ctx.fillRect(cx + 5, cy + 8, 22, 18);
      ctx.fillStyle = '#d4af37';
      ctx.fillRect(cx + 5, cy + 14, 22, 3);
      ctx.fillRect(cx + 14, cy + 13, 4, 6);
    }

    for (const chest of this.map.getMapChestsForArea?.(startCol, startRow, endCol, endRow) || []) {
      this.drawChest(ctx, chest.col, chest.row, camX, camY, '#3c657d');
    }

    if (this.map.isInfinite) {
      for (const poi of this.map.getPoisForArea(startCol, startRow, endCol, endRow)) this.drawPoi(ctx, poi, camX, camY);
      for (const camp of this.map.getGoblinCampsForArea(startCol, startRow, endCol, endRow)) this.drawGoblinCamp(ctx, camp, camX, camY);
    } else {
      this.drawDungeonExit(ctx, this.map.exit, camX, camY);
    }

    // 4. Dibujar objetos recolectables (Corazones, Monedas, Flechas, Mapa)
    for (const drop of this.lootDrops) {
      drop.draw(ctx, camX, camY);
    }

    this.player.orcsNearby = this.enemies.some((enemy) => !enemy.dead && (enemy.type === 'orc' || enemy.type === 'uruk' || enemy.type === 'archer_orc') && Math.hypot(enemy.x - this.player.x, enemy.y - this.player.y) < 180);

    // 5. SISTEMA Y-SORTING para Viviendas de Hobbiton 1:5, NPCs, Elfos, Enemigos y Jugador
    const ySortedList = [];

    for (const b of this.map.buildings || []) {
      if (b.x + b.def.width < viewLeft || b.x > viewRight || b.y + b.def.height < viewTop || b.y > viewBottom) {
        continue;
      }
      ySortedList.push({
        sortY: b.sortY,
        draw: () => ctx.drawImage(b.def.sprite, Math.round(b.x - camX), Math.round(b.y - camY)),
      });
    }

    for (const npc of this.map.npcs) {
      ySortedList.push({
        sortY: (npc.row + 0.5) * 32 + 10,
        draw: () => this.drawNPC(ctx, npc, camX, camY),
      });
    }

    for (const elf of this.elves) {
      ySortedList.push({
        sortY: elf.y + 10,
        draw: () => elf.draw(ctx, camX, camY),
      });
    }

    for (const enemy of this.enemies) {
      if (enemy.dead) continue;
      ySortedList.push({
        sortY: enemy.y + enemy.halfH,
        draw: () => enemy.draw(ctx, camX, camY),
      });
    }

    ySortedList.push({
      sortY: this.player.y + this.player.halfH,
      draw: () => this.player.draw(ctx, camX, camY),
    });

    ySortedList.sort((a, b) => a.sortY - b.sortY);
    for (const item of ySortedList) {
      item.draw();
    }

    // 8. Dibujar flechas en vuelo
    for (const arrow of this.arrows) {
      arrow.draw(ctx, camX, camY);
    }
    for (const arrow of this.enemyArrows) arrow.draw(ctx, camX, camY);

    // 9. Dibujar textos flotantes
    for (const ft of this.floatingTexts) {
      ft.draw(ctx, camX, camY);
    }

    if (this.drawAmbientDarkness(ctx, camX, camY)) {
      // El aventurero no se pierde en la oscuridad: se dibuja por encima del ambiente oscurecido.
      this.player.draw(ctx, camX, camY);
    }

    // 10. Dibujar la interfaz HUD superior y el minimapa
    const nearbyTarget = this.state === 'PLAYING' ? this.findNearbyInteractable() : null;
    this.hud.draw(
      ctx,
      this.player,
      this.questState,
      this.map,
      this.enemies,
      nearbyTarget ? nearbyTarget.label : null
    );
  }

  drawElevationCliff(ctx, x, y, w, h) {
    const rx = Math.round(x);
    const ry = Math.round(y);
    ctx.fillStyle = '#336324';
    ctx.fillRect(rx, ry, w, 3);
    ctx.fillStyle = '#6e5b3e';
    ctx.fillRect(rx, ry + 3, w, h - 3);
    for (let sx = rx + 4; sx < rx + w - 8; sx += 12) {
      ctx.fillStyle = sx % 24 === 0 ? '#8c7653' : '#52422b';
      ctx.fillRect(sx, ry + 5, 7, h - 7);
    }
  }

  drawNPC(ctx, npc, camX, camY) {
    const sx = Math.round((npc.col + 0.5) * 32 - camX);
    const sy = Math.round((npc.row + 0.5) * 32 - camY);

    ctx.fillStyle = 'rgba(0,0,0,0.35)';
    ctx.fillRect(sx - 9, sy + 9, 18, 4);

    // Túnica
    ctx.fillStyle = npc.cloakColor;
    ctx.fillRect(sx - 8, sy - 4, 16, 14);

    // Rostro
    ctx.fillStyle = '#f2c199';
    ctx.fillRect(sx - 6, sy - 12, 12, 8);

    // Sombrero / Pelo (Sombrero puntiagudo si es Gandalf)
    ctx.fillStyle = npc.hatColor;
    if (npc.id === 'gandalf') {
      // Barba blanca larga de Gandalf
      ctx.fillStyle = '#e8eef2';
      ctx.fillRect(sx - 5, sy - 6, 10, 9);
      // Sombrero puntiagudo gris azulado
      ctx.fillStyle = npc.hatColor;
      ctx.fillRect(sx - 10, sy - 13, 20, 3);
      ctx.fillRect(sx - 6, sy - 18, 12, 5);
      ctx.fillRect(sx - 3, sy - 22, 6, 4);
    } else {
      ctx.fillRect(sx - 7, sy - 14, 14, 4);
    }

    // Signo de exclamación dorado sobre NPC importante
    ctx.fillStyle = '#ffd866';
    ctx.font = 'bold 11px "Courier New", monospace';
    ctx.textAlign = 'center';
    ctx.fillText(npc.name.split(' ')[0], sx, sy - 24);
    ctx.textAlign = 'left';
  }

  drawChest(ctx, col, row, camX, camY, color = '#8c5319') {
    const cx = col * 32 - camX;
    const cy = row * 32 - camY;
    ctx.fillStyle = 'rgba(0,0,0,0.35)';
    ctx.fillRect(cx + 4, cy + 24, 24, 5);
    ctx.fillStyle = color;
    ctx.fillRect(cx + 5, cy + 8, 22, 18);
    ctx.fillStyle = '#d4af37';
    ctx.fillRect(cx + 5, cy + 14, 22, 3);
    ctx.fillRect(cx + 14, cy + 13, 4, 6);
  }

  drawPoi(ctx, poi, camX, camY) {
    const sx = poi.col * 32 - camX;
    const sy = poi.row * 32 - camY;
    ctx.fillStyle = poi.type === 'mine_dwarven' ? '#b8a47e' : '#322a2a';
    ctx.fillRect(sx + 4, sy + 7, 24, 21);
    ctx.fillStyle = '#08090b';
    ctx.fillRect(sx + 9, sy + 12, 14, 16);
    if (poi.type !== 'cave') {
      ctx.fillStyle = '#d4af37';
      ctx.fillRect(sx + 5, sy + 8, 22, 3);
    }
  }

  drawDungeonExit(ctx, exit, camX, camY) {
    const sx = exit.col * 32 - camX;
    const sy = exit.row * 32 - camY;
    ctx.fillStyle = '#a78342';
    ctx.fillRect(sx + 4, sy + 5, 24, 23);
    ctx.fillStyle = '#182026';
    ctx.fillRect(sx + 9, sy + 10, 14, 18);
  }

  drawGoblinCamp(ctx, camp, camX, camY) {
    const sx = camp.col * 32 - camX;
    const sy = camp.row * 32 - camY;
    ctx.fillStyle = '#3b2c22';
    ctx.fillRect(sx - 20, sy - 15, 40, 30);
    ctx.fillStyle = '#17120e';
    ctx.fillRect(sx - 7, sy - 5, 14, 12);
    ctx.fillStyle = '#cf4d1c';
    ctx.fillRect(sx - 4, sy - 3, 8, 7);
    ctx.fillStyle = '#f2c14e';
    ctx.fillRect(sx - 2, sy - 1, 4, 4);
  }

  drawAmbientDarkness(ctx, camX, camY) {
    const inOldForest = this.map.isInfinite && this.map.getBiomeAtPixel(this.player.x, this.player.y) === 'OLD_FOREST';
    const darkness = inOldForest ? 0.62 : this.map.darkness || 0;
    if (!darkness) return false;
    const px = this.player.x - camX;
    const py = this.player.y - camY;
    const weapon = this.player.getEquippedWeapon();
    const stingLight = weapon?.glowsNearOrcs && this.player.orcsNearby;
    ctx.save();
    ctx.fillStyle = `rgba(2, 7, 9, ${darkness})`;
    ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    if (stingLight) {
      // Dardo revela el entorno cuando presiente orcos, no solo el sprite del jugador.
      const radius = inOldForest ? 300 : 250;
      ctx.globalCompositeOperation = 'destination-out';
      const light = ctx.createRadialGradient(px, py, 18, px, py, radius);
      light.addColorStop(0, 'rgba(0,0,0,0.88)');
      light.addColorStop(0.55, 'rgba(0,0,0,0.45)');
      light.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.fillStyle = light;
      ctx.fillRect(px - radius, py - radius, radius * 2, radius * 2);
    }
    ctx.restore();
    if (stingLight) {
      const radius = inOldForest ? 300 : 250;
      const glow = ctx.createRadialGradient(px, py, 10, px, py, radius * 0.72);
      glow.addColorStop(0, 'rgba(92, 230, 255, 0.22)');
      glow.addColorStop(1, 'rgba(92, 230, 255, 0)');
      ctx.fillStyle = glow;
      ctx.fillRect(px - radius, py - radius, radius * 2, radius * 2);
    }
    return true;
  }

  refreshSecondaryQuests() {
    const quests = this.questState.secondary || [];
    const cartographer = quests.find((quest) => quest.id === 'cartographer');
    const delver = quests.find((quest) => quest.id === 'delver');
    if (cartographer) cartographer.completed = this.chartedZones.size > 0;
    if (delver) delver.completed = this.clearedDungeonChests.size > 0;
  }

  discoverCurrentChunk() {
    if (!this.map.isInfinite) return;
    const chunk = this.map.getChunkAtPixel(this.player.x, this.player.y);
    this.discoveredChunks.add(`${chunk.x},${chunk.y}`);
  }

  syncProceduralEnemies() {
    if (!this.map.isInfinite) return;
    const current = this.map.getChunkAtPixel(this.player.x, this.player.y);
    const activeRadius = 1;
    this.enemies = this.enemies.filter((enemy) => {
      if (enemy.isAuthored) return true;
      const dx = Math.floor(enemy.x / (32 * 32)) - current.x;
      const dy = Math.floor(enemy.y / (32 * 32)) - current.y;
      return Math.abs(dx) <= activeRadius && Math.abs(dy) <= activeRadius;
    });
    const activeKeys = new Set(this.enemies.map((enemy) => enemy.spawnKey).filter(Boolean));
    for (let y = current.y - activeRadius; y <= current.y + activeRadius; y++) {
      for (let x = current.x - activeRadius; x <= current.x + activeRadius; x++) {
        for (const spawn of this.map.getEnemySpawnsForChunk(x, y)) {
          if (activeKeys.has(spawn.key) || this.defeatedProceduralEnemies.has(spawn.key)) continue;
          const enemy = new Enemy(spawn.type, (spawn.col + 0.5) * 32, (spawn.row + 0.5) * 32, false, spawn.threat || 0);
          enemy.spawnKey = spawn.key;
          this.enemies.push(enemy);
          activeKeys.add(spawn.key);
        }
        for (const spawn of this.map.getGoblinSpawnsForChunk(x, y)) {
          if (activeKeys.has(spawn.key) || this.defeatedProceduralEnemies.has(spawn.key)) continue;
          const enemy = new Enemy(spawn.type, (spawn.col + 0.5) * 32, (spawn.row + 0.5) * 32, false, spawn.threat || 0);
          enemy.spawnKey = spawn.key;
          this.enemies.push(enemy);
          activeKeys.add(spawn.key);
        }
      }
    }
    this.syncElves(current, activeRadius);
  }

  syncElves(current, activeRadius) {
    this.elves = this.elves.filter((elf) => {
      const chunk = this.map.getChunkAtPixel(elf.x, elf.y);
      return Math.abs(chunk.x - current.x) <= activeRadius && Math.abs(chunk.y - current.y) <= activeRadius;
    });
    const active = new Set(this.elves.map((elf) => elf.spawnKey));
    for (let y = current.y - activeRadius; y <= current.y + activeRadius; y++) {
      for (let x = current.x - activeRadius; x <= current.x + activeRadius; x++) {
        for (const spawn of this.map.getElfSpawnsForChunk(x, y)) {
          if (!active.has(spawn.key)) {
            this.elves.push(new ElfGuardian(spawn));
            active.add(spawn.key);
          }
        }
      }
    }
  }

  handleElfDefeatedEnemy(enemy) {
    if (enemy.worldAuthored || enemy.isMiniBoss) return;
    if (enemy.spawnKey) this.defeatedProceduralEnemies.add(enemy.spawnKey);
  }

  loadProgress() {
    const save = this.saveSystem.load();
    if (!save || save.version !== 2) return;
    const world = this.map;
    for (const [key, tile] of save.world?.modifiedTiles || []) world.modifiedTiles.set(key, tile);
    for (const key of save.world?.openedMapChests || []) world.openedMapChests.add(key);
    for (const chest of world.chests) chest.opened = (save.world?.openedChests || []).includes(chest.id);
    for (const [key, value] of Object.entries(save.player?.stats || {})) this.player[key] = value;
    this.player.equippedItemId = save.player?.equippedItemId || this.player.equippedItemId;
    this.player.equippedWeaponId = save.player?.equippedWeaponId || this.player.equippedWeaponId;
    this.player.equippedArmorId = save.player?.equippedArmorId || this.player.equippedArmorId;
    for (const savedItem of save.player?.inventory || []) {
      const item = this.player.inventory.find((candidate) => candidate.id === savedItem.id);
      if (item) Object.assign(item, savedItem);
    }
    if (Number.isFinite(save.player?.x) && Number.isFinite(save.player?.y)) {
      this.player.x = save.player.x;
      this.player.y = save.player.y;
      this.camera.follow(this.player, 1, true);
    }
    Object.assign(this.questState, save.questState || {});
    this.chartedZones = new Set(save.chartedZones || []);
    this.discoveredChunks = new Set(save.discoveredChunks || []);
    this.defeatedProceduralEnemies = new Set(save.defeatedProceduralEnemies || []);
    this.defeatedOverworldEnemies = new Set(save.defeatedOverworldEnemies || []);
    this.clearedDungeonChests = new Set(save.clearedDungeonChests || []);
    this.elfGifts = new Set(save.elfGifts || []);
    this.enemies = this.enemies.filter((enemy) => !this.defeatedOverworldEnemies.has(enemy.spawnKey));
    this.player.refreshWeaponDamage();
    this.player.maxHp = Math.min(6, this.player.maxHp);
    this.player.hp = Math.min(this.player.hp, this.player.maxHp);
    this.player.refreshArmorDefense();
    this.refreshSecondaryQuests();
    this.discoverCurrentChunk();
  }

  saveProgress() {
    // Los interiores se guardan al volver al exterior; el mundo principal es la fuente persistente.
    const world = this.map.isInfinite ? this.map : this.overworldReturn?.map;
    if (!world) return;
    const stats = ['maxHp', 'hp', 'weaponBonusDamage', 'level', 'xp', 'nextLevelXp', 'coins', 'arrows'];
    const playerStats = Object.fromEntries(stats.map((key) => [key, this.player[key]]));
    this.saveSystem.save({
      version: 2,
      world: {
        modifiedTiles: [...world.modifiedTiles.entries()],
        openedMapChests: [...world.openedMapChests],
        openedChests: world.chests.filter((chest) => chest.opened).map((chest) => chest.id),
      },
      player: {
        x: this.map.isInfinite ? this.player.x : this.overworldReturn.x,
        y: this.map.isInfinite ? this.player.y : this.overworldReturn.y,
        stats: playerStats,
        equippedItemId: this.player.equippedItemId,
        equippedWeaponId: this.player.equippedWeaponId,
        equippedArmorId: this.player.equippedArmorId,
        inventory: this.player.inventory.map(({ id, qty, unlocked }) => ({ id, qty, unlocked })),
      },
      questState: this.questState,
      chartedZones: [...this.chartedZones],
      discoveredChunks: [...this.discoveredChunks],
      defeatedProceduralEnemies: [...this.defeatedProceduralEnemies],
      defeatedOverworldEnemies: [...this.defeatedOverworldEnemies],
      clearedDungeonChests: [...this.clearedDungeonChests],
      elfGifts: [...this.elfGifts],
    });
  }
}

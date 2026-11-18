/**
 * Player — Aventurero de la Tierra Media controlable en 4 direcciones.
 * Incluye:
 *  - Movimiento fluido con deslizamiento en esquinas y colisiones por eje.
 *  - Animaciones de caminar en 4 direcciones y estado idle.
 *  - Ataque cuerpo a cuerpo con espada (arco de barrido estilo Zelda ALTTP).
 *  - Disparo de flechas con el Arco o curación con Poción Miruvor mediante [Q].
 *  - Retroceso (knockback) y frames de invulnerabilidad tras recibir daño.
 *  - Efecto de ralentización temporal por telaraña si es mordido por una Araña.
 */
import { sfx } from '../systems/SoundFX.js';

export class Player {
  constructor(x, y) {
    this.x = x;
    this.y = y;
    this.halfW = 10;
    this.halfH = 11;

    this.baseSpeed = 165;
    this.dir = 'down'; // 'up' | 'down' | 'left' | 'right'
    this.isMoving = false;
    this.animTimer = 0;
    this.animFrame = 0;

    // Estadísticas RPG
    this.maxHp = 6; // Límite temporal de salud: seis corazones/puntos visibles.
    this.hp = 6;
    this.armorDefense = 0;
    this.equippedArmorId = 'traveler_cloak';
    this.armorCooldown = 0;
    this.armorCooldownDuration = 3;
    this.lastArmorBlocked = false;
    this.swordDamage = 1;
    this.weaponBonusDamage = 0;
    this.equippedWeaponId = 'traveler_dagger';
    this.orcsNearby = false;
    this.level = 1;
    this.xp = 0;
    this.nextLevelXp = 60;
    this.coins = 15;
    this.arrows = 8;

    // Combate y estados
    this.attackTimer = 0;
    this.attackDuration = 0.22;
    this.attackCooldown = 0;
    this.swingHitIds = new Set();

    this.invulnTimer = 0;
    this.knockbackVx = 0;
    this.knockbackVy = 0;
    this.knockbackTimer = 0;
    this.webSlowTimer = 0;

    // Inventario
    this.equippedItemId = 'potion';
    this.inventory = [
      { id: 'traveler_dagger', name: 'Daga del Viajero', icon: '🗡️', type: 'weapon', qty: 1, unlocked: true, damage: 1, requiredLevel: 1, color: '#e6f4ff', desc: 'Arma humilde pero fiable. La hoja con la que comienza todo aventurero.' },
      { id: 'barrow_blade', name: 'Hoja de los Túmulos', icon: '🗡️', type: 'weapon', qty: 1, unlocked: false, damage: 2, requiredLevel: 2, color: '#9ad9ff', desc: 'Una hoja antigua recuperada de las Quebradas de los Túmulos.' },
      { id: 'sting', name: 'Dardo de Frodo', icon: '✨', type: 'weapon', qty: 1, unlocked: false, damage: 3, requiredLevel: 3, color: '#78e9ff', glowsNearOrcs: true, desc: 'La hoja élfica de Gondolin brilla en azul cuando hay orcos o Uruks cerca.' },
      { id: 'ranger_sword', name: 'Espada del Montaraz', icon: '⚔️', type: 'weapon', qty: 1, unlocked: false, damage: 4, requiredLevel: 5, color: '#d6e3d1', desc: 'Una espada equilibrada para la larga marcha por Eriador.' },
      { id: 'orcrist', name: 'Orcrist, Hiendeorcos', icon: '⚔️', type: 'weapon', qty: 1, unlocked: false, damage: 5, requiredLevel: 7, color: '#9ce6ff', desc: 'Hoja élfica inspirada en las armas perdidas de Gondolin.' },
      { id: 'isildur_sword', name: 'Espada de Isildur', icon: '⚔️', type: 'weapon', qty: 1, unlocked: false, damage: 6, requiredLevel: 9, color: '#ffe29a', desc: 'Una reliquia de los Dúnedain, pesada de historia y voluntad.' },
      { id: 'glamdring', name: 'Glamdring', icon: '✨', type: 'weapon', qty: 1, unlocked: false, damage: 7, requiredLevel: 11, color: '#e9efff', desc: 'La Foe-hammer, una gran espada élfica digna de un mago gris.' },
      { id: 'anduril', name: 'Andúril, Llama del Oeste', icon: '⚔️', type: 'weapon', qty: 1, unlocked: false, damage: 9, requiredLevel: 14, color: '#ffffff', desc: 'El arma culminante: exige experiencia y valor antes de poder blandirla.' },
      {
        id: 'traveler_cloak',
        name: 'Capa de Viajero',
        icon: '🧥',
        type: 'armor',
        qty: 1,
        unlocked: true,
        defense: 0,
        requiredLevel: 1,
        desc: 'Ropas sencillas sin protección real.',
      },
      { id: 'shire_leather', name: 'Cuero de la Comarca', icon: '🛡️', type: 'armor', qty: 1, unlocked: false, defense: 1, requiredLevel: 2, desc: 'Cuero reforzado por artesanos hobbits.' },
      { id: 'elven_cloak', name: 'Capa Élfica de Lórien', icon: '🟢', type: 'armor', qty: 1, unlocked: false, defense: 2, requiredLevel: 4, desc: 'Tejida por los elfos; ligera y protectora.' },
      { id: 'dunedain_mail', name: 'Malla de los Dúnedain', icon: '🛡️', type: 'armor', qty: 1, unlocked: false, defense: 3, requiredLevel: 7, desc: 'Anillos de acero para quien viaja por tierras peligrosas.' },
      { id: 'mithril_coat', name: 'Cota de Mithril', icon: '✨', type: 'armor', qty: 1, unlocked: false, defense: 4, requiredLevel: 10, desc: 'Una armadura de valor incalculable, casi imposible de perforar.' },
      {
        id: 'potion',
        name: 'Frasco de Miruvor',
        icon: '🧪',
        type: 'active',
        qty: 2,
        desc: 'Licor cordial de Rivendel. Equípalo y pulsa [Q] para restaurar 3 corazones.',
      },
      {
        id: 'bow',
        name: 'Arco de la Comarca',
        icon: '🏹',
        type: 'active',
        unlocked: false,
        qty: 1,
        desc: 'Permite disparar flechas a distancia con [Q]. Encuentra el cofre del Viejo Molino para desbloquearlo.',
      },
      {
        id: 'map_arnor',
        name: 'Mapa de Arnor',
        icon: '📜',
        type: 'quest',
        unlocked: false,
        qty: 0,
        desc: 'Antiguo mapa en poder del Capitán Uruk-hai que revela la ruta segura hacia Bree.',
      },
    ];
    this.refreshWeaponDamage();
    this.refreshArmorDefense();
  }

  getEquippedWeapon() {
    return this.inventory.find((item) => item.id === this.equippedWeaponId);
  }

  refreshWeaponDamage() {
    const weapon = this.getEquippedWeapon();
    this.swordDamage = (weapon?.damage || 1) + this.weaponBonusDamage;
  }

  equipWeapon(itemId, worldCallbacks) {
    const weapon = this.inventory.find((item) => item.id === itemId && item.type === 'weapon');
    if (!weapon || !weapon.unlocked) return false;
    if (this.level < weapon.requiredLevel) {
      worldCallbacks?.notify(`Requiere nivel ${weapon.requiredLevel}: ${weapon.name}`, '#ff9e7d');
      return false;
    }
    this.equippedWeaponId = weapon.id;
    this.refreshWeaponDamage();
    worldCallbacks?.notify(`Equipada: ${weapon.name}`, '#78e9ff');
    return true;
  }

  unlockNextWeapon() {
    const weapon = this.inventory.find((item) => item.type === 'weapon' && !item.unlocked);
    if (!weapon) return null;
    weapon.unlocked = true;
    return weapon;
  }

  getEquippedArmor() {
    return this.inventory.find((item) => item.id === this.equippedArmorId);
  }

  refreshArmorDefense() {
    this.armorDefense = this.getEquippedArmor()?.defense || 0;
  }

  equipArmor(itemId, worldCallbacks) {
    const armor = this.inventory.find((item) => item.id === itemId && item.type === 'armor');
    if (!armor || !armor.unlocked) return false;
    if (this.level < armor.requiredLevel) {
      worldCallbacks?.notify(`Requiere nivel ${armor.requiredLevel}: ${armor.name}`, '#ff9e7d');
      return false;
    }
    this.equippedArmorId = armor.id;
    this.refreshArmorDefense();
    worldCallbacks?.notify(`Equipada: ${armor.name} (DEF ${armor.defense})`, '#a8e090');
    return true;
  }

  getSpeed() {
    return this.webSlowTimer > 0 ? this.baseSpeed * 0.55 : this.baseSpeed;
  }

  update(dt, input, map, worldCallbacks) {
    // Actualizar temporizadores
    if (this.invulnTimer > 0) this.invulnTimer = Math.max(0, this.invulnTimer - dt);
    if (this.attackCooldown > 0) this.attackCooldown = Math.max(0, this.attackCooldown - dt);
    if (this.webSlowTimer > 0) this.webSlowTimer = Math.max(0, this.webSlowTimer - dt);
    if (this.armorCooldown > 0) this.armorCooldown = Math.max(0, this.armorCooldown - dt);

    // Gestión del retroceso por impacto
    if (this.knockbackTimer > 0) {
      this.knockbackTimer = Math.max(0, this.knockbackTimer - dt);
      this.moveWithCollision(this.knockbackVx * dt, this.knockbackVy * dt, map);
    }

    // Ataque en curso
    if (this.attackTimer > 0) {
      this.attackTimer = Math.max(0, this.attackTimer - dt);
    }

    // Iniciar ataque con espada (Espacio o Clic izquierdo)
    if (
      (input.wasPressed('Space') || input.consumeClick()) &&
      this.attackTimer <= 0 &&
      this.attackCooldown <= 0
    ) {
      this.startSwordAttack();
    }

    // Usar objeto equipado con Q
    if (input.wasPressed('KeyQ')) {
      this.useEquippedItem(worldCallbacks);
    }

    // Movimiento en 4 direcciones (permitido incluso con ligera reducción al terminar el golpe)
    const moveFactor = this.attackTimer > 0.1 ? 0.35 : 1.0;
    const { dx, dy } = input.getMovementVector();

    if (dx !== 0 || dy !== 0) {
      this.isMoving = true;
      if (this.attackTimer <= 0) {
        if (Math.abs(dx) > Math.abs(dy)) {
          this.dir = dx > 0 ? 'right' : 'left';
        } else {
          this.dir = dy > 0 ? 'down' : 'up';
        }
      }
      const speed = this.getSpeed() * moveFactor;
      this.moveWithCollision(dx * speed * dt, dy * speed * dt, map);

      this.animTimer += dt;
      if (this.animTimer >= 0.14) {
        this.animTimer = 0;
        this.animFrame = (this.animFrame + 1) % 4;
      }
    } else {
      this.isMoving = false;
      this.animFrame = 0;
    }
  }

  moveWithCollision(stepX, stepY, map) {
    // Eje X
    if (stepX !== 0) {
      const nextX = this.x + stepX;
      if (!map.isRectBlocked(nextX, this.y, this.halfW, this.halfH)) {
        this.x = nextX;
      }
    }
    // Eje Y
    if (stepY !== 0) {
      const nextY = this.y + stepY;
      if (!map.isRectBlocked(this.x, nextY, this.halfW, this.halfH)) {
        this.y = nextY;
      }
    }
  }

  startSwordAttack() {
    this.attackTimer = this.attackDuration;
    this.attackCooldown = 0.28;
    this.swingHitIds.clear();
    sfx.swordSwing();
  }

  getSwordHitbox() {
    if (this.attackTimer <= 0) return null;
    const reach = 26;
    const size = 28;
    let hx = this.x;
    let hy = this.y;

    if (this.dir === 'up') hy -= reach;
    else if (this.dir === 'down') hy += reach;
    else if (this.dir === 'left') hx -= reach;
    else if (this.dir === 'right') hx += reach;

    return {
      x: hx - size / 2,
      y: hy - size / 2,
      w: size,
      h: size,
    };
  }

  useEquippedItem(worldCallbacks) {
    const item = this.inventory.find((i) => i.id === this.equippedItemId);
    if (!item) return;

    if (item.id === 'potion') {
      if (item.qty <= 0) {
        worldCallbacks.notify('No te quedan Frascos de Miruvor', '#ff8080');
        return;
      }
      if (this.hp >= this.maxHp) {
        worldCallbacks.notify('Tus corazones ya están al máximo', '#ffe07d');
        return;
      }
      item.qty -= 1;
      this.hp = Math.min(this.maxHp, this.hp + 3);
      sfx.pickupHeart();
      worldCallbacks.notify('+3 Corazones (Miruvor)', '#7dff8b');
    } else if (item.id === 'bow') {
      if (!item.unlocked) {
        worldCallbacks.notify('Aún no has encontrado el Arco (Busca en el Viejo Molino)', '#ff9e7d');
        return;
      }
      if (this.arrows <= 0) {
        worldCallbacks.notify('¡Sin flechas! Derrota enemigos o corta arbustos', '#ff8080');
        return;
      }
      this.arrows -= 1;
      sfx.arrowShoot();
      worldCallbacks.spawnArrow(this.x, this.y, this.dir);
    }
  }

  takeDamage(amount, sourceX, sourceY, isSpiderWeb = false) {
    if (this.invulnTimer > 0) return false;

    const armorReady = this.armorDefense > 0 && this.armorCooldown <= 0;
    const finalDamage = armorReady ? Math.max(0, amount - this.armorDefense) : amount;
    this.lastArmorBlocked = armorReady;
    if (armorReady) this.armorCooldown = this.armorCooldownDuration;
    this.hp = Math.max(0, this.hp - finalDamage);
    this.invulnTimer = 0.85;
    if (finalDamage > 0) sfx.playerHurt();

    const angle = Math.atan2(this.y - sourceY, this.x - sourceX);
    this.knockbackVx = Math.cos(angle) * 230;
    this.knockbackVy = Math.sin(angle) * 230;
    this.knockbackTimer = 0.16;

    if (isSpiderWeb) {
      this.webSlowTimer = 2.4;
    }
    return true;
  }

  gainXp(amount, worldCallbacks) {
    this.xp += amount;
    if (this.xp >= this.nextLevelXp) {
      this.xp -= this.nextLevelXp;
      this.level += 1;
      this.nextLevelXp = Math.round(this.nextLevelXp * 1.45);
      const previousMaxHp = this.maxHp;
      this.maxHp = Math.min(6, this.maxHp + 1);
      this.hp = this.maxHp;
      sfx.chestOpen();
      if (worldCallbacks) {
        const bonus = this.maxHp > previousMaxHp ? ' (+1 Corazón Máx.)' : ' (Salud restaurada)';
        worldCallbacks.notify(`¡SUBIDA A NIVEL ${this.level}!${bonus}`, '#ffd866');
      }
    }
  }

  draw(ctx, camX, camY) {
    const sx = Math.round(this.x - camX);
    const sy = Math.round(this.y - camY);

    // Parpadeo de invulnerabilidad
    if (this.invulnTimer > 0 && Math.floor(this.invulnTimer * 16) % 2 === 0) {
      return;
    }

    // Sombra bajo los pies
    ctx.fillStyle = 'rgba(0, 0, 0, 0.35)';
    ctx.fillRect(sx - 9, sy + 9, 18, 5);

    // Indicador de telaraña si está ralentizado
    if (this.webSlowTimer > 0) {
      ctx.strokeStyle = '#d8e8f8';
      ctx.lineWidth = 2;
      ctx.strokeRect(sx - 12, sy - 14, 24, 26);
    }

    // Rebote de caminar (walk bob)
    const bob = this.isMoving && this.animFrame % 2 === 1 ? -2 : 0;
    const legShift = this.isMoving ? (this.animFrame % 2 === 0 ? -2 : 2) : 0;

    // Capa élfica verde montaraz (al dorso)
    ctx.fillStyle = '#2d5e29';
    ctx.fillRect(sx - 9, sy - 4 + bob, 18, 12);

    // Botas de cuero
    ctx.fillStyle = '#4e2f18';
    ctx.fillRect(sx - 6, sy + 7 + (legShift > 0 ? -1 : 0), 5, 5);
    ctx.fillRect(sx + 1, sy + 7 + (legShift < 0 ? -1 : 0), 5, 5);

    // Túnica de aventurero (verde bosque y cinturón dorado)
    ctx.fillStyle = '#3e7a37';
    ctx.fillRect(sx - 7, sy - 3 + bob, 14, 11);
    ctx.fillStyle = '#d4af37';
    ctx.fillRect(sx - 7, sy + 3 + bob, 14, 2);

    // Escudo de roble en el costado según la dirección
    ctx.fillStyle = '#734822';
    if (this.dir === 'down' || this.dir === 'right') {
      ctx.fillRect(sx - 10, sy - 2 + bob, 4, 9);
      ctx.fillStyle = '#c0c7d0';
      ctx.fillRect(sx - 9, sy + bob, 2, 5);
    } else {
      ctx.fillRect(sx + 6, sy - 2 + bob, 4, 9);
    }

    // Cabeza y cabello castaño rizado (estilo Hobbit / Joven Dúnedain)
    ctx.fillStyle = '#f2c199';
    ctx.fillRect(sx - 6, sy - 13 + bob, 12, 10);

    // Cabello
    ctx.fillStyle = '#5a3518';
    ctx.fillRect(sx - 7, sy - 15 + bob, 14, 5);
    if (this.dir === 'up') {
      ctx.fillRect(sx - 7, sy - 14 + bob, 14, 10);
    } else if (this.dir === 'left') {
      ctx.fillRect(sx - 2, sy - 14 + bob, 9, 8);
      // Ojo izquierdo
      ctx.fillStyle = '#182026';
      ctx.fillRect(sx - 5, sy - 9 + bob, 2, 3);
    } else if (this.dir === 'right') {
      ctx.fillRect(sx - 7, sy - 14 + bob, 9, 8);
      // Ojo derecho
      ctx.fillStyle = '#182026';
      ctx.fillRect(sx + 3, sy - 9 + bob, 2, 3);
    } else {
      // Mirando abajo (2 ojos)
      ctx.fillStyle = '#182026';
      ctx.fillRect(sx - 4, sy - 9 + bob, 2, 3);
      ctx.fillRect(sx + 2, sy - 9 + bob, 2, 3);
    }

    // Dibujar el arco de ataque con la espada Dardo (brillo azul élfico)
    if (this.attackTimer > 0) {
      this.drawSwordSwing(ctx, sx, sy);
    }
  }

  drawSwordSwing(ctx, sx, sy) {
    const progress = 1 - this.attackTimer / this.attackDuration;
    let baseAngle = 0;
    if (this.dir === 'right') baseAngle = 0;
    else if (this.dir === 'down') baseAngle = Math.PI / 2;
    else if (this.dir === 'left') baseAngle = Math.PI;
    else if (this.dir === 'up') baseAngle = -Math.PI / 2;

    const swingAngle = baseAngle - 0.9 + progress * 1.8;

    ctx.save();
    ctx.translate(sx, sy);

    // Estela luminosa de Dardo (azul élfico)
    const weapon = this.getEquippedWeapon();
    const glow = weapon?.glowsNearOrcs && this.orcsNearby;
    ctx.strokeStyle = glow ? 'rgba(84, 224, 255, 0.95)' : this.swordDamage > 1 ? 'rgba(130, 235, 255, 0.85)' : 'rgba(200, 240, 255, 0.7)';
    ctx.lineWidth = 6;
    ctx.beginPath();
    ctx.arc(0, 0, 24, baseAngle - 0.85, swingAngle);
    ctx.stroke();

    // Hoja de la espada
    ctx.rotate(swingAngle);
    ctx.fillStyle = '#d4af37'; // Guarda dorada
    ctx.fillRect(8, -4, 4, 8);
    ctx.fillStyle = glow ? '#54e0ff' : weapon?.color || '#e6f4ff'; // Hoja
    ctx.fillRect(12, -2, 18, 4);
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(13, -1, 15, 2);

    ctx.restore();
  }
}

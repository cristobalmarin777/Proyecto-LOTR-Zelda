/**
 * Enemy — Criaturas de las fuerzas de Sauron en la Tierra Media.
 * Tipos implementados en Etapa 1:
 *  - 'orc' (Explorador Orco de Mordor): Patrulla y persigue cuerpo a cuerpo con cimitarra.
 *  - 'spider' (Araña Gigante del Bosque Viejo): Rápida, embiste a intervalos y ralentiza con telaraña.
 *  - 'uruk' (Capitán Uruk-hai de la Mano Blanca): Mini-jefe resistente, agresivo y de mayor alcance.
 */
import { sfx } from '../systems/SoundFX.js';

let NEXT_ENEMY_ID = 1;

export class Enemy {
  constructor(type, x, y, isMiniBoss = false, threat = 0) {
    this.id = NEXT_ENEMY_ID++;
    this.type = type;
    this.x = x;
    this.y = y;
    this.spawnX = x;
    this.spawnY = y;
    this.isMiniBoss = isMiniBoss;
    this.threat = threat;

    this.dead = false;
    this.hurtFlashTimer = 0;
    this.knockbackVx = 0;
    this.knockbackVy = 0;
    this.knockbackTimer = 0;
    this.animTimer = Math.random() * 2;
    this.patrolAngle = Math.random() * Math.PI * 2;
    this.patrolChangeTimer = 1.5 + Math.random() * 1.5;
    this.lungeTimer = 0;
    this.shootCooldown = 0.7 + Math.random();
    this.fleeTimer = 0;
    this.justStoleCoins = 0;

    if (type === 'orc') {
      this.name = 'Orco Explorador';
      this.maxHp = 3;
      this.hp = 3;
      this.speed = 76;
      this.detectRadius = 175;
      this.damage = 1;
      this.xpReward = 20;
      this.halfW = 10;
      this.halfH = 11;
    } else if (type === 'spider') {
      this.name = 'Araña del Bosque Viejo';
      this.maxHp = 2;
      this.hp = 2;
      this.speed = 112;
      this.detectRadius = 195;
      this.damage = 1;
      this.xpReward = 18;
      this.halfW = 11;
      this.halfH = 10;
    } else if (type === 'uruk') {
      this.name = 'Capitán Uruk-hai (Lurtz-kin)';
      this.maxHp = 9;
      this.hp = 9;
      this.speed = 92;
      this.detectRadius = 230;
      this.damage = 2;
      this.xpReward = 80;
      this.halfW = 13;
      this.halfH = 13;
    } else if (type === 'goblin') {
      this.name = 'Duende Saqueador';
      this.maxHp = 1;
      this.hp = 1;
      this.speed = 122;
      this.detectRadius = 165;
      this.damage = 1;
      this.xpReward = 8;
      this.halfW = 8;
      this.halfH = 8;
    } else if (type === 'archer_orc') {
      this.name = 'Orco Arquero';
      this.maxHp = 2;
      this.hp = 2;
      this.speed = 58;
      this.detectRadius = 245;
      this.damage = 1;
      this.xpReward = 28;
      this.halfW = 10;
      this.halfH = 11;
    }

    // La amenaza aumenta lejos de La Comarca y da sentido a mejorar equipo.
    if (this.threat > 0) {
      this.maxHp += this.threat * (type === 'uruk' ? 3 : 2);
      this.hp = this.maxHp;
      this.damage += Math.floor((this.threat + 1) / 2);
      this.xpReward += this.threat * 12;
      this.name = `${this.name} · Amenaza ${this.threat}`;
      this.isElite = this.threat >= 3;
    }
  }

  update(dt, player, map, worldCallbacks = {}) {
    if (this.dead) return;

    this.animTimer += dt;
    if (this.hurtFlashTimer > 0) {
      this.hurtFlashTimer = Math.max(0, this.hurtFlashTimer - dt);
    }

    // Retroceso al recibir un espadazo o flecha
    if (this.knockbackTimer > 0) {
      this.knockbackTimer = Math.max(0, this.knockbackTimer - dt);
      this.moveWithCollision(this.knockbackVx * dt, this.knockbackVy * dt, map);
      return;
    }

    if (this.type === 'goblin' && this.fleeTimer > 0) {
      this.fleeTimer = Math.max(0, this.fleeTimer - dt);
      const angle = Math.atan2(this.y - player.y, this.x - player.x);
      this.moveWithCollision(Math.cos(angle) * 250 * dt, Math.sin(angle) * 250 * dt, map);
      if (this.fleeTimer <= 0) this.dead = true;
      return;
    }

    const dx = player.x - this.x;
    const dy = player.y - this.y;
    const dist = Math.hypot(dx, dy);

    let vx = 0;
    let vy = 0;

    if (this.type === 'archer_orc' && dist <= this.detectRadius) {
      this.shootCooldown = Math.max(0, this.shootCooldown - dt);
      if (dist < 125) {
        vx = -Math.cos(Math.atan2(dy, dx)) * this.speed;
        vy = -Math.sin(Math.atan2(dy, dx)) * this.speed;
      }
      this.moveWithCollision(vx * dt, vy * dt, map);
      if (this.shootCooldown <= 0) {
        this.shootCooldown = 1.65;
        worldCallbacks.spawnEnemyArrow?.(this.x, this.y, player.x, player.y, this.damage);
      }
      return;
    }

    if (dist <= this.detectRadius) {
      // Estado: Persecución activa del jugador
      const angle = Math.atan2(dy, dx);
      let currentSpeed = this.speed;

      // Las arañas realizan pequeñas embestidas rápidas
      if (this.type === 'spider') {
        this.lungeTimer += dt;
        if (this.lungeTimer % 1.6 < 0.35) {
          currentSpeed *= 1.45;
        }
      } else if (this.type === 'uruk' && this.hp <= this.maxHp / 2) {
        // El Capitán Uruk-hai entra en furia cuando baja de la mitad de vida
        currentSpeed *= 1.25;
      }

      vx = Math.cos(angle) * currentSpeed;
      vy = Math.sin(angle) * currentSpeed;
    } else {
      // Estado: Patrulla alrededor de su punto de origen
      this.patrolChangeTimer -= dt;
      if (this.patrolChangeTimer <= 0) {
        this.patrolChangeTimer = 1.8 + Math.random() * 2.0;
        const distFromSpawn = Math.hypot(this.x - this.spawnX, this.y - this.spawnY);
        if (distFromSpawn > 90) {
          this.patrolAngle = Math.atan2(this.spawnY - this.y, this.spawnX - this.x);
        } else {
          this.patrolAngle = Math.random() * Math.PI * 2;
        }
      }
      vx = Math.cos(this.patrolAngle) * (this.speed * 0.45);
      vy = Math.sin(this.patrolAngle) * (this.speed * 0.45);
    }

    this.moveWithCollision(vx * dt, vy * dt, map);

    // Comprobar colisión de contacto con el jugador para infligir daño
    if (dist < this.halfW + player.halfW + 3) {
      const isSpider = this.type === 'spider';
      const landed = player.takeDamage(this.damage, this.x, this.y, isSpider);
      if (landed && this.type === 'goblin' && !this.fleeTimer) {
        this.justStoleCoins = Math.min(player.coins, 3 + Math.floor(Math.random() * 5));
        player.coins -= this.justStoleCoins;
        this.fleeTimer = 1.8;
      }
    }
  }

  moveWithCollision(stepX, stepY, map) {
    if (stepX !== 0) {
      const nextX = this.x + stepX;
      if (!map.isRectBlocked(nextX, this.y, this.halfW, this.halfH)) {
        this.x = nextX;
      } else {
        this.patrolAngle += Math.PI;
      }
    }
    if (stepY !== 0) {
      const nextY = this.y + stepY;
      if (!map.isRectBlocked(this.x, nextY, this.halfW, this.halfH)) {
        this.y = nextY;
      } else {
        this.patrolAngle += Math.PI;
      }
    }
  }

  takeHit(damage, fromX, fromY) {
    if (this.dead) return false;
    this.hp -= damage;
    this.hurtFlashTimer = 0.16;

    const angle = Math.atan2(this.y - fromY, this.x - fromX);
    const kbForce = this.type === 'uruk' ? 140 : 220;
    this.knockbackVx = Math.cos(angle) * kbForce;
    this.knockbackVy = Math.sin(angle) * kbForce;
    this.knockbackTimer = 0.14;

    if (this.hp <= 0) {
      this.dead = true;
      sfx.enemyDeath();
      return true;
    } else {
      sfx.enemyHit();
      return false;
    }
  }

  draw(ctx, camX, camY) {
    if (this.dead) return;
    const sx = Math.round(this.x - camX);
    const sy = Math.round(this.y - camY);
    const stepBob = Math.sin(this.animTimer * 10) > 0 ? -1 : 1;

    ctx.save();
    if (this.hurtFlashTimer > 0) {
      ctx.filter = 'brightness(2.4) contrast(1.5)';
    }

    if (this.type === 'orc') {
      this.drawOrc(ctx, sx, sy, stepBob);
    } else if (this.type === 'spider') {
      this.drawSpider(ctx, sx, sy, stepBob);
    } else if (this.type === 'uruk') {
      this.drawUruk(ctx, sx, sy, stepBob);
    } else if (this.type === 'goblin') {
      this.drawGoblin(ctx, sx, sy, stepBob);
    } else if (this.type === 'archer_orc') {
      this.drawArcherOrc(ctx, sx, sy, stepBob);
    }
    ctx.restore();

    // Barra de vida sobre la cabeza del enemigo
    const barW = this.type === 'uruk' ? 38 : 24;
    const barH = 4;
    const bx = sx - Math.floor(barW / 2);
    const by = sy - (this.type === 'uruk' ? 24 : 19);

    ctx.fillStyle = '#1a0d0d';
    ctx.fillRect(bx - 1, by - 1, barW + 2, barH + 2);
    const ratio = Math.max(0, this.hp / this.maxHp);
    ctx.fillStyle = this.isElite ? '#b76cff' : this.type === 'uruk' ? '#ff9f1c' : '#e63946';
    ctx.fillRect(bx, by, Math.round(barW * ratio), barH);
  }

  drawOrc(ctx, sx, sy, bob) {
    // Sombra
    ctx.fillStyle = 'rgba(0,0,0,0.35)';
    ctx.fillRect(sx - 9, sy + 9, 18, 4);
    // Armadura de cuero oscuro de Mordor
    ctx.fillStyle = '#3b2d26';
    ctx.fillRect(sx - 7, sy - 3 + bob, 14, 12);
    // Piel verdosa grisácea
    ctx.fillStyle = '#5f7a4b';
    ctx.fillRect(sx - 6, sy - 12 + bob, 12, 9);
    // Casco de hierro oxidado
    ctx.fillStyle = '#4a4e52';
    ctx.fillRect(sx - 7, sy - 14 + bob, 14, 4);
    // Ojos rojos malignos
    ctx.fillStyle = '#ff2a2a';
    ctx.fillRect(sx - 4, sy - 8 + bob, 2, 2);
    ctx.fillRect(sx + 2, sy - 8 + bob, 2, 2);
    // Cimitarra dentada
    ctx.fillStyle = '#9aa0a6';
    ctx.fillRect(sx + 7, sy - 6 + bob, 4, 11);
  }

  drawSpider(ctx, sx, sy, bob) {
    // Sombra
    ctx.fillStyle = 'rgba(0,0,0,0.35)';
    ctx.fillRect(sx - 11, sy + 6, 22, 5);
    // Patas articuladas (8 patas animadas)
    ctx.fillStyle = '#1c1624';
    for (let i = -1; i <= 1; i += 2) {
      ctx.fillRect(sx - 13, sy + i * 4 + bob, 26, 2);
      ctx.fillRect(sx - 11, sy + i * 2 - bob, 22, 2);
    }
    // Abdomen bulboso oscuro con marcas púrpuras/rojas de Ella-Laraña
    ctx.fillStyle = '#251c30';
    ctx.fillRect(sx - 8, sy - 7 + bob, 16, 13);
    ctx.fillStyle = '#9e2a2b';
    ctx.fillRect(sx - 3, sy - 4 + bob, 6, 4);
    // Múltiples ojos rojos brillantes
    ctx.fillStyle = '#ff3b3b';
    ctx.fillRect(sx - 5, sy + 2 + bob, 2, 2);
    ctx.fillRect(sx - 2, sy + 3 + bob, 2, 2);
    ctx.fillRect(sx + 1, sy + 3 + bob, 2, 2);
    ctx.fillRect(sx + 4, sy + 2 + bob, 2, 2);
  }

  drawUruk(ctx, sx, sy, bob) {
    // Sombra grande
    ctx.fillStyle = 'rgba(0,0,0,0.45)';
    ctx.fillRect(sx - 12, sy + 11, 24, 6);
    // Armadura pesada de placa negra
    ctx.fillStyle = '#2b2d30';
    ctx.fillRect(sx - 10, sy - 5 + bob, 20, 16);
    ctx.fillStyle = '#5c1d1d';
    ctx.fillRect(sx - 8, sy + 3 + bob, 16, 4);
    // Cabeza Uruk-hai (piel rojiza oscura + Mano Blanca pintada en el yelmo)
    ctx.fillStyle = '#6e352c';
    ctx.fillRect(sx - 7, sy - 15 + bob, 14, 10);
    ctx.fillStyle = '#3c4045';
    ctx.fillRect(sx - 8, sy - 17 + bob, 16, 5);
    // Marca de la Mano Blanca
    ctx.fillStyle = '#f2f2f2';
    ctx.fillRect(sx - 2, sy - 16 + bob, 4, 3);
    // Ojos amarillos feroces
    ctx.fillStyle = '#ffcc00';
    ctx.fillRect(sx - 4, sy - 11 + bob, 3, 2);
    ctx.fillRect(sx + 2, sy - 11 + bob, 3, 2);
    // Espadón Uruk
    ctx.fillStyle = '#b0b7c0';
    ctx.fillRect(sx + 10, sy - 12 + bob, 5, 18);
  }

  drawGoblin(ctx, sx, sy, bob) {
    ctx.fillStyle = 'rgba(0,0,0,0.3)';
    ctx.fillRect(sx - 7, sy + 7, 14, 3);
    ctx.fillStyle = '#553d22';
    ctx.fillRect(sx - 6, sy - 2 + bob, 12, 10);
    ctx.fillStyle = '#77934d';
    ctx.fillRect(sx - 5, sy - 10 + bob, 10, 8);
    ctx.fillStyle = '#ffcf33';
    ctx.fillRect(sx - 3, sy - 7 + bob, 2, 2);
    ctx.fillRect(sx + 2, sy - 7 + bob, 2, 2);
    ctx.fillStyle = '#d9a05b';
    ctx.fillRect(sx + 6, sy + bob, 4, 6);
  }

  drawArcherOrc(ctx, sx, sy, bob) {
    this.drawOrc(ctx, sx, sy, bob);
    ctx.fillStyle = '#b07a43';
    ctx.fillRect(sx - 12, sy - 10 + bob, 2, 18);
    ctx.fillRect(sx - 10, sy - 11 + bob, 2, 3);
    ctx.fillRect(sx - 10, sy + 7 + bob, 2, 3);
  }
}

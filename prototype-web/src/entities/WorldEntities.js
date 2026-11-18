/**
 * WorldEntities — Proyectiles (Flechas), Objetos recolectables (Corazones, Monedas, Flechas),
 * Partículas Pixel Art y Textos Flotantes de Daño / Recompensas.
 */
import { SOLID_TILES } from '../assets/SpriteAtlas.js';

export class ArrowProjectile {
  constructor(x, y, dir) {
    this.x = x;
    this.y = y;
    this.dir = dir;
    this.speed = 340;
    this.damage = 1;
    this.dead = false;
    this.life = 1.2;
  }

  update(dt, map, enemies, onEnemyKilled) {
    this.life -= dt;
    if (this.life <= 0) {
      this.dead = true;
      return;
    }

    if (this.dir === 'up') this.y -= this.speed * dt;
    else if (this.dir === 'down') this.y += this.speed * dt;
    else if (this.dir === 'left') this.x -= this.speed * dt;
    else if (this.dir === 'right') this.x += this.speed * dt;

    const tile = map.getTileAtPixel(this.x, this.y);
    if (SOLID_TILES.has(tile)) {
      this.dead = true;
      return;
    }

    for (const enemy of enemies) {
      if (enemy.dead) continue;
      if (
        Math.abs(this.x - enemy.x) < enemy.halfW + 6 &&
        Math.abs(this.y - enemy.y) < enemy.halfH + 6
      ) {
        const killed = enemy.takeHit(this.damage, this.x, this.y);
        this.dead = true;
        if (killed && onEnemyKilled) {
          onEnemyKilled(enemy);
        }
        return;
      }
    }
  }

  draw(ctx, camX, camY) {
    const sx = Math.round(this.x - camX);
    const sy = Math.round(this.y - camY);
    ctx.fillStyle = '#d9a05b';
    if (this.dir === 'left' || this.dir === 'right') {
      ctx.fillRect(sx - 8, sy - 1, 16, 3);
      ctx.fillStyle = '#e0e6ed';
      ctx.fillRect(this.dir === 'right' ? sx + 6 : sx - 9, sy - 2, 4, 5);
    } else {
      ctx.fillRect(sx - 1, sy - 8, 3, 16);
      ctx.fillStyle = '#e0e6ed';
      ctx.fillRect(sx - 2, this.dir === 'down' ? sy + 6 : sy - 9, 5, 4);
    }
  }
}

/** Flecha hostil disparada por los arqueros orcos. */
export class EnemyArrowProjectile {
  constructor(x, y, targetX, targetY, damage = 1) {
    this.x = x;
    this.y = y;
    const distance = Math.hypot(targetX - x, targetY - y) || 1;
    this.vx = ((targetX - x) / distance) * 245;
    this.vy = ((targetY - y) / distance) * 245;
    this.damage = damage;
    this.life = 1.8;
    this.dead = false;
  }

  update(dt, map, player) {
    this.life -= dt;
    if (this.life <= 0) {
      this.dead = true;
      return;
    }
    this.x += this.vx * dt;
    this.y += this.vy * dt;
    if (SOLID_TILES.has(map.getTileAtPixel(this.x, this.y))) {
      this.dead = true;
      return;
    }
    if (Math.abs(this.x - player.x) < player.halfW + 4 && Math.abs(this.y - player.y) < player.halfH + 4) {
      player.takeDamage(this.damage, this.x, this.y);
      this.dead = true;
    }
  }

  draw(ctx, camX, camY) {
    const sx = Math.round(this.x - camX);
    const sy = Math.round(this.y - camY);
    ctx.save();
    ctx.translate(sx, sy);
    ctx.rotate(Math.atan2(this.vy, this.vx));
    ctx.fillStyle = '#71441f';
    ctx.fillRect(-7, -1, 14, 3);
    ctx.fillStyle = '#c6d0d8';
    ctx.fillRect(5, -2, 4, 5);
    ctx.restore();
  }
}

export class LootDrop {
  constructor(x, y, kind) {
    this.x = x;
    this.y = y;
    this.kind = kind; // 'heart' | 'coin' | 'arrows' | 'arnor_map'
    this.bobTimer = Math.random() * Math.PI * 2;
    this.collected = false;
  }

  update(dt) {
    this.bobTimer += dt * 5;
  }

  draw(ctx, camX, camY) {
    const sx = Math.round(this.x - camX);
    const sy = Math.round(this.y - camY + Math.sin(this.bobTimer) * 2.5);

    ctx.fillStyle = 'rgba(0,0,0,0.3)';
    ctx.fillRect(sx - 6, Math.round(this.y - camY) + 6, 12, 3);

    if (this.kind === 'heart') {
      ctx.fillStyle = '#ff334b';
      ctx.fillRect(sx - 5, sy - 4, 4, 4);
      ctx.fillRect(sx + 1, sy - 4, 4, 4);
      ctx.fillRect(sx - 6, sy - 2, 12, 4);
      ctx.fillRect(sx - 4, sy + 2, 8, 3);
      ctx.fillRect(sx - 2, sy + 5, 4, 2);
    } else if (this.kind === 'coin') {
      ctx.fillStyle = '#ffd700';
      ctx.fillRect(sx - 4, sy - 6, 8, 12);
      ctx.fillStyle = '#fff394';
      ctx.fillRect(sx - 2, sy - 4, 2, 8);
    } else if (this.kind === 'arrows') {
      ctx.fillStyle = '#c98a4b';
      ctx.fillRect(sx - 5, sy - 6, 10, 12);
      ctx.fillStyle = '#58b347';
      ctx.fillRect(sx - 3, sy - 8, 6, 3);
    } else if (this.kind === 'arnor_map') {
      ctx.fillStyle = '#f4e2b8';
      ctx.fillRect(sx - 7, sy - 6, 14, 12);
      ctx.fillStyle = '#b8332a';
      ctx.fillRect(sx - 2, sy - 2, 4, 4);
    }
  }
}

export class FloatingText {
  constructor(x, y, text, color = '#ffffff') {
    this.x = x;
    this.y = y;
    this.text = text;
    this.color = color;
    this.life = 0.95;
  }

  update(dt) {
    this.y -= 24 * dt;
    this.life -= dt;
  }

  draw(ctx, camX, camY) {
    const sx = Math.round(this.x - camX);
    const sy = Math.round(this.y - camY);
    ctx.save();
    ctx.font = 'bold 12px "Courier New", monospace';
    ctx.textAlign = 'center';
    ctx.fillStyle = '#000000';
    ctx.fillText(this.text, sx + 1, sy + 1);
    ctx.fillStyle = this.color;
    ctx.fillText(this.text, sx, sy);
    ctx.restore();
  }
}

/** Guardián élfico amistoso: protege claros del Bosque Viejo. */
export class ElfGuardian {
  constructor(spawn) {
    this.x = (spawn.col + 0.5) * 32;
    this.y = (spawn.row + 0.5) * 32;
    this.spawnKey = spawn.key;
    this.role = spawn.role;
    this.halfW = 9;
    this.halfH = 10;
    this.attackTimer = Math.random();
    this.name = spawn.role === 'scout' ? 'Explorador Élfico' : spawn.role === 'lembas' ? 'Elfa Guardiana del Lembas' : 'Elfo de los Senderos';
  }

  update(dt, enemies, map, onEnemyDefeated) {
    this.attackTimer = Math.max(0, this.attackTimer - dt);
    const target = enemies.find((enemy) => !enemy.dead && !enemy.isMiniBoss && Math.hypot(enemy.x - this.x, enemy.y - this.y) < 175);
    if (!target) return;
    const dx = target.x - this.x;
    const dy = target.y - this.y;
    const dist = Math.hypot(dx, dy) || 1;
    if (dist > 54) {
      const stepX = (dx / dist) * 64 * dt;
      const stepY = (dy / dist) * 64 * dt;
      if (!map.isRectBlocked(this.x + stepX, this.y, this.halfW, this.halfH)) this.x += stepX;
      if (!map.isRectBlocked(this.x, this.y + stepY, this.halfW, this.halfH)) this.y += stepY;
    } else if (this.attackTimer <= 0) {
      this.attackTimer = 0.85;
      if (target.takeHit(2, this.x, this.y) && onEnemyDefeated) onEnemyDefeated(target);
    }
  }

  draw(ctx, camX, camY) {
    const sx = Math.round(this.x - camX);
    const sy = Math.round(this.y - camY);
    ctx.fillStyle = 'rgba(0,0,0,0.35)';
    ctx.fillRect(sx - 8, sy + 9, 16, 4);
    ctx.fillStyle = '#3c9461';
    ctx.fillRect(sx - 7, sy - 4, 14, 14);
    ctx.fillStyle = '#d7f3e1';
    ctx.fillRect(sx - 5, sy - 13, 10, 9);
    ctx.fillStyle = '#f2d8a8';
    ctx.fillRect(sx - 4, sy - 11, 8, 7);
    ctx.fillStyle = '#8ce9ff';
    ctx.fillRect(sx + 7, sy - 7, 10, 2);
    ctx.fillStyle = '#bfffea';
    ctx.fillRect(sx - 1, sy - 21, 2, 3);
  }
}

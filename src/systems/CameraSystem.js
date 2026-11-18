/**
 * CameraSystem — Cámara suave Top-Down que sigue al protagonista dentro de los límites del mapa.
 */
export class CameraSystem {
  constructor(viewWidth, viewHeight, worldWidth, worldHeight) {
    this.viewWidth = viewWidth;
    this.viewHeight = viewHeight;
    this.worldWidth = worldWidth;
    this.worldHeight = worldHeight;
    this.x = 0;
    this.y = 0;
    this.shakeTimer = 0;
    this.shakeIntensity = 0;
  }

  setWorldBounds(worldWidth, worldHeight) {
    this.worldWidth = worldWidth;
    this.worldHeight = worldHeight;
  }

  shake(duration = 0.16, intensity = 5) {
    this.shakeTimer = duration;
    this.shakeIntensity = intensity;
  }

  follow(target, dt, instant = false) {
    const targetX = target.x - this.viewWidth / 2;
    const targetY = target.y - this.viewHeight / 2;

    const clampedX = Number.isFinite(this.worldWidth)
      ? Math.max(0, Math.min(this.worldWidth - this.viewWidth, targetX))
      : targetX;
    const clampedY = Number.isFinite(this.worldHeight)
      ? Math.max(0, Math.min(this.worldHeight - this.viewHeight, targetY))
      : targetY;

    if (instant) {
      this.x = clampedX;
      this.y = clampedY;
    } else {
      const lerp = Math.min(1, dt * 9);
      this.x += (clampedX - this.x) * lerp;
      this.y += (clampedY - this.y) * lerp;
    }

    if (this.shakeTimer > 0) {
      this.shakeTimer = Math.max(0, this.shakeTimer - dt);
    }
  }

  getRenderOffset() {
    let ox = Math.round(this.x);
    let oy = Math.round(this.y);
    if (this.shakeTimer > 0) {
      ox += Math.round((Math.random() - 0.5) * 2 * this.shakeIntensity);
      oy += Math.round((Math.random() - 0.5) * 2 * this.shakeIntensity);
    }
    return { x: ox, y: oy };
  }
}

/**
 * SoundFX — Sintetizador de audio retro 16-bit mediante Web Audio API.
 * No requiere archivos externos y aporta feedback inmediato para golpes, daño, cofres y misiones.
 */
export class SoundFX {
  constructor() {
    this.ctx = null;
    this.enabled = true;
  }

  init() {
    if (!this.ctx) {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (AudioCtx) {
        this.ctx = new AudioCtx();
      }
    }
    if (this.ctx && this.ctx.state === 'suspended') {
      this.ctx.resume();
    }
  }

  playTone(freq, type = 'square', duration = 0.1, slideTo = null, gainVal = 0.08) {
    if (!this.enabled) return;
    this.init();
    if (!this.ctx) return;

    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = type;
    osc.frequency.setValueAtTime(freq, now);
    if (slideTo) {
      osc.frequency.exponentialRampToValueAtTime(slideTo, now + duration);
    }

    gain.gain.setValueAtTime(gainVal, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + duration);

    osc.connect(gain);
    gain.connect(this.ctx.destination);

    osc.start(now);
    osc.stop(now + duration);
  }

  swordSwing() {
    this.playTone(460, 'triangle', 0.11, 140, 0.1);
  }

  arrowShoot() {
    this.playTone(680, 'sawtooth', 0.09, 280, 0.07);
  }

  enemyHit() {
    this.playTone(210, 'square', 0.09, 95, 0.11);
  }

  enemyDeath() {
    this.playTone(180, 'sawtooth', 0.18, 55, 0.12);
  }

  playerHurt() {
    this.playTone(150, 'sawtooth', 0.22, 65, 0.14);
  }

  pickupCoin() {
    this.playTone(987, 'square', 0.06, null, 0.07);
    setTimeout(() => this.playTone(1318, 'square', 0.12, null, 0.07), 55);
  }

  pickupHeart() {
    this.playTone(523, 'triangle', 0.08, 784, 0.1);
  }

  chestOpen() {
    const notes = [523, 659, 784, 1046];
    notes.forEach((n, idx) => {
      setTimeout(() => this.playTone(n, 'square', 0.12, null, 0.08), idx * 80);
    });
  }

  dialogStep() {
    this.playTone(620, 'square', 0.03, null, 0.04);
  }
}

export const sfx = new SoundFX();

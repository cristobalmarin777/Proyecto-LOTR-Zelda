/**
 * InputSystem — Gestiona el teclado y el ratón para el control Top-Down tipo Zelda ALTTP.
 */
export class InputSystem {
  constructor(canvas) {
    this.keys = new Set();
    this.justPressed = new Set();
    this.mouseClicked = false;

    window.addEventListener('keydown', (e) => {
      const code = e.code;
      if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(code)) {
        e.preventDefault();
      }
      if (!this.keys.has(code)) {
        this.justPressed.add(code);
      }
      this.keys.add(code);
    });

    window.addEventListener('keyup', (e) => {
      this.keys.delete(e.code);
    });

    window.addEventListener('blur', () => {
      this.keys.clear();
      this.justPressed.clear();
    });

    if (canvas) {
      canvas.addEventListener('mousedown', (e) => {
        if (e.button === 0) {
          this.mouseClicked = true;
        }
      });
    }
  }

  isDown(code) {
    return this.keys.has(code);
  }

  wasPressed(code) {
    return this.justPressed.has(code);
  }

  consumeClick() {
    const clicked = this.mouseClicked;
    this.mouseClicked = false;
    return clicked;
  }

  getMovementVector() {
    let dx = 0;
    let dy = 0;
    if (this.isDown('KeyW') || this.isDown('ArrowUp')) dy -= 1;
    if (this.isDown('KeyS') || this.isDown('ArrowDown')) dy += 1;
    if (this.isDown('KeyA') || this.isDown('ArrowLeft')) dx -= 1;
    if (this.isDown('KeyD') || this.isDown('ArrowRight')) dx += 1;

    if (dx !== 0 && dy !== 0) {
      const inv = 1 / Math.SQRT2;
      dx *= inv;
      dy *= inv;
    }
    return { dx, dy };
  }

  endFrame() {
    this.justPressed.clear();
    this.mouseClicked = false;
  }
}

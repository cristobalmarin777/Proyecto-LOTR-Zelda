/**
 * EnvironmentAssets — Elementos ambientales con soporte para profundidad dinámica (Y-Sorting):
 *  - Árboles frondosos de La Comarca (Robles verdes y Árboles otoñales rojizos como en la Referencia B).
 *  - Arbustos floridos y Jardines de Calabazas / Flores (Referencia A y B).
 *  - Cercos rústicos de madera y Farolas de camino.
 */

function createCanvas(w, h) {
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext('2d');
  ctx.imageSmoothingEnabled = false;
  return { canvas, ctx };
}

function rect(ctx, x, y, w, h, color) {
  ctx.fillStyle = color;
  ctx.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h));
}

export class EnvironmentAssets {
  constructor() {
    this.props = {};
    this.buildProps();
  }

  buildProps() {
    this.props.shire_oak = this.createTreeProp({
      leaves: ['#1d451a', '#2e6627', '#498c3d', '#6eb55b'],
    });

    // Árbol otoñal rojizo/dorado que aparece a la izquierda en la Referencia B
    this.props.autumn_tree = this.createTreeProp({
      leaves: ['#521d24', '#852b2b', '#ba472b', '#e68a2e'],
    });

    this.props.flower_bush = this.createFlowerBushProp();
    this.props.wooden_post_lantern = this.createLanternPostProp();
  }

  createTreeProp(palette) {
    const width = 64;
    const height = 76;
    const { canvas, ctx } = createCanvas(width, height);
    const cx = 32;

    // Sombra ovalada en la base
    ctx.fillStyle = 'rgba(10, 20, 8, 0.35)';
    ctx.beginPath();
    ctx.ellipse(cx, 66, 22, 7, 0, 0, Math.PI * 2);
    ctx.fill();

    // Tronco y raíces
    rect(ctx, cx - 9, 60, 18, 6, '#4a2d15');
    rect(ctx, cx - 6, 40, 12, 24, '#5c391c');
    rect(ctx, cx - 3, 40, 5, 22, '#7a4d28');

    // Copa 16-bit en 4 niveles
    const radii = [
      [27, 21, 34, palette.leaves[0]],
      [24, 18, 30, palette.leaves[1]],
      [19, 14, 26, palette.leaves[2]],
      [12, 9, 22, palette.leaves[3]],
    ];
    for (const [rx, ry, cy, col] of radii) {
      ctx.fillStyle = col;
      ctx.beginPath();
      ctx.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2);
      ctx.fill();
    }

    return {
      sprite: canvas,
      width,
      height,
      collider: { x: 23, y: 52, w: 18, h: 14 },
      sortYOffset: 64,
    };
  }

  createFlowerBushProp() {
    const width = 40;
    const height = 32;
    const { canvas, ctx } = createCanvas(width, height);

    rect(ctx, 6, 22, 28, 6, 'rgba(10, 20, 8, 0.3)');
    ctx.fillStyle = '#285420';
    ctx.beginPath();
    ctx.ellipse(20, 18, 16, 10, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#3f7833';
    ctx.beginPath();
    ctx.ellipse(20, 16, 13, 8, 0, 0, Math.PI * 2);
    ctx.fill();

    const flowers = [
      [12, 13, '#ff6b9d'],
      [20, 11, '#ffe047'],
      [26, 15, '#ffffff'],
      [16, 18, '#ff6b9d'],
    ];
    for (const [fx, fy, col] of flowers) {
      rect(ctx, fx, fy, 3, 3, col);
    }

    return {
      sprite: canvas,
      width,
      height,
      collider: { x: 8, y: 16, w: 24, h: 10 },
      sortYOffset: 24,
    };
  }

  createLanternPostProp() {
    const width = 24;
    const height = 44;
    const { canvas, ctx } = createCanvas(width, height);
    rect(ctx, 7, 36, 10, 4, 'rgba(0,0,0,0.3)');
    rect(ctx, 10, 10, 4, 28, '#593718');
    rect(ctx, 10, 10, 8, 3, '#593718');
    rect(ctx, 15, 13, 5, 7, '#291d12');
    rect(ctx, 16, 14, 3, 5, '#ffea79');

    return {
      sprite: canvas,
      width,
      height,
      collider: { x: 9, y: 30, w: 6, h: 8 },
      sortYOffset: 36,
    };
  }
}

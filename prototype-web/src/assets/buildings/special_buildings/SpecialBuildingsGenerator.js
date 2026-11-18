/**
 * SpecialBuildingsGenerator — Edificios Emblemáticos de Hobbiton:
 *  1. Bolsón Cerrado (Bag End): Gran Smial señorial de Bilbo y Frodo en la cima de La Colina,
 *     con el Gran Roble sobre la colina, puerta verde esmeralda con pomo central de latón,
 *     múltiples ventanas circulares, banco exterior y escaleras de piedra.
 *  2. Posada El Dragón Verde (The Green Dragon Inn): Gran edificio tradicional de entramado
 *     de madera y piedra con tejado de paja en L, chimeneas humeantes, letrero colgante del
 *     Dragón Verde y barriles de cerveza de la Cuaderna del Sur.
 *  3. El Viejo Molino de Arenas (Sandyman's Mill): Construcción rústica de piedra rojiza/gris
 *     y entramado de madera junto al río El Agua, con su gran rueda hidráulica de paletas.
 *  4. El Árbol de la Fiesta (The Party Tree) y Pabellón de Cumpleaños en el Campo de la Fiesta.
 */
import {
  drawTurfMound,
  drawRoundHobbitDoor,
  drawRoundWindow,
  drawStoneStepsAndGarden,
} from '../hobbit_houses/HobbitHouseGenerator.js';
import {
  drawStoneChimney,
  drawSquareTimberWindow,
  drawRuralWoodDoor,
  drawHorizontalThatchWing,
  drawFrontGableThatch,
} from '../rural_houses/RuralHouseGenerator.js';

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

/**
 * 1. BOLSÓN CERRADO (Bag End) — Mansión subterránea de Bilbo y Frodo Bolsón
 */
export function buildBagEndSprite() {
  const width = 224;
  const height = 160;
  const { canvas, ctx } = createCanvas(width, height);
  const cx = Math.floor(width / 2);

  // Colina señorial amplia
  drawTurfMound(ctx, cx, 96, 104, 56);

  // El Gran Roble de Bolsón Cerrado coronando la cima de la colina
  const treeX = cx + 10;
  const treeY = 38;
  // Raíces retorcidas abrazando la colina (Referencia A)
  rect(ctx, treeX - 18, treeY + 12, 36, 6, '#4a2d15');
  rect(ctx, treeX - 24, treeY + 16, 14, 4, '#3b2310');
  rect(ctx, treeX + 12, treeY + 16, 16, 4, '#3b2310');
  rect(ctx, treeX - 8, treeY - 12, 16, 28, '#5c391c');
  rect(ctx, treeX - 5, treeY - 12, 6, 26, '#784c27');

  // Copa majestuosa del roble en 4 niveles rectangulares pixelados (estética SpriteAtlas.createTreeTile)
  rect(ctx, treeX - 42, treeY - 34, 84, 38, '#1e4d1b');
  rect(ctx, treeX - 36, treeY - 38, 72, 34, '#2e6f28');
  rect(ctx, treeX - 28, treeY - 35, 56, 24, '#44913b');
  rect(ctx, treeX - 20, treeY - 32, 32, 13, '#62b356');

  // Dos chimeneas de ladrillo en Bolsón Cerrado
  rect(ctx, cx - 52, 42, 12, 18, '#6e3f23');
  rect(ctx, cx - 51, 43, 10, 16, '#9c5b34');
  rect(ctx, cx + 48, 48, 10, 15, '#6e3f23');

  // Gran fachada curva de Bolsón Cerrado (paneles de roble y estuco crema)
  const fx = cx - 82;
  const fy = 94;
  const fw = 164;
  const fh = 34;

  rect(ctx, fx - 3, fy - 4, fw + 6, 6, '#362010');
  rect(ctx, fx, fy, fw, fh, '#dfbe82');
  rect(ctx, fx + 2, fy + 2, fw - 4, fh - 4, '#f0d7a8');

  // Pilares de madera tallada
  const pillars = [-60, -24, 22, 58];
  for (const pxOffset of pillars) {
    rect(ctx, cx + pxOffset, fy - 2, 4, fh, '#b89054');
  }

  // 4 ventanas circulares (salón, estudio de Bilbo, comedor y despensa)
  drawRoundWindow(ctx, cx - 70, fy + 16, 7);
  drawRoundWindow(ctx, cx - 38, fy + 15, 9);
  drawRoundWindow(ctx, cx + 38, fy + 15, 9);
  drawRoundWindow(ctx, cx + 70, fy + 16, 7);

  // La icónica Puerta Verde Esmeralda de Bolsón Cerrado con su farolillo superior
  rect(ctx, cx - 2, fy - 6, 5, 6, '#26180d');
  rect(ctx, cx - 1, fy - 5, 3, 4, '#fff2a6');
  drawRoundHobbitDoor(ctx, cx, fy + 16, 15, '#195e2c', '#10401d', '#b86f39');

  // Banco de madera de Bilbo junto a la entrada (donde fuma en pipa con Gandalf)
  rect(ctx, cx - 48, fy + fh - 6, 18, 6, '#6e4520');
  rect(ctx, cx - 47, fy + fh - 4, 16, 3, '#8f5d2e');

  // Escalones de piedra gris y jardines floridos (Referencia A)
  drawStoneStepsAndGarden(ctx, cx, fy + fh - 2, 5, true);

  return canvas;
}

/**
 * 2. POSADA EL DRAGÓN VERDE (The Green Dragon Inn) — Junto al lago de Delagua
 */
export function buildGreenDragonInnSprite() {
  const width = 220;
  const height = 140;
  const { canvas, ctx } = createCanvas(width, height);

  // Sombra general
  rect(ctx, 14, 86, 192, 42, 'rgba(12, 22, 10, 0.35)');

  // Chimeneas gemelas de piedra (Referencia B)
  drawStoneChimney(ctx, 48, 8, 24, 22);
  drawStoneChimney(ctx, 148, 12, 22, 20);

  // Cuerpo largo principal de entramado de madera y piedra
  const bx = 22;
  const by = 64;
  const bw = 176;
  const bh = 44;
  rect(ctx, bx, by, bw, bh, '#ebe2d6');
  // Zócalo inferior de piedra
  rect(ctx, bx, by + bh - 10, bw, 10, '#7c756b');
  // Vigas de roble
  rect(ctx, bx, by, bw, 4, '#633b15');
  rect(ctx, bx, by + 20, bw, 4, '#75471b');
  for (let vx = bx; vx <= bx + bw - 4; vx += 28) {
    rect(ctx, vx, by, 4, bh, '#633b15');
  }

  // Ventanas iluminadas cálidamente de la taberna
  drawSquareTimberWindow(ctx, bx + 12, by + 5, 14, 14);
  drawSquareTimberWindow(ctx, bx + 98, by + 5, 14, 14);
  drawSquareTimberWindow(ctx, bx + 128, by + 5, 14, 14);
  drawSquareTimberWindow(ctx, bx + 154, by + 5, 14, 14);

  // Tejado largo de paja dorada (Referencia B)
  drawHorizontalThatchWing(ctx, 16, 26, 188, 42);

  // Cuerpo de entrada adelantado con hastial en A (izquierda-centro)
  const gx = 52;
  const gy = 56;
  const gw = 58;
  const gh = 56;
  rect(ctx, gx, gy, gw, gh, '#f0e7dc');
  rect(ctx, gx, gy, 4, gh, '#633b15');
  rect(ctx, gx + gw - 4, gy, 4, gh, '#633b15');
  rect(ctx, gx, gy + 22, gw, 4, '#7d4d1d');
  drawRuralWoodDoor(ctx, gx + 20, gy + 28, 20, 26);
  drawFrontGableThatch(ctx, gx + 29, 18, 34, 42);

  // Letrero colgante del "Dragón Verde" junto a la puerta
  rect(ctx, gx + gw + 2, gy + 24, 14, 3, '#4a2c10');
  rect(ctx, gx + gw + 4, gy + 27, 12, 11, '#1e4d26');
  rect(ctx, gx + gw + 6, gy + 29, 8, 7, '#58c468');

  // Barriles de cerveza y mesas exteriores de madera
  for (let i = 0; i < 3; i++) {
    const barrelX = 136 + i * 16;
    const barrelY = 100;
    rect(ctx, barrelX, barrelY, 11, 13, '#7d4e22');
    rect(ctx, barrelX + 1, barrelY + 3, 9, 2, '#3d4045');
    rect(ctx, barrelX + 1, barrelY + 9, 9, 2, '#3d4045');
  }

  return canvas;
}

/**
 * 3. EL VIEJO MOLINO DE ARENAS (Sandyman's Mill) — Con rueda hidráulica sobre El Agua
 */
export function buildOldMillSprite() {
  const width = 164;
  const height = 136;
  const { canvas, ctx } = createCanvas(width, height);

  rect(ctx, 16, 86, 132, 38, 'rgba(12, 20, 12, 0.35)');

  // Rueda hidráulica de madera en el lateral derecho (junto al cauce del río)
  const wx = 122;
  const wy = 62;
  rect(ctx, wx, wy, 26, 48, '#3d2511');
  rect(ctx, wx + 3, wy + 3, 20, 42, '#69411f');
  for (let py = wy + 4; py < wy + 46; py += 6) {
    rect(ctx, wx - 2, py, 30, 3, '#8f5b2d');
  }
  // Espuma de agua bajo la rueda
  rect(ctx, wx - 2, wy + 44, 30, 6, '#9ad1f5');
  rect(ctx, wx + 2, wy + 46, 22, 4, '#ffffff');

  // Torreón principal del Molino (mampostería de ladrillo/piedra y entramado superior)
  const mx = 26;
  const my = 46;
  const mw = 96;
  const mh = 68;
  rect(ctx, mx, my, mw, mh, '#9c6244');
  // Textura de ladrillo envejecido y piedra
  for (let y = my + 6; y < my + mh - 6; y += 8) {
    for (let x = mx + 6; x < mx + mw - 12; x += 14) {
      rect(ctx, x + ((y / 8) % 2) * 5, y, 10, 5, '#b57858');
    }
  }
  // Entramado de madera superior
  rect(ctx, mx, my, mw, 24, '#e6ddd1');
  rect(ctx, mx, my, 4, mh, '#593614');
  rect(ctx, mx + mw - 4, my, 4, mh, '#593614');
  rect(ctx, mx, my + 24, mw, 4, '#593614');

  drawSquareTimberWindow(ctx, mx + 14, my + 6, 14, 14);
  drawSquareTimberWindow(ctx, mx + mw - 28, my + 6, 14, 14);
  drawRuralWoodDoor(ctx, mx + 38, my + 40, 20, 26);

  // Sacos de harina apilados junto a la entrada
  rect(ctx, mx + 12, my + 56, 12, 10, '#d9ccb4');
  rect(ctx, mx + 22, my + 58, 11, 9, '#c7b89d');

  // Tejado inclinado de paja y madera del molino
  drawHorizontalThatchWing(ctx, 20, 16, 108, 34);
  drawFrontGableThatch(ctx, mx + 48, 10, 36, 38);

  return canvas;
}

/**
 * 4. EL ÁRBOL DE LA FIESTA (The Party Tree) — Gran árbol centenario con guirnaldas y farolillos
 */
export function buildPartyTreeSprite() {
  const width = 180;
  const height = 160;
  const { canvas, ctx } = createCanvas(width, height);
  const cx = Math.floor(width / 2);

  // Sombra amplia en la pradera de la fiesta
  ctx.fillStyle = 'rgba(12, 24, 10, 0.35)';
  ctx.beginPath();
  ctx.ellipse(cx, 134, 68, 20, 0, 0, Math.PI * 2);
  ctx.fill();

  // Raíces y tronco monumental
  rect(ctx, cx - 26, 122, 52, 10, '#4a2e16');
  rect(ctx, cx - 18, 78, 36, 48, '#5c3a1d');
  rect(ctx, cx - 10, 78, 14, 46, '#784e29');

  // Copa gigante en bloques rectangulares escalonados (estética SpriteAtlas.createTreeTile)
  rect(ctx, cx - 72, 22, 144, 64, '#1e4d1b');
  rect(ctx, cx - 64, 14, 128, 56, '#2e6f28');
  rect(ctx, cx - 52, 20, 104, 40, '#44913b');
  rect(ctx, cx - 36, 24, 62, 22, '#62b356');

  // Farolillos festivos y banderines colgados de las ramas bajas (Cumpleaños 111 de Bilbo)
  const lanterns = [
    [-48, 78, '#ffdf4d'],
    [-26, 84, '#ff758f'],
    [0, 86, '#ffdf4d'],
    [28, 84, '#72efdd'],
    [50, 78, '#ffdf4d'],
  ];
  for (const [lx, ly, col] of lanterns) {
    rect(ctx, cx + lx, ly - 4, 2, 4, '#2b1d10');
    rect(ctx, cx + lx - 2, ly, 6, 6, col);
    rect(ctx, cx + lx - 1, ly + 1, 4, 4, '#ffffff');
  }

  return canvas;
}

/**
 * 5. CARPA / PABELLÓN DE LA FIESTA (Party Marquee)
 */
export function buildPartyTentSprite() {
  const width = 112;
  const height = 88;
  const { canvas, ctx } = createCanvas(width, height);

  rect(ctx, 12, 58, 88, 22, 'rgba(12, 22, 10, 0.3)');
  // Postes de madera
  rect(ctx, 18, 42, 4, 34, '#6e451f');
  rect(ctx, 54, 38, 4, 38, '#6e451f');
  rect(ctx, 90, 42, 4, 34, '#6e451f');

  // Mesa de banquete con pasteles y jarras bajo la carpa
  rect(ctx, 26, 58, 60, 12, '#8c5828');
  rect(ctx, 28, 56, 56, 4, '#f5ebd6');
  rect(ctx, 36, 52, 8, 5, '#e85d75');
  rect(ctx, 54, 51, 10, 6, '#f0c441');
  rect(ctx, 72, 53, 6, 5, '#d9822b');

  // Toldo a franjas festivas (blanco crema y dorado/rojo)
  for (let x = 12; x < 100; x += 8) {
    const isStripe = Math.floor((x - 12) / 8) % 2 === 0;
    rect(ctx, x, 18, 8, 26, isStripe ? '#f5ecd8' : '#d94e34');
    rect(ctx, x, 44, 6, 4, isStripe ? '#decbb0' : '#ad3620');
  }

  return canvas;
}

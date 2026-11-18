/**
 * HobbitHouseGenerator — Generador Pixel Art 16-bit de Smials (Casas Hobbit tradicionales)
 * basado en la Referencia A (colinas cubiertas de vegetación con dither orgánico,
 * puertas circulares de madera verde/marrón/amarilla/roja/azul, arco de ladrillo/piedra,
 * ventanas circulares con celosía en X, escaleras de losas grises, calabazas y flores).
 *
 * Todas las viviendas se generan en un lienzo transparente sin bordes blancos,
 * diseñadas para perspectiva Top-Down estilo Zelda: A Link to the Past con Y-sorting.
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

/**
 * Dibuja una colina redondeada con textura de césped 16-bit (dither de 4 tonos verdes)
 */
export function drawTurfMound(ctx, cx, cy, rx, ry) {
  // Sombra proyectada en la base del montículo
  ctx.fillStyle = 'rgba(10, 18, 8, 0.35)';
  ctx.beginPath();
  ctx.ellipse(cx, cy + ry * 0.45, rx + 4, ry * 0.55, 0, 0, Math.PI * 2);
  ctx.fill();

  for (let y = -ry; y <= ry * 0.55; y += 2) {
    const normY = y / ry;
    const spanRatio = Math.sqrt(Math.max(0, 1 - normY * normY * 0.85));
    const halfW = Math.round(rx * spanRatio);
    for (let x = -halfW; x <= halfW; x += 2) {
      const distRatio = (x * x) / (rx * rx) + (y * y) / (ry * ry);
      // Paleta Referencia A: musgo oscuro, verde medio, verde hierba, verde pastel iluminado arriba
      let col = '#4f773b';
      if (y < -ry * 0.35 && distRatio < 0.7) {
        col = (x + y) % 4 === 0 ? '#a2bf7a' : '#799e58';
      } else if (y < 0) {
        col = (x * 3 + y) % 5 === 0 ? '#799e58' : '#588242';
      } else {
        col = (x + y) % 3 === 0 ? '#395929' : '#4a6e36';
      }
      // Borde exterior oscuro de la colina
      if (Math.abs(x) >= halfW - 3 || y <= -ry + 3) {
        col = '#2a421e';
      }
      rect(ctx, cx + x, cy + y, 2, 2, col);
    }
  }
}

/**
 * Dibuja una puerta circular hobbit con su arco de dovelas de madera/ladrillo y pomo central
 */
export function drawRoundHobbitDoor(ctx, cx, cy, radius, doorColor, doorDark, archColor = '#b06c3b') {
  const rOut = radius + 4;
  for (let dy = -rOut; dy <= rOut; dy++) {
    for (let dx = -rOut; dx <= rOut; dx++) {
      const d2 = dx * dx + dy * dy;
      if (d2 <= rOut * rOut && d2 > radius * radius) {
        // Arco de ladrillo/piedra cálida (Referencia A)
        const brickToggle = (Math.floor((dx + rOut) / 3) + Math.floor((dy + rOut) / 3)) % 2 === 0;
        rect(ctx, cx + dx, cy + dy, 1, 1, brickToggle ? archColor : '#874c24');
      } else if (d2 <= radius * radius) {
        // Tablones verticales de la puerta circular
        const isSeam = Math.abs(dx) % 4 === 0;
        const isShadowTop = dy < -radius + 3 || dx < -radius + 3;
        let col = isSeam ? doorDark : doorColor;
        if (isShadowTop) col = '#152918';
        rect(ctx, cx + dx, cy + dy, 1, 1, col);
      }
    }
  }
  // Pomo de latón/bronce en el centro exacto (característico de los hobbits)
  rect(ctx, cx - 2, cy - 1, 4, 4, '#3d2310');
  rect(ctx, cx - 1, cy, 2, 2, '#f0c441');
}

/**
 * Dibuja una ventana circular hobbit con marco de ladrillo y celosía en X blanca/azulada (Referencia A)
 */
export function drawRoundWindow(ctx, cx, cy, radius = 8) {
  const rOut = radius + 3;
  for (let dy = -rOut; dy <= rOut; dy++) {
    for (let dx = -rOut; dx <= rOut; dx++) {
      const d2 = dx * dx + dy * dy;
      if (d2 <= rOut * rOut && d2 > radius * radius) {
        const toggle = (dx + dy) % 2 === 0;
        rect(ctx, cx + dx, cy + dy, 1, 1, toggle ? '#a86434' : '#7d441d');
      } else if (d2 <= radius * radius) {
        // Cristal con reflejo celeste y celosía en X
        const onLattice = Math.abs(Math.abs(dx) - Math.abs(dy)) <= 1;
        if (onLattice) {
          rect(ctx, cx + dx, cy + dy, 1, 1, '#e6f2f5');
        } else {
          rect(ctx, cx + dx, cy + dy, 1, 1, dy < 0 ? '#3b6675' : '#6fa4b8');
        }
      }
    }
  }
}

/**
 * Dibuja los escalones de piedra gris clara y macetas/calabazas frente al smial (Referencia A)
 */
export function drawStoneStepsAndGarden(ctx, doorX, bottomY, stepsCount = 4, hasPumpkin = true) {
  for (let i = 0; i < stepsCount; i++) {
    const sy = bottomY + i * 5;
    const sw = 28 + i * 4;
    const sx = doorX - Math.floor(sw / 2) + (i % 2 === 0 ? 0 : 2);
    rect(ctx, sx, sy, sw, 4, '#7a8288');
    rect(ctx, sx + 1, sy, sw - 2, 3, '#cfd6db');
    // Juntas de losas
    rect(ctx, sx + Math.floor(sw * 0.35), sy, 1, 4, '#6e767c');
    rect(ctx, sx + Math.floor(sw * 0.7), sy, 1, 4, '#6e767c');
  }

  // Macetas con flores amarillas y rosas junto a la puerta (como en la imagen de Referencia A)
  rect(ctx, doorX - 22, bottomY - 6, 8, 6, '#8f522c');
  rect(ctx, doorX - 24, bottomY - 12, 12, 7, '#2f5922');
  rect(ctx, doorX - 22, bottomY - 13, 3, 3, '#ffdf38');
  rect(ctx, doorX - 17, bottomY - 11, 3, 3, '#ffdf38');
  rect(ctx, doorX - 20, bottomY - 9, 3, 3, '#ffdf38');

  rect(ctx, doorX + 15, bottomY - 5, 7, 5, '#8f522c');
  rect(ctx, doorX + 14, bottomY - 10, 9, 5, '#e85d9c');
  rect(ctx, doorX + 16, bottomY - 11, 5, 3, '#ff8cc2');

  if (hasPumpkin) {
    // Calabaza naranja a la izquierda entre los arbustos (Referencia A)
    rect(ctx, doorX - 42, bottomY - 4, 12, 8, '#d96b14');
    rect(ctx, doorX - 40, bottomY - 4, 8, 7, '#f28729');
    rect(ctx, doorX - 37, bottomY - 6, 2, 2, '#3d6e29');
  }

  // Arbustos floridos en las esquinas de la colina
  const flowerColors = ['#e84a8a', '#ffdd40', '#ff77a9'];
  for (let i = 0; i < 10; i++) {
    const fx = doorX - 48 + i * 10 + (i % 2) * 3;
    const fy = bottomY + (i % 3) * 4 - 2;
    if (Math.abs(fx - doorX) > 16) {
      rect(ctx, fx, fy, 5, 4, '#376128');
      rect(ctx, fx + 1, fy + 1, 2, 2, flowerColors[i % flowerColors.length]);
    }
  }
}

/**
 * Construye una variante del catálogo de Viviendas Hobbit Tradicionales (Smials)
 */
export function buildHobbitHouseVariant(config) {
  const {
    width = 128,
    height = 96,
    doorColor = '#1e5c2e',
    doorDark = '#14401f',
    windowCount = 2,
    hasChimney = true,
    hasRoofTree = false,
    hasPumpkin = true,
  } = config;

  const { canvas, ctx } = createCanvas(width, height);
  const cx = Math.floor(width / 2);
  const moundCy = Math.floor(height * 0.56);
  const rx = Math.floor(width * 0.46);
  const ry = Math.floor(height * 0.44);

  // 1. Colina verde con textura pixelada 16-bit
  drawTurfMound(ctx, cx, moundCy, rx, ry);

  // 2. Chimenea de ladrillo/piedra asomando sobre el césped
  if (hasChimney) {
    const chX = cx - Math.floor(rx * 0.35);
    const chY = moundCy - ry + 4;
    rect(ctx, chX, chY, 12, 16, '#5c3a24');
    rect(ctx, chX + 1, chY + 1, 10, 14, '#8f5735');
    rect(ctx, chX - 1, chY, 14, 3, '#a86b44');
    rect(ctx, chX + 3, chY - 3, 6, 3, 'rgba(220, 225, 230, 0.55)');
  }

  // 3. Árbol o raíces sobre la colina (como en la esquina derecha de la Referencia A o el Roble de Bolsón Cerrado)
  if (hasRoofTree) {
    const tx = cx + Math.floor(rx * 0.25);
    const ty = moundCy - ry + 10;
    // Raíces abrazando el montículo
    rect(ctx, tx - 8, ty + 8, 20, 5, '#422814');
    rect(ctx, tx - 12, ty + 12, 10, 3, '#422814');
    rect(ctx, tx - 4, ty - 14, 12, 24, '#54341c');
    // Copa frondosa del roble
    drawFoliageCluster(ctx, tx + 2, ty - 18, 28, 18);
  }

  // 4. Fachada curva de estuco color crema/ocre cálido y vigas de roble (Referencia A)
  const facadeW = Math.floor(rx * 1.48);
  const facadeH = 30;
  const facadeX = cx - Math.floor(facadeW / 2);
  const facadeY = moundCy + 2;

  // Viga curva oscura superior bajo el césped
  rect(ctx, facadeX - 2, facadeY - 4, facadeW + 4, 6, '#362010');
  // Pared de estuco color crema/arena cálida
  rect(ctx, facadeX, facadeY, facadeW, facadeH, '#dfbe82');
  rect(ctx, facadeX + 2, facadeY + 2, facadeW - 4, facadeH - 4, '#edd29f');

  // Vigas verticales divisorias de madera clara
  if (windowCount >= 1) {
    rect(ctx, cx - 22, facadeY - 2, 4, facadeH, '#c49e62');
    rect(ctx, cx - 21, facadeY - 2, 2, facadeH, '#e3c38d');
  }
  if (windowCount >= 2) {
    rect(ctx, cx + 18, facadeY - 2, 4, facadeH, '#c49e62');
    rect(ctx, cx + 19, facadeY - 2, 2, facadeH, '#e3c38d');
  }

  // Farolillo sobre la puerta central (Referencia A)
  rect(ctx, cx - 2, facadeY - 5, 4, 5, '#2b1d12');
  rect(ctx, cx - 1, facadeY - 4, 2, 3, '#d8f0ff');

  // 5. Ventanas circulares con celosía en X
  if (windowCount >= 1) {
    drawRoundWindow(ctx, cx - 35, facadeY + 14, 7);
  }
  if (windowCount >= 2) {
    drawRoundWindow(ctx, cx + 35, facadeY + 14, 7);
  }

  // 6. Puerta circular hobbit
  const doorY = facadeY + 15;
  drawRoundHobbitDoor(ctx, cx, doorY, 13, doorColor, doorDark);

  // 7. Escalones de piedra y jardín florido frontal
  drawStoneStepsAndGarden(ctx, cx, facadeY + facadeH - 2, 4, hasPumpkin);

  return canvas;
}

function drawFoliageCluster(ctx, cx, cy, rx, ry) {
  // Estética de copa de árbol en 3-4 bloques rectangulares escalonados (idéntica a SpriteAtlas.createTreeTile)
  const w = Math.round(rx * 1.6);
  const h = Math.round(ry * 1.3);
  rect(ctx, cx - w / 2, cy - h / 2 + 2, w, h, '#1e4d1b');
  rect(ctx, cx - w / 2 + 2, cy - h / 2, w - 4, h - 2, '#2e6f28');
  rect(ctx, cx - w / 2 + 4, cy - h / 2 + 2, w - 8, Math.round(h * 0.65), '#44913b');
  rect(ctx, cx - w / 2 + 6, cy - h / 2 + 3, Math.round(w * 0.45), Math.round(h * 0.35), '#62b356');
}

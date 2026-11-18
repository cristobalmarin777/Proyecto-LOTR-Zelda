/**
 * RuralHouseGenerator — Generador Pixel Art 16-bit de Casas Rurales de La Comarca
 * basado fielmente en la Referencia B:
 *  - Tejados de paja dorada a dos aguas y en L con caballete trenzado en espiga y varas de sujeción.
 *  - Muros de entramado de madera (timber framing, estuco blanco cálido con vigas de roble en diagonal/vertical).
 *  - Chimenea robusta de piedra gris clara en la parte superior.
 *  - Puerta arqueada de madera con ventanuco negro y pomo metálico.
 *  - Ventanas de madera con cuarterones azul oscuro.
 *  - Escalera de mano apoyada en la fachada y losa de piedra en la entrada.
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
 * Dibuja una chimenea de bloques de piedra gris clara (Referencia B)
 */
export function drawStoneChimney(ctx, x, y, w = 22, h = 18) {
  rect(ctx, x, y, w, h, '#8c8881');
  rect(ctx, x + 1, y + 1, w - 2, h - 2, '#d9d4cc');
  // Bloques de mampostería y dos salidas superiores
  rect(ctx, x + 2, y + 2, 7, 4, '#bab4aa');
  rect(ctx, x + 12, y + 2, 7, 4, '#bab4aa');
  rect(ctx, x + 1, y + 8, w - 2, 1, '#9e9990');
  rect(ctx, x + 10, y + 8, 1, h - 8, '#9e9990');
}

/**
 * Dibuja una ventana cuadrada con cuarterones azul noche (Referencia B)
 */
export function drawSquareTimberWindow(ctx, x, y, w = 14, h = 14) {
  // Marco de roble
  rect(ctx, x - 1, y - 1, w + 2, h + 2, '#5c3818');
  rect(ctx, x, y, w, h, '#3d5894');
  // Cuatro paneles oscuros
  const pw = Math.floor((w - 3) / 2);
  const ph = Math.floor((h - 3) / 2);
  rect(ctx, x + 1, y + 1, pw, ph, '#142042');
  rect(ctx, x + 2 + pw, y + 1, pw, ph, '#142042');
  rect(ctx, x + 1, y + 2 + ph, pw, ph, '#142042');
  rect(ctx, x + 2 + pw, y + 2 + ph, pw, ph, '#142042');
  // Brillo superior izquierdo en cada cristal
  rect(ctx, x + 1, y + 1, 2, 2, '#6287d6');
  rect(ctx, x + 2 + pw, y + 1, 2, 2, '#6287d6');
}

/**
 * Dibuja la puerta rústica de madera con arco superior y pomo (Referencia B)
 */
export function drawRuralWoodDoor(ctx, x, y, w = 18, h = 24) {
  // Marco grueso de madera
  rect(ctx, x - 2, y - 2, w + 4, h + 2, '#5e3914');
  rect(ctx, x, y, w, h, '#a86b24');
  rect(ctx, x + 2, y + 2, w - 4, h - 3, '#c48335');
  // Ventanuco oscuro semicircular arriba
  rect(ctx, x + 4, y + 4, w - 8, 5, '#1a120b');
  // Recuadro inferior tallado
  rect(ctx, x + 4, y + 12, w - 8, 8, '#8f5619');
  rect(ctx, x + 5, y + 13, w - 10, 6, '#b8772b');
  // Pomo plateado a la derecha
  rect(ctx, x + w - 5, y + 10, 3, 2, '#e6e8ec');
  // Losa de piedra redonda frente a la puerta
  rect(ctx, x + 2, y + h + 1, w - 4, 5, '#7a6f5d');
  rect(ctx, x + 3, y + h + 2, w - 6, 3, '#9c907a');
}

/**
 * Dibuja un tejado horizontal de paja dorada con maderos superiores (Referencia B)
 */
export function drawHorizontalThatchWing(ctx, x, y, w, h) {
  // Sombra proyectada por el alero sobre la pared y el suelo
  rect(ctx, x + 4, y + h, w, 4, 'rgba(20, 30, 18, 0.35)');

  // Cuerpo de paja en degradado dorado cálido
  for (let row = 0; row < h; row++) {
    const t = row / h;
    let col = '#f5eb67';
    if (t < 0.22) col = '#db9f27';
    else if (t < 0.45) col = '#f0cc46';
    else if (t > 0.82) col = '#d49422';

    // Faldón acampanado hacia abajo (como en la imagen de Referencia B)
    const flare = Math.round(Math.sin(t * Math.PI) * 4);
    rect(ctx, x - flare, y + row, w + flare * 2, 1, col);
  }

  // Textura vertical de hebras de paja
  for (let sx = x + 3; sx < x + w - 3; sx += 4) {
    rect(ctx, sx, y + 8, 1, h - 10, '#e3ba39');
    rect(ctx, sx + 2, y + h - 7, 1, 6, '#b37415');
  }

  // Caballete horizontal superior con varas cruzadas de sujeción (Referencia B)
  rect(ctx, x + 2, y - 2, w - 4, 7, '#bd7b19');
  rect(ctx, x + 2, y, w - 4, 5, '#e8b638');
  for (let rx = x + 6; rx < x + w - 6; rx += 11) {
    rect(ctx, rx, y - 3, 3, 13, '#8f5210');
    rect(ctx, rx + 1, y - 2, 1, 11, '#c98224');
  }
}

/**
 * Dibuja un hastial (gablete frontal en A) de paja con trenzado en espiga (Referencia B)
 */
export function drawFrontGableThatch(ctx, cx, topY, halfW, height) {
  // Sombra exterior e interior del hastial
  for (let dy = 0; dy < height; dy++) {
    const ratio = dy / height;
    const span = Math.round(10 + (halfW - 10) * Math.pow(ratio, 0.85));

    // Cuerpo de paja lateral izquierdo (iluminado) y derecho (sombreado cálido)
    rect(ctx, cx - span, topY + dy, span, 1, dy % 3 === 0 ? '#f7ee72' : '#ebd04b');
    rect(ctx, cx, topY + dy, span, 1, dy % 3 === 0 ? '#d99824' : '#bf7b17');

    // Trenzado central en espiga (chevron del caballete en Referencia B)
    const chevronW = Math.min(span - 2, 12);
    const isDarkChevron = Math.floor(dy / 4) % 2 === 0;
    rect(
      ctx,
      cx - chevronW,
      topY + dy,
      chevronW * 2,
      1,
      isDarkChevron ? '#8f5112' : '#d69324'
    );
  }
}

/**
 * Construye una Casa Rural en L o Rectangular (Referencia B)
 */
export function buildRuralHouseVariant(config) {
  const {
    style = 'l_shape', // 'l_shape' (exacta a Referencia B) | 'cottage' | 'barn'
    width = 148,
    height = 118,
    hasLadder = true,
    hasChimney = true,
  } = config;

  const { canvas, ctx } = createCanvas(width, height);

  if (style === 'l_shape') {
    // Sombra general sobre el césped
    rect(ctx, 14, 72, 122, 34, 'rgba(15, 28, 12, 0.3)');

    // 1. Chimenea de piedra arriba a la izquierda (Referencia B)
    if (hasChimney) {
      drawStoneChimney(ctx, 42, 6, 24, 20);
    }

    // 2. Muro derecho de entramado de madera (estuco blanco cálido + vigas de roble)
    const rwX = 64;
    const rwY = 58;
    const rwW = 68;
    const rwH = 30;
    rect(ctx, rwX, rwY, rwW, rwH, '#e8dfd5');
    // Vigas horizontales y verticales
    rect(ctx, rwX, rwY, rwW, 4, '#6e4318');
    rect(ctx, rwX, rwY + 15, rwW, 4, '#7d4d1d');
    rect(ctx, rwX, rwY + rwH - 3, rwW, 3, '#5c3712');
    for (let vx = rwX; vx <= rwX + rwW - 4; vx += 21) {
      rect(ctx, vx, rwY, 4, rwH, '#6e4318');
    }
    // Dos ventanas azules en el ala derecha
    drawSquareTimberWindow(ctx, rwX + 6, rwY + 3, 13, 13);
    drawSquareTimberWindow(ctx, rwX + 44, rwY + 3, 13, 13);

    // 3. Tejado horizontal de paja dorada sobre el ala derecha
    drawHorizontalThatchWing(ctx, 56, 22, 80, 40);

    // 4. Escalera de madera apoyada en el tejado derecho (detalle icónico de Referencia B)
    if (hasLadder) {
      const lx = 94;
      const ly = 54;
      rect(ctx, lx, ly, 2, 38, '#7a4e21');
      rect(ctx, lx + 12, ly, 2, 38, '#7a4e21');
      for (let ry = ly + 4; ry < ly + 36; ry += 7) {
        rect(ctx, lx - 1, ry, 16, 2, '#ab7638');
      }
    }

    // 5. Ala izquierda adelantada con hastial en A y entramado curvo
    const lwX = 16;
    const lwY = 50;
    const lwW = 54;
    const lwH = 52;
    rect(ctx, lwX, lwY, lwW, lwH, '#ede4da');
    // Vigas del hastial y diagonales (Referencia B)
    rect(ctx, lwX, lwY, 4, lwH, '#6e4318');
    rect(ctx, lwX + lwW - 4, lwY, 4, lwH, '#6e4318');
    rect(ctx, lwX, lwY + 22, lwW, 4, '#8c5822');
    // Poste central del hastial y tornapuntas diagonales
    rect(ctx, lwX + 25, lwY - 6, 4, 28, '#9e672b');
    for (let i = 0; i < 14; i++) {
      rect(ctx, lwX + 10 + i, lwY + 8 + i, 3, 3, '#9e672b');
      rect(ctx, lwX + 40 - i, lwY + 8 + i, 3, 3, '#9e672b');
    }

    // Ventana izquierda y Puerta principal de madera
    drawSquareTimberWindow(ctx, lwX + 6, lwY + 27, 13, 13);
    drawRuralWoodDoor(ctx, lwX + 24, lwY + 26, 18, 25);

    // 6. Tejado en hastial frontal sobre el ala izquierda
    drawFrontGableThatch(ctx, lwX + 27, 16, 32, 42);
  } else if (style === 'cottage') {
    // Casa rural compacta (como la que asoma arriba a la izquierda en Referencia B)
    rect(ctx, 10, 56, width - 20, 32, 'rgba(15, 28, 12, 0.3)');
    if (hasChimney) drawStoneChimney(ctx, width - 38, 6, 18, 16);

    const bx = 16;
    const by = 46;
    const bw = width - 32;
    const bh = 38;
    rect(ctx, bx, by, bw, bh, '#ebe2d8');
    rect(ctx, bx, by, 4, bh, '#6e4318');
    rect(ctx, bx + bw - 4, by, 4, bh, '#6e4318');
    rect(ctx, bx, by + 16, bw, 4, '#7d4d1d');

    drawSquareTimberWindow(ctx, bx + 8, by + 19, 13, 13);
    if (bw > 74) {
      drawSquareTimberWindow(ctx, bx + bw - 21, by + 19, 13, 13);
    }
    drawRuralWoodDoor(ctx, Math.floor(width / 2) - 8, by + 13, 17, 24);
    drawHorizontalThatchWing(ctx, 10, 16, width - 20, 34);
  } else {
    // Granero / Cobertizo auxiliar de piedra y madera
    rect(ctx, 10, 48, width - 20, 30, 'rgba(15, 28, 12, 0.3)');
    const bx = 14;
    const by = 38;
    const bw = width - 28;
    const bh = 34;
    rect(ctx, bx, by, bw, bh, '#8c8274');
    // Mampostería de piedra rústica
    for (let y = by + 4; y < by + bh - 4; y += 6) {
      for (let x = bx + 4; x < bx + bw - 8; x += 10) {
        rect(ctx, x, y, 7, 4, '#aba090');
      }
    }
    rect(ctx, bx, by, 4, bh, '#593716');
    rect(ctx, bx + bw - 4, by, 4, bh, '#593716');
    drawRuralWoodDoor(ctx, Math.floor(width / 2) - 9, by + 9, 18, 24);
    drawHorizontalThatchWing(ctx, 8, 12, width - 16, 28);
  }

  return canvas;
}

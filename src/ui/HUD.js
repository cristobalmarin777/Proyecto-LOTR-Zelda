/**
 * HUD — Interfaz de usuario estilo Zelda: A Link to the Past (SNES).
 * Dibuja en el canvas:
 *  - Barra de corazones de vida (arriba a la izquierda).
 *  - Ranura de objeto equipado [Q], Espada [ESPACIO], Monedas, Flechas y Nivel (arriba).
 *  - Indicador de Misión Principal activa y región actual (arriba a la derecha).
 *  - Minimapa interactivo de La Comarca (abajo a la derecha).
 *  - Prompts contextuales "[E] Hablar / Abrir" sobre personajes o cofres cercanos.
 */
export class HUD {
  constructor() {
    this.dialogBox = document.getElementById('dialog-box');
    this.dialogSpeaker = document.getElementById('dialog-speaker');
    this.dialogText = document.getElementById('dialog-text');
    this.invOverlay = document.getElementById('inventory-overlay');
    this.invGrid = document.getElementById('inventory-grid');
    this.invDesc = document.getElementById('inventory-desc');
    this.statsSummary = document.getElementById('player-stats-summary');
    this.worldMapCanvas = document.getElementById('world-map-canvas');
    this.worldMapStatus = document.getElementById('world-map-status');
  }

  draw(ctx, player, questState, map, enemies, interactionHint) {
    // Banda superior translúcida estilo RPG 16-bit
    ctx.fillStyle = 'rgba(10, 14, 12, 0.82)';
    ctx.fillRect(0, 0, 960, 54);
    ctx.fillStyle = '#b89446';
    ctx.fillRect(0, 52, 960, 2);

    // 1. VIDA (Corazones estilo Zelda)
    ctx.font = 'bold 12px "Courier New", monospace';
    ctx.fillStyle = '#e8d8a8';
    ctx.fillText(' — VIDA — ', 18, 16);

    for (let i = 0; i < player.maxHp; i++) {
      const hx = 20 + i * 20;
      const hy = 24;
      const filled = i < player.hp;
      this.drawHeartIcon(ctx, hx, hy, filled);
    }

    // 2. RANURA EQUIPADA [Q] Y ESPADA [ESPACIO]
    const weapon = player.getEquippedWeapon();
    this.drawSlotBox(ctx, 210, 7, 125, 40, '[ESPACIO] Arma', `${weapon?.icon || '🗡️'} ${weapon?.name || 'Daga'} (${player.swordDamage})`);

    const eqItem = player.inventory.find((i) => i.id === player.equippedItemId);
    const eqLabel = eqItem ? `${eqItem.icon} ${eqItem.name.split(' ')[0]}` : 'Nada';
    this.drawSlotBox(ctx, 345, 7, 135, 40, '[Q] Objeto Activo', eqLabel);

    // 3. MONEDAS, FLECHAS Y NIVEL
    ctx.fillStyle = '#ffd700';
    ctx.font = 'bold 13px "Courier New", monospace';
    ctx.fillText(`🪙 ${player.coins}`, 495, 23);
    ctx.fillStyle = '#a8e090';
    ctx.fillText(`🏹 ${player.arrows}`, 495, 42);
    ctx.fillStyle = '#b9d1df';
    ctx.fillText(`🛡️ ${player.armorDefense}`, 620, 23);
    this.drawArmorCooldown(ctx, player, 682, 27);

    ctx.fillStyle = '#8ad8ff';
    ctx.fillText(`NV. ${player.level}`, 560, 23);
    ctx.fillStyle = '#cfcfcf';
    ctx.font = '11px "Courier New", monospace';
    ctx.fillText(`XP ${player.xp}/${player.nextLevelXp}`, 560, 42);

    // 4. REGIÓN ACTUAL
    ctx.textAlign = 'right';
    ctx.font = 'bold 12px "Courier New", monospace';
    ctx.fillStyle = '#ffd866';
    const regionName = map.getBiomeNameAtPixel
      ? map.getBiomeNameAtPixel(player.x, player.y)
      : 'LA COMARCA';
    ctx.fillText(`REGIÓN: ${regionName}`, 944, 20);
    ctx.textAlign = 'left';

    this.drawQuestPanel(ctx, questState);

    // 5. PROMPT CONTEXTUAL DE INTERACCIÓN [E]
    if (interactionHint) {
      const text = `[E] ${interactionHint}`;
      ctx.font = 'bold 13px "Courier New", monospace';
      const w = ctx.measureText(text).width + 24;
      const bx = Math.round(480 - w / 2);
      const by = 588;

      ctx.fillStyle = 'rgba(15, 20, 15, 0.9)';
      ctx.fillRect(bx, by, w, 28);
      ctx.strokeStyle = '#ffd866';
      ctx.lineWidth = 2;
      ctx.strokeRect(bx, by, w, 28);

      ctx.fillStyle = '#ffe999';
      ctx.textAlign = 'center';
      ctx.fillText(text, 480, by + 18);
      ctx.textAlign = 'left';
    }

    // 6. MINIMAPA DE LA COMARCA (Abajo a la derecha)
    this.drawMinimap(ctx, player, map, enemies);
  }

  drawQuestPanel(ctx, questState) {
    const x = 708; const y = 64; const w = 238;
    ctx.fillStyle = 'rgba(11, 15, 14, 0.88)';
    ctx.fillRect(x, y, w, 138);
    ctx.strokeStyle = '#8c6d3b';
    ctx.lineWidth = 2;
    ctx.strokeRect(x, y, w, 138);
    ctx.font = 'bold 12px "Courier New", monospace';
    ctx.fillStyle = '#ffd866';
    ctx.fillText('📜 MISIONES', x + 10, y + 17);
    ctx.font = 'bold 11px "Courier New", monospace';
    ctx.fillStyle = questState.completed ? '#7dff8b' : '#ffe394';
    ctx.fillText('PRINCIPAL', x + 10, y + 36);
    this.drawWrappedText(ctx, questState.objectiveText, x + 10, y + 50, w - 20, 13, '#f2ebd9', 2);
    ctx.fillStyle = '#9ad972';
    ctx.fillText('SECUNDARIAS', x + 10, y + 91);
    let lineY = y + 105;
    for (const quest of (questState.secondary || []).slice(0, 2)) {
      this.drawWrappedText(ctx, `${quest.completed ? '✓' : '○'} ${quest.title}`, x + 10, lineY, w - 20, 12, quest.completed ? '#7dff8b' : '#c8d9b8', 1);
      lineY += 17;
    }
  }

  drawWrappedText(ctx, text, x, y, maxWidth, lineHeight, color, maxLines) {
    ctx.font = '11px "Courier New", monospace';
    ctx.fillStyle = color;
    const words = text.split(' ');
    let line = ''; let lines = 0;
    for (const word of words) {
      const candidate = line ? `${line} ${word}` : word;
      if (ctx.measureText(candidate).width > maxWidth && line) {
        ctx.fillText(line, x, y + lines * lineHeight);
        lines += 1;
        line = word;
        if (lines >= maxLines) return;
      } else line = candidate;
    }
    if (lines < maxLines) ctx.fillText(line, x, y + lines * lineHeight);
  }

  drawHeartIcon(ctx, x, y, filled) {
    ctx.fillStyle = '#291114';
    ctx.fillRect(x - 1, y - 1, 16, 14);

    ctx.fillStyle = filled ? '#ef233c' : '#4a252aa0';
    ctx.fillRect(x + 2, y + 1, 4, 4);
    ctx.fillRect(x + 8, y + 1, 4, 4);
    ctx.fillRect(x, y + 3, 14, 5);
    ctx.fillRect(x + 2, y + 8, 10, 3);
    ctx.fillRect(x + 5, y + 11, 4, 2);

    if (filled) {
      ctx.fillStyle = '#ff99ac';
      ctx.fillRect(x + 2, y + 2, 2, 2);
    }
  }

  drawArmorCooldown(ctx, player, x, y) {
    const radius = 11;
    const progress = player.armorDefense <= 0 ? 0 : 1 - player.armorCooldown / player.armorCooldownDuration;
    ctx.save();
    ctx.lineWidth = 3;
    ctx.strokeStyle = '#293840';
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.stroke();
    if (progress > 0) {
      ctx.strokeStyle = player.armorCooldown <= 0 ? '#8ce9ff' : '#6e9fb1';
      ctx.beginPath();
      ctx.arc(x, y, radius, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * progress);
      ctx.stroke();
    }
    ctx.fillStyle = '#d7f3e1';
    ctx.font = 'bold 8px "Courier New", monospace';
    ctx.textAlign = 'center';
    ctx.fillText('DEF', x, y + 3);
    ctx.restore();
  }

  drawSlotBox(ctx, x, y, w, h, topLabel, valueText) {
    ctx.fillStyle = '#18140e';
    ctx.fillRect(x, y, w, h);
    ctx.strokeStyle = '#8c6d3b';
    ctx.lineWidth = 2;
    ctx.strokeRect(x, y, w, h);

    ctx.fillStyle = '#b8a47e';
    ctx.font = '10px "Courier New", monospace';
    ctx.fillText(topLabel, x + 6, y + 13);

    ctx.fillStyle = '#fff3d1';
    ctx.font = 'bold 12px "Courier New", monospace';
    ctx.fillText(valueText, x + 6, y + 31);
  }

  drawMinimap(ctx, player, map, enemies) {
    const mw = 144;
    const mh = 102;
    const mx = 960 - mw - 14;
    const my = 640 - mh - 14;

    ctx.fillStyle = 'rgba(12, 18, 12, 0.85)';
    ctx.fillRect(mx, my, mw, mh);
    ctx.strokeStyle = '#b89446';
    ctx.lineWidth = 2;
    ctx.strokeRect(mx, my, mw, mh);

    if (map.isInfinite) {
      this.drawWorldMinimap(ctx, player, map, enemies, mx, my, mw, mh);
      return;
    }

    const scaleX = mw / map.width;
    const scaleY = mh / map.height;

    // Río en el minimapa
    ctx.fillStyle = '#2b6cb0';
    ctx.fillRect(mx + Math.round(25 * 32 * scaleX), my + 2, 6, mh - 4);

    // Enemigos vivos (puntos rojos)
    for (const e of enemies) {
      if (e.dead) continue;
      ctx.fillStyle = e.isMiniBoss ? '#ff9f1c' : '#ff3b3b';
      const ex = mx + Math.round(e.x * scaleX);
      const ey = my + Math.round(e.y * scaleY);
      ctx.fillRect(ex - 2, ey - 2, e.isMiniBoss ? 5 : 3, e.isMiniBoss ? 5 : 3);
    }

    // Cofres cerrados (puntos dorados)
    ctx.fillStyle = '#ffd700';
    for (const ch of map.chests) {
      if (ch.opened) continue;
      const cx = mx + Math.round((ch.col + 0.5) * 32 * scaleX);
      const cy = my + Math.round((ch.row + 0.5) * 32 * scaleY);
      ctx.fillRect(cx - 2, cy - 2, 4, 4);
    }

    // Jugador (punto verde brillante con borde blanco)
    const px = mx + Math.round(player.x * scaleX);
    const py = my + Math.round(player.y * scaleY);
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(px - 3, py - 3, 6, 6);
    ctx.fillStyle = '#38ff62';
    ctx.fillRect(px - 2, py - 2, 4, 4);
  }

  drawWorldMinimap(ctx, player, map, enemies, mx, my, mw, mh) {
    const cell = 4;
    const cols = Math.floor((mw - 4) / cell);
    const rows = Math.floor((mh - 4) / cell);
    const playerCol = Math.floor(player.x / map.tileSize);
    const playerRow = Math.floor(player.y / map.tileSize);
    const startCol = playerCol - Math.floor(cols / 2);
    const startRow = playerRow - Math.floor(rows / 2);
    const colors = {
      0: '#478932', 1: '#295b1a', 2: '#65a94a', 3: '#b98f58', 4: '#878d96',
      5: '#235789', 7: '#1e4d1b', 9: '#4a4e54', 13: '#2b5228',
    };

    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        ctx.fillStyle = colors[map.getTile(startCol + c, startRow + r)] || '#6d6b54';
        ctx.fillRect(mx + 2 + c * cell, my + 2 + r * cell, cell, cell);
      }
    }
    for (const b of map.buildings || []) {
      const bCol = (b.x + b.def.width / 2) / map.tileSize;
      const bRow = b.sortY / map.tileSize;
      const bx = mx + 2 + (bCol - startCol) * cell;
      const by = my + 2 + (bRow - startRow) * cell;
      if (bx >= mx + 2 && bx <= mx + mw - 4 && by >= my + 2 && by <= my + mh - 4) {
        ctx.fillStyle = b.catalogId.startsWith('rural') ? '#f0cc46' : '#7ef069';
        ctx.fillRect(Math.round(bx) - 2, Math.round(by) - 2, 5, 4);
      }
    }
    for (const enemy of enemies) {
      if (enemy.dead) continue;
      const ex = mx + 2 + (enemy.x / map.tileSize - startCol) * cell;
      const ey = my + 2 + (enemy.y / map.tileSize - startRow) * cell;
      if (ex >= mx && ex <= mx + mw && ey >= my && ey <= my + mh) {
        ctx.fillStyle = enemy.isMiniBoss ? '#ff9f1c' : '#ff3b3b';
        ctx.fillRect(Math.round(ex) - 2, Math.round(ey) - 2, 4, 4);
      }
    }
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(mx + Math.floor(mw / 2) - 3, my + Math.floor(mh / 2) - 3, 6, 6);
    ctx.fillStyle = '#38ff62';
    ctx.fillRect(mx + Math.floor(mw / 2) - 2, my + Math.floor(mh / 2) - 2, 4, 4);
  }

  renderInventoryModal(player, onSelectItem) {
    this.invGrid.innerHTML = '';
    player.inventory.forEach((item) => {
      const slot = document.createElement('div');
      const isEquipped = item.type === 'weapon' ? player.equippedWeaponId === item.id : item.type === 'armor' ? player.equippedArmorId === item.id : player.equippedItemId === item.id;
      slot.className = 'inv-slot' + (isEquipped ? ' equipped' : '');
      const lockedText = item.unlocked === false ? ' (Bloqueado)' : '';
      const qtyText =
        item.type === 'weapon'
          ? `Daño: ${item.damage} · Nivel ${item.requiredLevel}`
          : item.type === 'armor'
          ? `DEF: ${item.defense} · Nivel ${item.requiredLevel}`
          :
        item.id === 'potion'
          ? `Cantidad: ${item.qty}`
          : item.id === 'bow'
          ? `Flechas: ${player.arrows}`
          : item.type === 'passive'
          ? 'Equipado (Pasivo)'
          : item.qty > 0
          ? 'Obtenido'
          : 'No encontrado';

      slot.innerHTML = `
        <div class="inv-slot-title">${item.icon} ${item.name}${lockedText}</div>
        <div class="inv-slot-qty">${qtyText}</div>
      `;

      slot.addEventListener('click', () => {
        this.invDesc.textContent = item.desc;
        if ((item.type === 'active' || item.type === 'weapon' || item.type === 'armor') && item.unlocked !== false) {
          onSelectItem(item.id, item.type);
          this.renderInventoryModal(player, onSelectItem);
        }
      });

      this.invGrid.appendChild(slot);
    });

    this.statsSummary.innerHTML = `
      <span>Nivel: <strong>${player.level}</strong></span>
      <span>Corazones: <strong>${player.hp}/${player.maxHp}</strong></span>
      <span>Daño Espada: <strong>${player.swordDamage}</strong></span>
      <span>Defensa: <strong>${player.armorDefense}</strong></span>
      <span>Monedas: <strong>${player.coins}</strong></span>
      <span>Flechas: <strong>${player.arrows}</strong></span>
    `;
  }

  renderWorldMap(world, player, discoveredChunks, chartedZones, enemies) {
    const ctx = this.worldMapCanvas.getContext('2d');
    const chunk = world.getChunkAtPixel(player.x, player.y);
    const zone = world.getAtlasZoneAtChunk(chunk.x, chunk.y);
    const zoneKey = world.getAtlasZoneKey(zone.x, zone.y);
    const charted = chartedZones.has(zoneKey);
    const tilePixel = 2;
    const zoneTileSize = 9 * 32;
    const startCol = zone.x * zoneTileSize;
    const startRow = zone.y * zoneTileSize;
    const colors = { 0: '#478932', 1: '#295b1a', 2: '#65a94a', 3: '#b98f58', 4: '#878d96', 5: '#235789', 7: '#1e4d1b', 9: '#4a4e54', 13: '#2b5228' };

    ctx.fillStyle = '#090c0c';
    ctx.fillRect(0, 0, this.worldMapCanvas.width, this.worldMapCanvas.height);
    for (let row = 0; row < zoneTileSize; row++) {
      for (let col = 0; col < zoneTileSize; col++) {
        const tileCol = startCol + col;
        const tileRow = startRow + row;
        const chunkKey = `${Math.floor(tileCol / 32)},${Math.floor(tileRow / 32)}`;
        if (charted || discoveredChunks.has(chunkKey)) {
          ctx.fillStyle = colors[world.getTile(tileCol, tileRow)] || '#5b5545';
          ctx.fillRect(col * tilePixel, row * tilePixel, tilePixel, tilePixel);
        }
      }
    }

    for (const b of world.buildings || []) {
      const tileCol = Math.floor((b.x + b.def.width / 2) / world.tileSize);
      const tileRow = Math.floor(b.sortY / world.tileSize);
      const chunkKey = `${Math.floor(tileCol / 32)},${Math.floor(tileRow / 32)}`;
      if (charted || discoveredChunks.has(chunkKey)) {
        const bx = (tileCol - startCol) * tilePixel;
        const by = (tileRow - startRow) * tilePixel;
        if (bx >= 0 && bx < this.worldMapCanvas.width && by >= 0 && by < this.worldMapCanvas.height) {
          ctx.fillStyle = b.catalogId.startsWith('rural') ? '#f0cc46' : '#7ef069';
          ctx.fillRect(Math.round(bx) - 2, Math.round(by) - 2, 5, 4);
        }
      }
    }

    const px = (player.x / world.tileSize - startCol) * tilePixel;
    const py = (player.y / world.tileSize - startRow) * tilePixel;
    const glow = ctx.createRadialGradient(px, py, 2, px, py, 38);
    glow.addColorStop(0, 'rgba(255, 228, 142, 0.38)');
    glow.addColorStop(1, 'rgba(255, 228, 142, 0)');
    ctx.fillStyle = glow;
    ctx.fillRect(Math.max(0, px - 40), Math.max(0, py - 40), 80, 80);
    ctx.fillStyle = '#fff4b8';
    ctx.fillRect(Math.round(px) - 3, Math.round(py) - 3, 6, 6);

    this.worldMapStatus.textContent = `${world.getBiomeNameAtPixel(player.x, player.y)} · ${charted ? 'Carta regional descifrada' : 'Zona sin cartografiar: encuentra su cofre de mapa'}`;
  }
}

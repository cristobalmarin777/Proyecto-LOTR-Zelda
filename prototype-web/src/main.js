/**
 * Punto de entrada principal — El Señor de los Anillos: Sombras de la Tierra Media (Etapa 1).
 * Inicializa el bucle de juego a 60 FPS, el sistema de entrada y la escena de La Comarca.
 */
import { InputSystem } from './systems/InputSystem.js';
import { GameScene } from './scenes/GameScene.js';

const canvas = document.getElementById('game-canvas');
const input = new InputSystem(canvas);
const scene = new GameScene(canvas, input);

// Exponer la instancia para depuración y verificación en tiempo real
window.__LOTR_GAME__ = scene;

let lastTime = performance.now();

function gameLoop(now) {
  const dt = Math.min(0.05, (now - lastTime) / 1000);
  lastTime = now;

  scene.update(dt);
  scene.render();
  input.endFrame();

  requestAnimationFrame(gameLoop);
}

requestAnimationFrame(gameLoop);

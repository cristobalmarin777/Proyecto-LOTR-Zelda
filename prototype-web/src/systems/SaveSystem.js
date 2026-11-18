/** Guardado local, versionado y tolerante a datos corruptos. */
const SAVE_KEY = 'sombras-tierra-media-save-v1';

export class SaveSystem {
  load() {
    try {
      const raw = window.localStorage.getItem(SAVE_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  }

  save(data) {
    try {
      window.localStorage.setItem(SAVE_KEY, JSON.stringify(data));
    } catch {
      // Una partida sigue siendo jugable si el navegador bloquea almacenamiento.
    }
  }

  clear() {
    try {
      window.localStorage.removeItem(SAVE_KEY);
    } catch {
      // No hay nada más que hacer si el almacenamiento no está disponible.
    }
  }
}

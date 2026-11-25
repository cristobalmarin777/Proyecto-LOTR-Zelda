# Sombras de la Tierra Media

Proyecto de RPG de exploración inspirado en la Tierra Media. El repositorio se
organizó para mantener el juego original como referencia y construir la versión
principal en Godot 4 con GDScript.

## Estructura

- `godot/`: aplicación principal de Godot 4. Aquí continuará el desarrollo.
- `prototype-web/`: prototipo HTML/Canvas completo, conservado para comparar
  comportamiento, reutilizar ideas y no perder el trabajo previo.
- `prototype-web/proyecto 11111.tiled-*`: configuración histórica de Tiled y
  recursos recuperados del repositorio remoto.

## Ejecutar la versión Godot

1. Instala [Godot 4](https://godotengine.org/download/) (4.3 o una versión 4.x
   posterior; no hace falta C#).
2. Abre el gestor de proyectos de Godot y selecciona **Importar**.
3. Elige `godot/project.godot` dentro de este repositorio.
4. Pulsa **F6** o el botón de ejecutar proyecto.

Controles: `WASD` o flechas para moverse, `ESPACIO` para atacar, `E` para
interactuar, `Q` para Miruvor, `M` para abrir la carta regional, `F11` para
alternar entre pantalla completa y ventana, y `F5` para guardar. En modo
ventana puedes cambiar el tamaño libremente. La partida se guarda localmente
en `user://`.

La versión Godot ya contiene el núcleo del port: mundo determinista por chunks,
biomas, Bosque Viejo oscuro, minimapa zonal con niebla, cofres de cartas,
enemigos (orcos, arqueros, arañas, Uruks y duendes), campamentos, cuevas/minas,
elfos, vendedor, armas, armaduras con recarga, misiones y guardado. El
prototipo web conserva los detalles adicionales mientras la presentación y los
contenidos se trasladan iterativamente a nodos y recursos nativos de Godot.

Isengard se genera en una carta regional de 9 × 9 chunks, con Orthanc en el
centro, a 32–42 chunks del inicio. Mordor ocupa cuatro cartas contiguas
(18 × 18 chunks) a 85–110 chunks del inicio, con Udûn, Gorgoroth, Núrn,
tierras de sombra, Orodruin y Barad-dûr. Sus ubicaciones dependen de la
semilla y permanecen estables. Los interiores y jefes de estas fortalezas
todavía no están implementados.

## Ejecutar el prototipo web

Desde la raíz del repositorio:

```bash
cd prototype-web
python3 -m http.server 8080
```

Después abre `http://localhost:8080` en el navegador.


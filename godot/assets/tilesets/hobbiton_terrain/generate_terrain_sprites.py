#!/usr/bin/env python3
"""
Generador de Assets Pixel Art 16-bit (.png reales de 32x32) y Atlas de Elevaciones
para Hobbiton (Godot 4) inspirado en The Legend of Zelda: A Link to the Past.

Soluciona de raíz:
  1. Continuidad 100% exacta de la paleta de césped entre superficie superior, bordes y esquinas.
  2. Piezas dedicadas de esquina inferior izquierda (SW), inferior derecha (SE),
     superior izquierda (NW), superior derecha (NE) e interiores (cóncavas).
  3. Terminaciones de pared izquierda/derecha y paredes verticales completas sin huecos
     transparentes ni líneas artificiales.
"""
import os
import struct
import zlib

ROOT = "/Users/cm/Desktop/Proyecto11111/godot/assets"

# Paleta 16-bit unificada estilo Zelda: A Link to the Past (RGBA)
TRANSP       = (0, 0, 0, 0)
GRASS_BASE   = (88, 173, 52, 255)   # #58ad34 — Verde base único para superficie, bordes y esquinas
GRASS_LIGHT  = (114, 198, 70, 255)  # #72c646 — Brillo suave de briznas y labio superior
GRASS_HILITE = (146, 222, 92, 255)  # #92de5c — Filo iluminado de borde de colina
GRASS_MID    = (70, 148, 42, 255)   # #46942a — Sombra suave de césped
GRASS_DARK   = (42, 94, 28, 255)    # #2a5e1c — Contorno oscuro de césped / raíz
WALL_OUTLINE = (61, 41, 21, 255)    # #3d2915 — Contorno pixel art de roca/tierra
WALL_TOP     = (96, 67, 35, 255)    # #604323 — Sombra bajo el labio de césped
WALL_MID     = (140, 105, 62, 255)  # #8c693e — Tierra principal de pared
WALL_LIGHT   = (168, 129, 78, 255)  # #a8814e — Bloques iluminados de tierra/roca
WALL_SHADOW  = (110, 79, 43, 255)   # #6e4f2b — Grietas y sombras de bloques
ROCK_MID     = (120, 126, 134, 255) # #787e86 — Piedra grisácea ALTTP
ROCK_LIGHT   = (162, 169, 178, 255)
ROCK_DARK    = (74, 80, 88, 255)
DIRT_BASE    = (232, 181, 90, 255)  # #e8b55a — Camino arena dorada
DIRT_LIGHT   = (242, 195, 107, 255)
DIRT_DARK    = (214, 158, 66, 255)
SHADOW_SOFT  = (16, 28, 12, 72)     # Sombra proyectada en la base de las paredes


class PixelCanvas:
    def __init__(self, w=32, h=32, fill=TRANSP):
        self.w = w
        self.h = h
        self.pixels = [[fill for _ in range(w)] for _ in range(h)]

    def set_px(self, x, y, col):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.pixels[y][x] = col

    def rect(self, x, y, w, h, col):
        for py in range(int(y), int(y + h)):
            for px in range(int(x), int(x + w)):
                self.set_px(px, py, col)

    def blend_px(self, x, y, col):
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        sr, sg, sb, sa = col
        if sa == 0:
            return
        if sa == 255:
            self.pixels[y][x] = col
            return
        dr, dg, db, da = self.pixels[y][x]
        a = sa / 255.0
        nr = int(sr * a + dr * (1 - a))
        ng = int(sg * a + dg * (1 - a))
        nb = int(sb * a + db * (1 - a))
        na = min(255, int(sa + da * (1 - a)))
        self.pixels[y][x] = (nr, ng, nb, na)

    def blit(self, other, ox, oy):
        for y in range(other.h):
            for x in range(other.w):
                c = other.pixels[y][x]
                if c[3] > 0:
                    self.blend_px(ox + x, oy + y, c)

    def flip_x(self):
        out = PixelCanvas(self.w, self.h, TRANSP)
        for y in range(self.h):
            for x in range(self.w):
                out.pixels[y][self.w - 1 - x] = self.pixels[y][x]
        return out

    def save_png(self, path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        raw = bytearray()
        for y in range(self.h):
            raw.append(0)  # Filter type 0 (None)
            for x in range(self.w):
                r, g, b, a = self.pixels[y][x]
                raw.extend((r, g, b, a))

        def chunk(tag, data):
            return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

        ihdr = struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0)
        png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
        with open(path, "wb") as f:
            f.write(png)


def paint_grass_texture(c, variant=0):
    """Superficie de césped base 100% homogénea en toda la paleta."""
    c.rect(0, 0, 32, 32, GRASS_BASE)
    specks = [(4, 5), (17, 3), (26, 11), (8, 19), (21, 24), (13, 14), (27, 27), (5, 28)]
    for i, (sx, sy) in enumerate(specks):
        ox = (sx + variant * 5) % 30
        oy = (sy + variant * 7) % 30
        c.rect(ox, oy, 2, 1, GRASS_LIGHT if i % 2 == 0 else GRASS_MID)
    if variant == 1:
        # Brote pequeño de 3 briznas
        c.rect(12, 20, 6, 2, GRASS_DARK)
        c.rect(11, 17, 2, 3, GRASS_MID)
        c.rect(14, 15, 2, 5, GRASS_LIGHT)
        c.rect(17, 17, 2, 3, GRASS_MID)
    elif variant == 2:
        # Césped con pequeñas piedras
        c.rect(9, 14, 5, 3, ROCK_DARK)
        c.rect(10, 14, 3, 2, ROCK_LIGHT)
        c.rect(21, 22, 4, 3, ROCK_MID)
        c.rect(22, 22, 2, 1, ROCK_LIGHT)
    elif variant == 3:
        # Césped con florecillas blancas/doradas
        for fx, fy in [(9, 11), (22, 23)]:
            c.rect(fx - 2, fy + 2, 6, 2, GRASS_DARK)
            c.rect(fx - 1, fy - 2, 4, 4, (255, 255, 255, 255))
            c.rect(fx, fy - 1, 2, 2, (245, 166, 35, 255))


def make_grass_sprites():
    sprites = {}
    for v, name in [(0, "grass_center"), (1, "grass_sprout"), (2, "grass_stones"), (3, "grass_flowers")]:
        c = PixelCanvas(32, 32)
        paint_grass_texture(c, v)
        c.save_png(f"{ROOT}/terrain/grass/{name}.png")
        sprites[name] = c
    return sprites


def make_edge_sprites():
    """Bordes rectos de elevación (comparten EXACTAMENTE el mismo GRASS_BASE)."""
    sprites = {}

    # Borde superior (Norte de la colina): labio oscuro arriba -> línea clara -> césped base
    n = PixelCanvas(32, 32)
    paint_grass_texture(n, 0)
    n.rect(0, 0, 32, 2, WALL_OUTLINE)
    n.rect(0, 2, 32, 3, GRASS_DARK)
    n.rect(0, 5, 32, 2, GRASS_HILITE)
    n.save_png(f"{ROOT}/terrain/grass_edges/edge_north.png")
    sprites["edge_north"] = n

    # Borde inferior (Sur de la colina): césped base -> filo iluminado -> labio que cae a la pared
    s = PixelCanvas(32, 32)
    paint_grass_texture(s, 0)
    s.rect(0, 24, 32, 3, GRASS_HILITE)
    s.rect(0, 27, 32, 3, GRASS_DARK)
    s.rect(0, 30, 32, 2, WALL_OUTLINE)
    # Pequeñas briznas colgando irregularmente sobre el labio
    for bx in [4, 13, 23]:
        s.rect(bx, 29, 3, 2, GRASS_MID)
    s.save_png(f"{ROOT}/terrain/grass_edges/edge_south.png")
    sprites["edge_south"] = s

    # Borde izquierdo (Oeste de la colina): pared lateral de tierra + filo iluminado + césped base
    w = PixelCanvas(32, 32)
    paint_grass_texture(w, 0)
    w.rect(0, 0, 2, 32, WALL_OUTLINE)
    w.rect(2, 0, 4, 32, WALL_MID)
    for y in range(2, 30, 8):
        w.rect(2, y, 3, 4, WALL_LIGHT)
    w.rect(6, 0, 2, 32, GRASS_DARK)
    w.rect(8, 0, 2, 32, GRASS_HILITE)
    w.save_png(f"{ROOT}/terrain/grass_edges/edge_west.png")
    sprites["edge_west"] = w

    # Borde derecho (Este de la colina): espejo sombreado del borde izquierdo
    e = PixelCanvas(32, 32)
    paint_grass_texture(e, 0)
    e.rect(30, 0, 2, 32, WALL_OUTLINE)
    e.rect(26, 0, 4, 32, WALL_SHADOW)
    for y in range(4, 30, 8):
        e.rect(27, y, 3, 4, WALL_MID)
    e.rect(24, 0, 2, 32, GRASS_DARK)
    e.rect(22, 0, 2, 32, GRASS_MID)
    e.save_png(f"{ROOT}/terrain/grass_edges/edge_east.png")
    sprites["edge_east"] = e

    return sprites


def make_corner_sprites():
    """
    Esquinas dedicadas (Exteriores NW, NE, SW, SE e Interiores NW, NE, SW, SE).
    - Las esquinas superiores (NW, NE) tienen transparencia limpia en el vértice exterior
      para dejar ver el terreno inferior real, y usan EXACTAMENTE GRASS_BASE en la superficie.
    - Las esquinas inferiores (SW, SE) están diseñadas específicamente para CERRAR la unión
      entre el borde lateral (Oeste/Este) y el borde inferior (Sur) con pared de tierra sólida
      que enlaza al píxel con el sprite de terminación inferior (0 huecos).
    """
    sprites = {}

    # 1. Esquina exterior SUPERIOR IZQUIERDA (NW)
    nw = PixelCanvas(32, 32, TRANSP)
    curve_nw = [10, 8, 6, 4, 2, 0]  # Recorte orgánico escalonado de 2 en 2 px
    for y in range(32):
        cut = curve_nw[y // 2] if y < 12 else 0
        for x in range(cut, 32):
            nw.set_px(x, y, GRASS_BASE)
    # Contorno curvo + empalme exacto con edge_north (y=0..6) y edge_west (x=0..9)
    nw.rect(10, 0, 22, 2, WALL_OUTLINE)
    nw.rect(10, 2, 22, 3, GRASS_DARK)
    nw.rect(10, 5, 22, 2, GRASS_HILITE)
    nw.rect(0, 12, 2, 20, WALL_OUTLINE)
    nw.rect(2, 12, 4, 20, WALL_MID)
    nw.rect(6, 12, 2, 20, GRASS_DARK)
    nw.rect(8, 12, 2, 20, GRASS_HILITE)
    # Arco de unión diagonal en el vértice NW
    for i, cx in enumerate([8, 6, 4, 2, 0]):
        cy = i * 2 + 2
        nw.rect(cx, cy, 2, 2, WALL_OUTLINE)
        nw.rect(cx + 2, cy, 4, 2, WALL_MID if i >= 2 else GRASS_DARK)
        nw.rect(cx + 6, cy, 2, 2, GRASS_DARK)
        nw.rect(cx + 8, cy, 2, 2, GRASS_HILITE)
    nw.save_png(f"{ROOT}/terrain/grass_corners/corner_outer_nw.png")
    sprites["corner_outer_nw"] = nw

    # 2. Esquina exterior SUPERIOR DERECHA (NE)
    ne = nw.flip_x()
    ne.save_png(f"{ROOT}/terrain/grass_corners/corner_outer_ne.png")
    sprites["corner_outer_ne"] = ne

    # 3. Esquina exterior INFERIOR IZQUIERDA (SW) — PIEZA CRÍTICA SIN HUECOS
    # Conecta edge_west (x=0..9) por arriba con edge_south (y=24..31) por la derecha
    # y entrega una base de pared sólida de x=2..31 en y=30..31 para enlazar con wall_end_left.
    sw = PixelCanvas(32, 32, TRANSP)
    for y in range(32):
        # Solo los 2 píxeles más exteriores del vértice inferior quedan transparentes para curvar el contorno
        cut = 2 if y >= 28 else 0
        for x in range(cut, 32):
            sw.set_px(x, y, GRASS_BASE)
    # Borde lateral izquierdo bajando hasta y=24
    sw.rect(0, 0, 2, 26, WALL_OUTLINE)
    sw.rect(2, 0, 4, 28, WALL_MID)
    sw.rect(6, 0, 2, 26, GRASS_DARK)
    sw.rect(8, 0, 2, 24, GRASS_HILITE)
    # Borde sur llegando desde la derecha hasta x=10
    sw.rect(10, 24, 22, 3, GRASS_HILITE)
    sw.rect(8, 27, 24, 3, GRASS_DARK)
    sw.rect(6, 30, 26, 2, WALL_OUTLINE)
    # Cierre diagonal sólido de tierra/roca en la esquina inferior izquierda (x=0..10, y=24..31)
    sw.rect(0, 26, 2, 2, WALL_OUTLINE)
    sw.rect(2, 28, 2, 4, WALL_OUTLINE)
    sw.rect(4, 26, 4, 6, WALL_MID)
    sw.rect(4, 27, 2, 3, WALL_LIGHT)
    sw.rect(6, 29, 2, 3, WALL_OUTLINE)
    sw.save_png(f"{ROOT}/terrain/grass_corners/corner_outer_sw.png")
    sprites["corner_outer_sw"] = sw

    # 4. Esquina exterior INFERIOR DERECHA (SE) — PIEZA CRÍTICA SIN HUECOS
    se = sw.flip_x()
    se.save_png(f"{ROOT}/terrain/grass_corners/corner_outer_se.png")
    sprites["corner_outer_se"] = se

    # 5-8. Esquinas INTERIORES (cóncavas, sobre superficie GRASS_BASE continua)
    in_sw = PixelCanvas(32, 32)
    paint_grass_texture(in_sw, 0)
    in_sw.rect(0, 24, 8, 8, WALL_MID)
    in_sw.rect(0, 30, 8, 2, WALL_OUTLINE)
    in_sw.rect(0, 24, 2, 8, WALL_OUTLINE)
    in_sw.rect(6, 24, 2, 8, GRASS_DARK)
    in_sw.rect(8, 24, 2, 8, GRASS_HILITE)
    in_sw.rect(0, 22, 10, 2, GRASS_HILITE)
    in_sw.save_png(f"{ROOT}/terrain/grass_corners/corner_inner_sw.png")
    sprites["corner_inner_sw"] = in_sw

    in_se = in_sw.flip_x()
    in_se.save_png(f"{ROOT}/terrain/grass_corners/corner_inner_se.png")
    sprites["corner_inner_se"] = in_se

    in_nw = PixelCanvas(32, 32)
    paint_grass_texture(in_nw, 0)
    in_nw.rect(0, 0, 8, 8, WALL_SHADOW)
    in_nw.rect(0, 0, 8, 2, WALL_OUTLINE)
    in_nw.rect(0, 0, 2, 8, WALL_OUTLINE)
    in_nw.rect(6, 0, 2, 8, GRASS_DARK)
    in_nw.rect(0, 6, 8, 2, GRASS_DARK)
    in_nw.save_png(f"{ROOT}/terrain/grass_corners/corner_inner_nw.png")
    sprites["corner_inner_nw"] = in_nw

    in_ne = in_nw.flip_x()
    in_ne.save_png(f"{ROOT}/terrain/grass_corners/corner_inner_ne.png")
    sprites["corner_inner_ne"] = in_ne

    return sprites


def make_wall_and_termination_sprites():
    """
    Paredes verticales de tierra/roca (altura completa 22px + sombra 4px sobre transparencia)
    y terminaciones izquierda/derecha que cierran exactamente bajo corner_outer_sw y corner_outer_se.
    """
    sprites = {}

    def draw_wall_body(c, x_start, x_end, y_end=22):
        # Línea superior de enlace con edge_south / corner_outer_sw (sin huecos)
        c.rect(x_start, 0, x_end - x_start, 2, WALL_TOP)
        c.rect(x_start, 2, x_end - x_start, y_end - 4, WALL_MID)
        # Bloques estratificados estilo Zelda ALTTP
        for bx in range(x_start + 2, x_end - 6, 10):
            c.rect(bx, 4, 6, 7, WALL_LIGHT)
            c.rect(bx + 6, 3, 2, 8, WALL_SHADOW)
            c.rect(bx + 3, 12, 6, 6, WALL_LIGHT)
            c.rect(bx + 1, 12, 2, 7, WALL_SHADOW)
        # Base oscura de la pared + sombra proyectada sobre el suelo inferior
        c.rect(x_start, y_end - 2, x_end - x_start, 2, WALL_OUTLINE)
        c.rect(x_start, y_end, x_end - x_start, 4, SHADOW_SOFT)

    # Pared vertical central (tierra/roca)
    w_mid = PixelCanvas(32, 32, TRANSP)
    draw_wall_body(w_mid, 0, 32, 22)
    # Pequeño mechón de césped/musgo en la parte superior
    w_mid.rect(12, 0, 6, 3, GRASS_DARK)
    w_mid.rect(13, 0, 4, 2, GRASS_MID)
    w_mid.save_png(f"{ROOT}/terrain/elevation_walls/wall_center.png")
    sprites["wall_center"] = w_mid

    # Pared de terminación IZQUIERDA (enlaza al píxel con corner_outer_sw en x=2..31)
    w_left = PixelCanvas(32, 32, TRANSP)
    draw_wall_body(w_left, 2, 32, 22)
    # Contorno izquierdo cerrado + curva suave en las 3 últimas filas
    w_left.rect(2, 0, 2, 16, WALL_OUTLINE)
    w_left.rect(2, 16, 2, 6, TRANSP)
    w_left.rect(4, 16, 2, 4, WALL_OUTLINE)
    w_left.rect(4, 20, 2, 2, TRANSP)
    w_left.rect(6, 20, 2, 2, WALL_OUTLINE)
    w_left.rect(2, 22, 4, 4, TRANSP)
    w_left.save_png(f"{ROOT}/terrain/elevation_terminations/wall_end_left.png")
    sprites["wall_end_left"] = w_left

    # Pared de terminación DERECHA (enlaza al píxel con corner_outer_se)
    w_right = w_left.flip_x()
    w_right.save_png(f"{ROOT}/terrain/elevation_terminations/wall_end_right.png")
    sprites["wall_end_right"] = w_right

    # Pared aislada de 1 tile de ancho (ambos extremos cerrados)
    w_both = PixelCanvas(32, 32, TRANSP)
    draw_wall_body(w_both, 2, 30, 22)
    w_both.rect(2, 0, 2, 18, WALL_OUTLINE)
    w_both.rect(28, 0, 2, 18, WALL_OUTLINE)
    w_both.rect(2, 18, 2, 8, TRANSP)
    w_both.rect(28, 18, 2, 8, TRANSP)
    w_both.rect(4, 18, 2, 4, WALL_OUTLINE)
    w_both.rect(26, 18, 2, 4, WALL_OUTLINE)
    w_both.save_png(f"{ROOT}/terrain/elevation_terminations/wall_end_both.png")
    sprites["wall_end_both"] = w_both

    # Rampa de tierra con bordes de piedra/madera
    ramp_v = PixelCanvas(32, 32)
    ramp_v.rect(0, 0, 32, 32, DIRT_BASE)
    for y in [6, 16, 26]:
        ramp_v.rect(2, y, 28, 2, DIRT_DARK)
        ramp_v.rect(2, y + 2, 28, 1, DIRT_LIGHT)
    ramp_v.save_png(f"{ROOT}/terrain/ramps/ramp_vertical.png")
    sprites["ramp_vertical"] = ramp_v

    return sprites


def build_combined_atlas(all_sprites):
    """Empaqueta todos los sprites en un atlas spritesheet organizado (8x3 tiles = 256x96 px) para Godot."""
    order = [
        "grass_center", "grass_sprout", "grass_stones", "grass_flowers",
        "edge_north", "edge_south", "edge_west", "edge_east",
        "corner_outer_nw", "corner_outer_ne", "corner_outer_sw", "corner_outer_se",
        "corner_inner_nw", "corner_inner_ne", "corner_inner_sw", "corner_inner_se",
        "wall_center", "wall_end_left", "wall_end_right", "wall_end_both",
        "ramp_vertical",
    ]
    atlas = PixelCanvas(256, 96, TRANSP)
    for idx, name in enumerate(order):
        col = idx % 8
        row = idx // 8
        atlas.blit(all_sprites[name], col * 32, row * 32)
    atlas.save_png(f"{ROOT}/tilesets/hobbiton_terrain/hobbiton_elevation_atlas.png")
    print(f"Generated {len(all_sprites)} modular sprites + combined 256x96 atlas.")


if __name__ == "__main__":
    all_s = {}
    all_s.update(make_grass_sprites())
    all_s.update(make_edge_sprites())
    all_s.update(make_corner_sprites())
    all_s.update(make_wall_and_termination_sprites())
    build_combined_atlas(all_s)

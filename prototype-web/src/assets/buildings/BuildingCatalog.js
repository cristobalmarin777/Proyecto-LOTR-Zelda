/**
 * BuildingCatalog — Catálogo unificado de viviendas de Hobbiton (La Comarca).
 * Reúne las 3 familias exigidas:
 *  A. Viviendas Hobbit Tradicionales (Smials en colinas con puertas circulares, Referencia A)
 *  B. Viviendas Rurales de La Comarca (Piedra, entramado de madera y techo de paja, Referencia B)
 *  C. Edificios Especiales y Emblemáticos (Bolsón Cerrado, Posada El Dragón Verde, El Viejo Molino,
 *     Árbol de la Fiesta, Pabellón de Cumpleaños).
 *
 * Cada entrada incluye:
 *  - id, name, category, description
 *  - sprite (Canvas pre-renderizado en pixel art 16-bit con transparencia)
 *  - width, height
 *  - collider: rectángulo sólido respecto a la esquina superior izquierda del sprite
 *  - sortYOffset: altura Y desde el borde superior del sprite que actúa como línea de base para Y-sorting
 *    (permite que el jugador camine por detrás del tejado/colina y por delante de la puerta).
 *  - doorOffset: coordenadas relativas de la puerta para interacción con [E].
 */
import { buildHobbitHouseVariant } from './hobbit_houses/HobbitHouseGenerator.js';
import { buildRuralHouseVariant } from './rural_houses/RuralHouseGenerator.js';
import {
  buildBagEndSprite,
  buildGreenDragonInnSprite,
  buildOldMillSprite,
  buildPartyTreeSprite,
  buildPartyTentSprite,
} from './special_buildings/SpecialBuildingsGenerator.js';

export class BuildingCatalog {
  constructor() {
    this.items = {};
    this.buildCatalog();
  }

  buildCatalog() {
    // =========================================================================
    // CATEGORÍA C: EDIFICIOS ESPECIALES Y EMBLEMÁTICOS DE HOBBITON
    // =========================================================================
    this.items.bag_end = {
      id: 'bag_end',
      name: 'Bolsón Cerrado (Bag End)',
      category: 'Especial / Emblemático',
      description:
        'Mansión subterránea de Bilbo y Frodo Bolsón en la cima de La Colina. Puerta verde esmeralda, 4 ventanas circulares, banco exterior y el Gran Roble en la cumbre.',
      sprite: buildBagEndSprite(),
      width: 224,
      height: 160,
      collider: { x: 24, y: 64, w: 176, h: 62 },
      sortYOffset: 126,
      doorOffset: { x: 112, y: 134 },
    };

    this.items.green_dragon_inn = {
      id: 'green_dragon_inn',
      name: 'Posada El Dragón Verde (Green Dragon Inn)',
      category: 'Especial / Emblemático',
      description:
        'Gran posada tradicional en la orilla suroeste del lago El Agua. Estructura de piedra, entramado de roble, tejado de paja en L, chimeneas dobles y barriles de cerveza.',
      sprite: buildGreenDragonInnSprite(),
      width: 220,
      height: 140,
      collider: { x: 22, y: 58, w: 176, h: 52 },
      sortYOffset: 110,
      doorOffset: { x: 81, y: 116 },
    };

    this.items.old_mill = {
      id: 'old_mill',
      name: 'El Viejo Molino de Arenas (Sandyman’s Mill)',
      category: 'Especial / Emblemático',
      description:
        'Molino hidráulico de ladrillo envejecido, piedra y entramado de madera junto al Puente de Doble Arco, con rueda de paletas sobre el río.',
      sprite: buildOldMillSprite(),
      width: 164,
      height: 136,
      collider: { x: 24, y: 52, w: 118, h: 60 },
      sortYOffset: 112,
      doorOffset: { x: 74, y: 118 },
    };

    this.items.party_tree = {
      id: 'party_tree',
      name: 'El Árbol de la Fiesta (The Party Tree)',
      category: 'Especial / Emblemático',
      description:
        'Gran árbol centenario en el centro del valle de Hobbiton, adornado con farolillos para el 111.º cumpleaños de Bilbo.',
      sprite: buildPartyTreeSprite(),
      width: 180,
      height: 160,
      collider: { x: 68, y: 98, w: 44, h: 34 },
      sortYOffset: 130,
      doorOffset: null,
    };

    this.items.party_tent = {
      id: 'party_tent',
      name: 'Pabellón de la Fiesta del Cumpleaños',
      category: 'Especial / Auxiliar',
      description:
        'Carpa festiva con mesas de banquete, pasteles y cerveza en el Campo de la Fiesta.',
      sprite: buildPartyTentSprite(),
      width: 112,
      height: 88,
      collider: { x: 18, y: 44, w: 76, h: 28 },
      sortYOffset: 72,
      doorOffset: { x: 56, y: 78 },
    };

    // =========================================================================
    // CATEGORÍA A: VIVIENDAS HOBBIT TRADICIONALES (REFERENCIA A)
    // =========================================================================
    this.items.smial_sam = {
      id: 'smial_sam',
      name: 'Smial Nº 3 de Bolsón de Tirada (Casa de Sam Gamyi)',
      category: 'Hobbit Tradicional (Ref. A)',
      description:
        'Acogedor agujero hobbit con puerta redonda amarilla/ocre, ventanas circulares en X, escalones de piedra y jardín de flores y calabazas.',
      sprite: buildHobbitHouseVariant({
        width: 136,
        height: 100,
        doorColor: '#d9a426',
        doorDark: '#9e7211',
        windowCount: 2,
        hasChimney: true,
        hasRoofTree: false,
        hasPumpkin: true,
      }),
      width: 136,
      height: 100,
      collider: { x: 18, y: 42, w: 100, h: 42 },
      sortYOffset: 84,
      doorOffset: { x: 68, y: 90 },
    };

    this.items.smial_green_classic = {
      id: 'smial_green_classic',
      name: 'Smial Tradicional de Puerta Verde (Ref. A Exacta)',
      category: 'Hobbit Tradicional (Ref. A)',
      description:
        'Reinterpretación directa de la Referencia A: colina cubierta de musgo, puerta redonda verde bosque, ventanas circulares con celosía, escaleras de losas grises, calabaza y arbustos en flor.',
      sprite: buildHobbitHouseVariant({
        width: 144,
        height: 104,
        doorColor: '#1b632d',
        doorDark: '#10421d',
        windowCount: 2,
        hasChimney: true,
        hasRoofTree: true,
        hasPumpkin: true,
      }),
      width: 144,
      height: 104,
      collider: { x: 18, y: 44, w: 108, h: 44 },
      sortYOffset: 88,
      doorOffset: { x: 72, y: 94 },
    };

    this.items.smial_wealthy_blue = {
      id: 'smial_wealthy_blue',
      name: 'Smial de Hobbit Acomodado (Puerta Azul Real)',
      category: 'Hobbit Tradicional (Ref. A)',
      description:
        'Vivienda amplia en la ladera oriental con puerta circular azul celeste/cobalto, doble ventana circular, chimenea de ladrillo y roble en el techo.',
      sprite: buildHobbitHouseVariant({
        width: 152,
        height: 106,
        doorColor: '#295f98',
        doorDark: '#193e66',
        windowCount: 2,
        hasChimney: true,
        hasRoofTree: true,
        hasPumpkin: false,
      }),
      width: 152,
      height: 106,
      collider: { x: 20, y: 44, w: 112, h: 46 },
      sortYOffset: 90,
      doorOffset: { x: 76, y: 96 },
    };

    this.items.smial_humble_red = {
      id: 'smial_humble_red',
      name: 'Smial Humilde de Ladera (Puerta Carmesí)',
      category: 'Hobbit Tradicional (Ref. A)',
      description:
        'Pequeña vivienda excavada para familias humildes en Bolsón de Tirada, con puerta circular roja/terracota y una sola ventana.',
      sprite: buildHobbitHouseVariant({
        width: 116,
        height: 92,
        doorColor: '#a8322d',
        doorDark: '#731e1b',
        windowCount: 1,
        hasChimney: false,
        hasRoofTree: false,
        hasPumpkin: true,
      }),
      width: 116,
      height: 92,
      collider: { x: 16, y: 38, w: 84, h: 38 },
      sortYOffset: 76,
      doorOffset: { x: 58, y: 82 },
    };

    this.items.smial_oak_brown = {
      id: 'smial_oak_brown',
      name: 'Smial Artesanal de Puerta de Roble',
      category: 'Hobbit Tradicional (Ref. A)',
      description:
        'Casa hobbit tradicional con puerta circular de madera de roble barnizada, chimenea humeante y jardines floridos.',
      sprite: buildHobbitHouseVariant({
        width: 132,
        height: 98,
        doorColor: '#8c5322',
        doorDark: '#5e3513',
        windowCount: 2,
        hasChimney: true,
        hasRoofTree: false,
        hasPumpkin: false,
      }),
      width: 132,
      height: 98,
      collider: { x: 18, y: 40, w: 96, h: 42 },
      sortYOffset: 82,
      doorOffset: { x: 66, y: 88 },
    };

    // =========================================================================
    // CATEGORÍA B: VIVIENDAS RURALES DE LA COMARCA (REFERENCIA B)
    // =========================================================================
    this.items.rural_l_house = {
      id: 'rural_l_house',
      name: 'Granja Rural en L con Tejado de Paja (Ref. B Exacta)',
      category: 'Casa Rural (Ref. B)',
      description:
        'Reinterpretación directa de la Referencia B: tejado de paja dorada en L con caballete trenzado en espiga, chimenea de piedra gris, entramado de madera, ventanas azules y escalera apoyada.',
      sprite: buildRuralHouseVariant({
        style: 'l_shape',
        width: 148,
        height: 118,
        hasLadder: true,
        hasChimney: true,
      }),
      width: 148,
      height: 118,
      collider: { x: 18, y: 52, w: 112, h: 48 },
      sortYOffset: 100,
      doorOffset: { x: 49, y: 106 },
    };

    this.items.rural_cottage = {
      id: 'rural_cottage',
      name: 'Cabaña Rural de Entramado y Paja',
      category: 'Casa Rural (Ref. B)',
      description:
        'Vivienda campesina de piedra y madera con techo de paja inclinado, chimenea de mampostería y puerta arqueada de roble.',
      sprite: buildRuralHouseVariant({
        style: 'cottage',
        width: 116,
        height: 98,
        hasLadder: false,
        hasChimney: true,
      }),
      width: 116,
      height: 98,
      collider: { x: 16, y: 46, w: 84, h: 38 },
      sortYOffset: 84,
      doorOffset: { x: 58, y: 90 },
    };

    this.items.rural_stone_barn = {
      id: 'rural_stone_barn',
      name: 'Granero Auxiliar de Piedra y Paja',
      category: 'Casa Rural / Auxiliar (Ref. B)',
      description:
        'Construcción auxiliar de mampostería de piedra y techo de paja para almacenar grano, herramientas de jardín y cosechas.',
      sprite: buildRuralHouseVariant({
        style: 'barn',
        width: 104,
        height: 86,
        hasLadder: false,
        hasChimney: false,
      }),
      width: 104,
      height: 86,
      collider: { x: 14, y: 38, w: 76, h: 34 },
      sortYOffset: 72,
      doorOffset: { x: 52, y: 78 },
    };
  }

  get(id) {
    return this.items[id];
  }

  getAllList() {
    return Object.values(this.items);
  }
}

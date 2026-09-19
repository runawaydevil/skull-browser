#!/usr/bin/env node
// Skull Browser -- gerador dos icones.
//
// Desenha tudo a partir de grades de pixel 16x16, escritas como arte ASCII
// logo abaixo. Emite PNG RGBA sem antialiasing (controle exato de pixel, que
// e o que faz um icone de 16px continuar legivel) e o SVG do aplicativo.
//
// Uso:  node build-utils/gen-icons.js
//
// Saida:
//   resources/icons/tab-icon-<nome>.png      16x16
//   resources/icons/tab-icon-<nome>@2x.png   32x32
//   extras/skull-browser.png                 64x64  (icone do aplicativo)
//   extras/skull-browser.svg                 vetor do icone do aplicativo

'use strict';

const zlib = require('zlib');
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');

// ---------------------------------------------------------------- paleta ---

const PALETTE = {
    '.': [0x00, 0x00, 0x00, 0x00], // transparente
    g: [0x3d, 0xf0, 0x7a, 0xff],   // fosforo -- a marca
    b: [0xd8, 0xd2, 0xc4, 0xff],   // osso    -- pagina comum
    v: [0xa7, 0x8b, 0xfa, 0xff],   // violeta -- navegacao privada
    r: [0xe5, 0x48, 0x4d, 0xff],   // vermelho-- erro / crash
    a: [0xf5, 0xa5, 0x24, 0xff],   // ambar   -- erro de seguranca
    d: [0x05, 0x0b, 0x07, 0xff],   // fundo escuro do badge
};

// ------------------------------------------------------------- as grades ---
// '#' = cor principal do icone, '.' = transparente.
// Todas simetricas em torno de x=7.5.

const SKULL = [
    '................',
    '....########....',
    '..############..',
    '.##############.',
    '################',
    '##...######...##',
    '##...######...##',
    '################',
    '#######..#######',
    '################',
    '.##############.',
    '..############..',
    '...##########...',
    '....########....',
    '....#.#..#.#....',
    '................',
];

// Crânio com olhos em X -- aba que travou.
const SKULL_DEAD = [
    '................',
    '....########....',
    '..############..',
    '.##############.',
    '################',
    '##.#.######.#.##',
    '##..#.####.#..##',
    '###.#.####.#.###',
    '#######..#######',
    '################',
    '.##############.',
    '..############..',
    '...##########...',
    '....########....',
    '....#.#..#.#....',
    '................',
];

// Documento -- pagina web comum.
const PAGE = [
    '................',
    '................',
    '...##########...',
    '...#........#...',
    '...#.######.#...',
    '...#........#...',
    '...#.######.#...',
    '...#........#...',
    '...#.######.#...',
    '...#........#...',
    '...#.####...#...',
    '...#........#...',
    '...##########...',
    '................',
    '................',
    '................',
];

// Triangulo de alerta -- falha de carregamento.
const ALERT = [
    '................',
    '................',
    '.......##.......',
    '......####......',
    '......####......',
    '.....##..##.....',
    '.....##.#.##....',
    '....##..#..##...',
    '....##..#..##...',
    '...##...#...##..',
    '...##.......##..',
    '..##....#....##.',
    '..#############.',
    '..#############.',
    '................',
    '................',
];

// Cadeado aberto -- erro de certificado.
const LOCK_OPEN = [
    '................',
    '................',
    '.....#####......',
    '....##...##.....',
    '....##...##.....',
    '....##...##.....',
    '....##..........',
    '..###########...',
    '..###########...',
    '..####...####...',
    '..####...####...',
    '..#####.#####...',
    '..###########...',
    '..###########...',
    '................',
    '................',
];

const ICONS = [
    { name: 'tab-icon-chrome', grid: SKULL, color: 'g' },
    { name: 'tab-icon-page', grid: PAGE, color: 'b' },
    { name: 'tab-icon-private', grid: SKULL, color: 'v' },
    { name: 'tab-icon-crash', grid: SKULL_DEAD, color: 'r' },
    { name: 'tab-icon-error', grid: ALERT, color: 'r' },
    { name: 'tab-icon-security-error', grid: LOCK_OPEN, color: 'a' },
];

// ------------------------------------------------------- encoder de PNG ---

const CRC_TABLE = (() => {
    const t = new Int32Array(256);
    for (let n = 0; n < 256; n++) {
        let c = n;
        for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
        t[n] = c;
    }
    return t;
})();

function crc32(buf) {
    let c = -1;
    for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
    return (c ^ -1) >>> 0;
}

function chunk(type, data) {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(body));
    return Buffer.concat([len, body, crc]);
}

/** pixels: Buffer RGBA de w*h*4 */
function encodePng(w, h, pixels) {
    const ihdr = Buffer.alloc(13);
    ihdr.writeUInt32BE(w, 0);
    ihdr.writeUInt32BE(h, 4);
    ihdr[8] = 8;  // bit depth
    ihdr[9] = 6;  // color type RGBA
    ihdr[10] = 0; // deflate
    ihdr[11] = 0; // filtro adaptativo
    ihdr[12] = 0; // sem entrelacamento

    // Uma linha = 1 byte de filtro (0 = None) + w*4 bytes.
    const raw = Buffer.alloc(h * (1 + w * 4));
    for (let y = 0; y < h; y++) {
        raw[y * (1 + w * 4)] = 0;
        pixels.copy(raw, y * (1 + w * 4) + 1, y * w * 4, (y + 1) * w * 4);
    }

    return Buffer.concat([
        Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        chunk('IHDR', ihdr),
        chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
        chunk('IEND', Buffer.alloc(0)),
    ]);
}

// ------------------------------------------------------------ rasterizer ---

/** Desenha uma grade 16x16 ampliada por `scale`, sem suavizacao. */
function renderGrid(grid, colorKey, scale, pad, bg) {
    const cells = grid.length;              // 16
    const size = cells * scale + pad * 2;
    const px = Buffer.alloc(size * size * 4);

    const put = (x, y, rgba) => {
        const o = (y * size + x) * 4;
        px[o] = rgba[0]; px[o + 1] = rgba[1]; px[o + 2] = rgba[2]; px[o + 3] = rgba[3];
    };

    if (bg) {
        // Badge com cantos arredondados, raio proporcional.
        const r = Math.round(size * 0.22);
        for (let y = 0; y < size; y++) {
            for (let x = 0; x < size; x++) {
                const dx = x < r ? r - x : x >= size - r ? x - (size - r - 1) : 0;
                const dy = y < r ? r - y : y >= size - r ? y - (size - r - 1) : 0;
                if (dx * dx + dy * dy <= r * r) put(x, y, PALETTE[bg]);
            }
        }
    }

    const fg = PALETTE[colorKey];
    for (let gy = 0; gy < cells; gy++) {
        for (let gx = 0; gx < grid[gy].length; gx++) {
            if (grid[gy][gx] !== '#') continue;
            for (let y = 0; y < scale; y++) {
                for (let x = 0; x < scale; x++) {
                    put(pad + gx * scale + x, pad + gy * scale + y, fg);
                }
            }
        }
    }
    return { size, px };
}

// ------------------------------------------------------------------- SVG ---

/** Emite retangulos por corridas horizontais -- SVG minusculo. */
function gridToSvgRects(grid, fill, scale, offset) {
    const out = [];
    grid.forEach((row, y) => {
        let x = 0;
        while (x < row.length) {
            if (row[x] !== '#') { x++; continue; }
            let run = 0;
            while (x + run < row.length && row[x + run] === '#') run++;
            out.push(`<rect x="${offset + x * scale}" y="${offset + y * scale}" `
                + `width="${run * scale}" height="${scale}" fill="${fill}"/>`);
            x += run;
        }
    });
    return out.join('');
}

function buildAppSvg() {
    // viewBox 64: grade 16 * escala 3 = 48, centrada com 8 de margem.
    const rects = gridToSvgRects(SKULL, '#3DF07A', 3, 8);
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">`
        + `<title>Skull Browser</title>`
        + `<rect width="64" height="64" rx="14" fill="#050B07"/>`
        + rects
        + `</svg>\n`;
}

// ------------------------------------------------------------------ main ---

function write(rel, buf) {
    const full = path.join(ROOT, rel);
    fs.mkdirSync(path.dirname(full), { recursive: true });
    fs.writeFileSync(full, buf);
    console.log(`  ${rel}  (${buf.length} bytes)`);
}

console.log('icones de aba:');
for (const { name, grid, color } of ICONS) {
    for (const [suffix, scale] of [['', 1], ['@2x', 2]]) {
        const { size, px } = renderGrid(grid, color, scale, 0, null);
        write(`resources/icons/${name}${suffix}.png`, encodePng(size, size, px));
    }
}

console.log('icone do aplicativo:');
{
    const { size, px } = renderGrid(SKULL, 'g', 3, 8, 'd');
    write('extras/skull-browser.png', encodePng(size, size, px));
    write('extras/skull-browser.svg', Buffer.from(buildAppSvg(), 'utf8'));
}

console.log('\npronto.');

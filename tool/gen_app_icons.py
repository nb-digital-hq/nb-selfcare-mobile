#!/usr/bin/env python3
"""Genera TODOS los íconos de NB SelfCare a partir de un único SVG.

Fuente de verdad: `assets/images/logo.svg` (un círculo de fondo + la figura).
Los colores de cada ícono salen del acento de cada tema de
`lib/shared/theme/sc_theme.dart`, así que un tema nuevo tiene su ícono al
volver a ejecutar:

    python3 tool/gen_app_icons.py

Salidas (todas se regeneran; no editar a mano):
  - Android, figura del ícono adaptativo en clara y oscura
    (`drawable-*/ic_launcher_foreground[_dark].png`), usada también como ícono
    monocromo (íconos temáticos de Android 13+).
  - Android, ícono por defecto: `mipmap-anydpi-v26/ic_launcher.xml` (adaptativo)
    y `mipmap-*/ic_launcher.png` (circular, para lanzadores antiguos).
  - Android, un ícono adaptativo por tema: `mipmap-anydpi-v26/ic_app_<tema>.xml`
    con el color `ic_app_<tema>_bg` de `values/ic_app_colors.xml`.
  - Selector "Ícono de la app": `assets/app_icons/logo_default.png` y
    `logo_<tema>.png` (el mismo logo con el fondo del color del tema).
  - Los `<activity-alias>` del AndroidManifest (uno por tema + el por defecto),
    que es lo que conmuta el ícono del lanzador en runtime.

Requiere `rsvg-convert` (librsvg) y Pillow.
"""
import io
import os
import re
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SVG = os.path.join(ROOT, 'assets/images/logo.svg')
THEMES = os.path.join(ROOT, 'lib/shared/theme/sc_theme.dart')
RES = os.path.join(ROOT, 'android/app/src/main/res')
MANIFEST = os.path.join(ROOT, 'android/app/src/main/AndroidManifest.xml')
ASSETS = os.path.join(ROOT, 'assets/app_icons')
PKG = 'com.nb.selfcare'

DENSIDADES = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0,
              'xxxhdpi': 4.0}

# Figura sobre fondos claros (acentos muy luminosos, p. ej. "Papel oscuro").
FIGURA_OSCURA = '#15171C'

CIRCLE_RE = re.compile(r'<circle\b[^>]*/>')
FILL_RE = re.compile(r'fill="(#[0-9A-Fa-f]{6})"')
THEME_RE = re.compile(r"_def\(\s*'([a-z0-9_]+)',.*?\baccent:\s*0x[0-9A-Fa-f]{2}([0-9A-Fa-f]{6})",
                      re.S)


def luminancia(hex_color):
    """Luminancia relativa WCAG de #RRGGBB."""
    def canal(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
    return 0.2126 * canal(r) + 0.7152 * canal(g) + 0.0722 * canal(b)


def leer_svg():
    with open(SVG, encoding='utf-8') as fh:
        svg = fh.read()
    circulo = CIRCLE_RE.search(svg)
    assert circulo, 'el SVG debe tener un <circle> de fondo'
    fondo = FILL_RE.search(circulo.group(0)).group(1)
    radio = float(re.search(r'\br="([\d.]+)"', circulo.group(0)).group(1))
    lado = float(re.search(r'viewBox="0 0 ([\d.]+)', svg).group(1))
    figura_color = [c for c in FILL_RE.findall(svg) if c != fondo][0]
    return svg, circulo.group(0), fondo, radio, lado, figura_color


def leer_temas():
    with open(THEMES, encoding='utf-8') as fh:
        dart = fh.read()
    temas = {k: '#' + v.upper() for k, v in THEME_RE.findall(dart)}
    assert temas, 'no se encontraron temas en sc_theme.dart'
    return temas


def render(svg, px):
    """Rasteriza [svg] (texto) a un PIL.Image RGBA de px×px."""
    out = subprocess.run(
        ['rsvg-convert', '-w', str(px), '-h', str(px), '-f', 'png'],
        input=svg.encode('utf-8'), stdout=subprocess.PIPE, check=True).stdout
    return Image.open(io.BytesIO(out)).convert('RGBA')


def guardar(img, *ruta):
    destino = os.path.join(*ruta)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    img.save(destino, optimize=True)


def escribir(texto, *ruta):
    destino = os.path.join(*ruta)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    with open(destino, 'w', encoding='utf-8') as fh:
        fh.write(texto)


def limpiar(carpeta, patron):
    if not os.path.isdir(carpeta):
        return
    for f in os.listdir(carpeta):
        if re.fullmatch(patron, f):
            os.remove(os.path.join(carpeta, f))


def adaptativo(color_ref, figura):
    return ('<?xml version="1.0" encoding="utf-8"?>\n'
            '<!-- Generado por tool/gen_app_icons.py; no editar a mano. -->\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            f'    <background android:drawable="{color_ref}"/>\n'
            f'    <foreground android:drawable="@drawable/{figura}"/>\n'
            '    <monochrome android:drawable="@drawable/ic_launcher_foreground"/>\n'
            '</adaptive-icon>\n')


def alias(name, icon, enabled):
    return (
        f'        <activity-alias\n'
        f'            android:name="{PKG}.{name}"\n'
        f'            android:enabled="{"true" if enabled else "false"}"\n'
        f'            android:exported="true"\n'
        f'            android:targetActivity=".MainActivity"\n'
        f'            android:icon="{icon}"\n'
        f'            android:roundIcon="{icon}">\n'
        f'            <intent-filter>\n'
        f'                <action android:name="android.intent.action.MAIN"/>\n'
        f'                <category android:name="android.intent.category.LAUNCHER"/>\n'
        f'            </intent-filter>\n'
        f'        </activity-alias>'
    )


def actualizar_manifest(claves):
    with open(MANIFEST, encoding='utf-8') as fh:
        xml = fh.read()
    lineas = ['        <!-- AppIconStart -->',
              '        <!-- Generado por tool/gen_app_icons.py; no editar a mano. -->',
              alias('AppIconDefault', '@mipmap/ic_launcher', True)]
    lineas += [alias(f'AppIcon_{k}', f'@mipmap/ic_app_{k}', False)
               for k in claves]
    lineas.append('        <!-- AppIconEnd -->')
    bloque = '\n'.join(lineas) + '\n'
    patron = re.compile(
        r'[ \t]*<!-- AppIconStart -->.*?<!-- AppIconEnd -->\n', re.S)
    assert patron.search(xml), 'faltan los marcadores AppIconStart/AppIconEnd'
    xml = patron.sub(lambda _: bloque, xml)
    with open(MANIFEST, 'w', encoding='utf-8') as fh:
        fh.write(xml)


def main():
    svg, circulo, fondo, radio, lado, figura_color = leer_svg()
    temas = leer_temas()
    claves = sorted(temas)

    def con_figura(color):
        return svg.replace(f'fill="{figura_color}"', f'fill="{color}"')

    def tematizado(color):
        claro = luminancia(color) > 0.45
        base = con_figura(FIGURA_OSCURA) if claro else svg
        return base.replace(circulo, circulo.replace(fondo, color)), claro

    # ── Figura del ícono adaptativo (clara y oscura) ──────────────────────
    # El lienzo adaptativo mide 108dp y la zona segura 66dp: el círculo del
    # SVG se ajusta a la máscara visible (72dp) y la figura queda completa.
    escala = 72.0 / 108.0 * (lado / (2 * radio))
    for nombre, color in (('ic_launcher_foreground', figura_color),
                          ('ic_launcher_foreground_dark', FIGURA_OSCURA)):
        figura = con_figura(color).replace(circulo, '')
        for dens, k in DENSIDADES.items():
            lienzo = round(108 * k)
            tam = round(lienzo * escala)
            img = Image.new('RGBA', (lienzo, lienzo), (0, 0, 0, 0))
            img.alpha_composite(render(figura, tam),
                                ((lienzo - tam) // 2, (lienzo - tam) // 2))
            guardar(img, RES, f'drawable-{dens}', f'{nombre}.png')

    # ── Ícono por defecto ─────────────────────────────────────────────────
    for dens, k in DENSIDADES.items():
        guardar(render(svg, round(48 * k)), RES, f'mipmap-{dens}', 'ic_launcher.png')
    anydpi = os.path.join(RES, 'mipmap-anydpi-v26')
    limpiar(anydpi, r'ic_(launcher|app_.+)\.xml')
    escribir(adaptativo('@color/ic_launcher_background', 'ic_launcher_foreground'),
             anydpi, 'ic_launcher.xml')

    # ── Íconos por tema ───────────────────────────────────────────────────
    colores = ['<?xml version="1.0" encoding="utf-8"?>',
               '<!-- Generado por tool/gen_app_icons.py; no editar a mano. -->',
               '<resources>',
               f'    <color name="ic_launcher_background">{fondo}</color>']
    limpiar(ASSETS, r'logo_.+\.png')
    guardar(render(svg, 256), ASSETS, 'logo_default.png')
    for clave in claves:
        color = temas[clave]
        svg_tema, claro = tematizado(color)
        colores.append(f'    <color name="ic_app_{clave}_bg">{color}</color>')
        escribir(adaptativo(f'@color/ic_app_{clave}_bg',
                            'ic_launcher_foreground_dark' if claro
                            else 'ic_launcher_foreground'),
                 anydpi, f'ic_app_{clave}.xml')
        guardar(render(svg_tema, 256), ASSETS, f'logo_{clave}.png')
    colores.append('</resources>')
    escribir('\n'.join(colores) + '\n', RES, 'values', 'ic_app_colors.xml')

    # ── iOS: cuadrado opaco, sin alfa (App Store y SpringBoard lo exigen) ──
    ios = os.path.join(ROOT, 'ios/Runner/Assets.xcassets/AppIcon.appiconset')
    if os.path.isdir(ios):
        cuadrado = svg.replace(
            circulo,
            f'<rect width="{lado:g}" height="{lado:g}" fill="{fondo}"/>')
        for f in sorted(os.listdir(ios)):
            if f.endswith('.png'):
                ruta = os.path.join(ios, f)
                with Image.open(ruta) as previo:
                    px = previo.size[0]
                render(cuadrado, px).convert('RGB').save(ruta, optimize=True)

    actualizar_manifest(claves)
    print(f'Íconos generados desde {os.path.relpath(SVG, ROOT)}: '
          f'por defecto + {len(claves)} temas.')


if __name__ == '__main__':
    sys.exit(main())

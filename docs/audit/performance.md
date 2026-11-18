# Rendimiento

> **Estado:** Medido en la versión 1.0.0 sobre un teléfono real con Android 16. iOS no se ha medido.

## Presupuestos

| Medida | Presupuesto | Medido en 1.0.0 |
|---|---|---|
| Arranque en frío (lanzador a primer fotograma) | Menos de 1 s | 0,45 a 0,57 s; 1,2 s solo en el primer arranque tras instalar |
| Memoria en uso (PSS) | Menos de 300 MB | Unos 250 MB con un año de datos |
| APK arm64-v8a | Menos de 40 MB | 31,7 MB |
| APK armeabi-v7a | Menos de 40 MB | 29,3 MB |
| APK x86_64 | Menos de 40 MB | 33,4 MB |
| APK universal (las tres arquitecturas) | Menos de 100 MB | 89,8 MB |

El primer arranque tras instalar es más lento porque Android compila el código y la app crea la base de datos y
siembra el catálogo de alimentos; los siguientes ya no lo hacen.

## Cómo se mide

Con el paquete de publicación instalado (nunca la compilación de desarrollo) y la app cerrada:

```bash
adb shell am force-stop com.nb.selfcare
adb shell am start -W -n com.nb.selfcare/.MainActivity   # TotalTime = arranque en frío
adb shell dumpsys meminfo com.nb.selfcare | grep "TOTAL PSS"
```

Se repite el arranque cinco veces y se anota el intervalo. Los tamaños son los de `just apk`.

## Lo que lo mantiene

* La base de datos se abre en un aislado propio de Drift y las consultas de cada pantalla son reactivas y acotadas
  por fecha, así que el hilo de la interfaz no espera a SQLite.
* La sincronización con Health Connect corre después del primer fotograma y nunca bloquea la navegación.
* Las pruebas de `test/edge_cases/` cargan volúmenes extremos de datos y textos muy largos en cada pantalla.

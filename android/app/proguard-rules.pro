# NB SelfCare — reglas R8 propias.
# Los plugins de Flutter publican sus reglas de consumo en sus AAR; aquí solo va
# lo que la app necesita y no cubren ellos.

# Canales nativos propios (MainActivity y servicios de plataforma).
-keep class com.nb.selfcare.** { *; }

# Google Play Core es referenciado por el embedding de Flutter (deferred components)
# pero la app no lo usa.
-dontwarn com.google.android.play.core.**

# El escáner usa zxing-cpp por FFI (flutter_zxing): el código nativo se resuelve
# por símbolo desde Dart y R8 no lo ve, así que no necesita reglas.

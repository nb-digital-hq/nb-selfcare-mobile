import 'package:flutter/foundation.dart';

/// Funciones que dependen del puente nativo de Android: Health Connect,
/// recordatorios y notificaciones programadas, cronómetro en la pantalla de
/// bloqueo, vibración guiada, ícono por tema y actualizaciones desde GitHub.
/// En iOS esas partes no se muestran, en lugar de ofrecer botones sin efecto.
bool get funcionesAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

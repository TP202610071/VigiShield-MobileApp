package com.vigishield.app

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth necesita una FragmentActivity para mostrar el dialogo
// biometrico del sistema; con FlutterActivity falla en tiempo de ejecucion.
class MainActivity : FlutterFragmentActivity()

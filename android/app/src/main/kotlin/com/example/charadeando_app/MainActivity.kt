package com.example.charadeando_app

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.media.MediaRouter
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var tv: TvConnection? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val connection = TvConnection(this)
        tv = connection
        EventChannel(messenger, "charadeando/tv/conexion").setStreamHandler(connection)
        MethodChannel(messenger, "charadeando/tv").setMethodCallHandler { call, result ->
            when (call.method) {
                "abrirAjustes" -> result.success(openCastSettings())
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        tv?.onCancel(null)
        super.onDestroy()
    }

    // Abre la lista de pantallas para transmitir del sistema.
    private fun openCastSettings(): Boolean {
        for (action in listOf(Settings.ACTION_CAST_SETTINGS, "android.settings.WIFI_DISPLAY_SETTINGS")) {
            try {
                startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (e: ActivityNotFoundException) {
                // Este celular no tiene esa pantalla; se prueba la siguiente.
            } catch (e: SecurityException) {
                // Algunas marcas la bloquean para otras apps.
            }
        }
        return false
    }
}

// Avisa a Flutter si el celular se está viendo en un televisor: una
// pantalla externa (HDMI, Miracast) o una ruta de video en vivo distinta
// del celular (transmitir pantalla a un Chromecast).
private class TvConnection(context: Context) : EventChannel.StreamHandler {
    private val displays = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val router = context.getSystemService(Context.MEDIA_ROUTER_SERVICE) as MediaRouter
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var last: Boolean? = null

    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) = send()
        override fun onDisplayRemoved(displayId: Int) = send()
        override fun onDisplayChanged(displayId: Int) = send()
    }

    private val routerCallback = object : MediaRouter.SimpleCallback() {
        override fun onRouteSelected(router: MediaRouter, type: Int, info: MediaRouter.RouteInfo) = send()
        override fun onRouteUnselected(router: MediaRouter, type: Int, info: MediaRouter.RouteInfo) = send()
        override fun onRouteChanged(router: MediaRouter, info: MediaRouter.RouteInfo) = send()
        override fun onRoutePresentationDisplayChanged(router: MediaRouter, info: MediaRouter.RouteInfo) = send()
    }

    private fun connected(): Boolean {
        if (displays.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION).isNotEmpty()) {
            return true
        }
        val route = router.getSelectedRoute(MediaRouter.ROUTE_TYPE_LIVE_VIDEO)
        return route != router.defaultRoute || route.presentationDisplay != null
    }

    private fun send() {
        val now = connected()
        if (now == last) return
        last = now
        sink?.success(now)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        last = null
        displays.registerDisplayListener(displayListener, main)
        router.addCallback(MediaRouter.ROUTE_TYPE_LIVE_VIDEO, routerCallback)
        send()
    }

    override fun onCancel(arguments: Any?) {
        if (sink == null) return
        displays.unregisterDisplayListener(displayListener)
        router.removeCallback(routerCallback)
        sink = null
    }
}

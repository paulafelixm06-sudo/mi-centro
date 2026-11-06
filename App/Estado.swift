import SwiftUI
import UIKit
import WebKit
import WidgetKit
import EventKit
import UserNotifications
import BackgroundTasks

/// Qué hoja rápida está abierta (nueva tarea, gasto, comida, compra).
enum Hoja: String, Identifiable {
    case nueva, gasto, ingreso, comida, compra
    var id: String { rawValue }

    init?(url: URL) {
        guard url.scheme == "centro" else { return nil }
        self.init(rawValue: url.host ?? "")
    }
}

/// Lo que comparten la app, las notificaciones y los accesos rápidos del icono.
final class Estado: ObservableObject {
    static let shared = Estado()
    @Published var hoja: Hoja?
    @Published var novedades = false
    weak var web: WKWebView?

    static let refresco = "com.paula.centro.refrescar"

    func abrir(atajo: String) {
        DispatchQueue.main.async {
            if let h = Hoja(rawValue: atajo) { self.hoja = h }
        }
    }

    /// Avisa a tu Centro (la web de dentro) de que hay cosas nuevas del iPhone para recoger.
    func refrescarWeb() {
        DispatchQueue.main.async {
            self.web?.evaluateJavaScript("""
            document.querySelectorAll('iframe').forEach(function(f){try{f.contentWindow.postMessage({centro:'refrescar'},'*')}catch(e){}})
            """)
        }
    }

    /// Después de apuntar algo: widgets, número del icono, notificaciones y la web, al día.
    func trasCambio() {
        WidgetCenter.shared.reloadAllTimelines()
        refrescarWeb()
        Task {
            let a = Agenda.cargar()
            await Avisos.ponerNumero(a.hoy.count)
            await Vivo.actualizar(a, crear: false)
        }
    }

    /// Todo lo que hay que tener al día cuando abres o dejas la app.
    func ponerAlDia(crearActividad: Bool) async {
        guard Almacen.shared.permiso else { return }
        Almacen.shared.refrescar()
        await Avisos.reprogramar()
        await Vivo.actualizar(Agenda.cargar(), crear: crearActividad)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func programarRefresco() {
        let r = BGAppRefreshTaskRequest(identifier: Self.refresco)
        r.earliestBeginDate = Date().addingTimeInterval(30 * 60)
        try? BGTaskScheduler.shared.submit(r)
    }
}

/// Se encarga de las notificaciones (botones ✅ ⏰ 📅) y de los accesos rápidos del icono.
final class Delegado: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Avisos.registrarCategorias()
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: Almacen.shared.store, queue: .main) { _ in
            Delegado.cambioCalendario()
        }
        return true
    }

    private static var espera: DispatchWorkItem?
    static func cambioCalendario() {
        espera?.cancel()
        let w = DispatchWorkItem {
            WidgetCenter.shared.reloadAllTimelines()
            Task { await Estado.shared.ponerAlDia(crearActividad: false) }
        }
        espera = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: w)
    }

    func application(_ application: UIApplication, configurationForConnecting sesion: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let atajo = options.shortcutItem { Estado.shared.abrir(atajo: atajo.type) }
        let c = UISceneConfiguration(name: nil, sessionRole: sesion.role)
        c.delegateClass = DelegadoEscena.self
        return c
    }

    // Con la app abierta, las notificaciones también se ven.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive respuesta: UNNotificationResponse) async {
        let ct = respuesta.notification.request.content
        let info = ct.userInfo
        guard let id = info["id"] as? String else { return }
        let tipo = info["tipo"] as? String ?? "t"
        let fecha = info["fecha"] as? String ?? Fechas.clave(Date())
        switch respuesta.actionIdentifier {
        case "hecho":
            try? Almacen.shared.tachar(id: id, tipo: tipo, fecha: fecha)
            let a = Agenda.cargar()
            await Avisos.alTachar(id: id, pendientesHoy: a.hoy.count)
            await Vivo.actualizar(a, crear: false)
            WidgetCenter.shared.reloadAllTimelines()
            Estado.shared.refrescarWeb()
        case "luego":
            await Avisos.otraVez(ct, id: id)
        case "manana":
            let manana = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            try? Almacen.shared.mover(id: id, tipo: tipo, a: manana)
            let a = Agenda.cargar()
            await Avisos.alTachar(id: id, pendientesHoy: a.hoy.count)
            await Vivo.actualizar(a, crear: false)
            WidgetCenter.shared.reloadAllTimelines()
            Estado.shared.refrescarWeb()
        default:
            break
        }
    }
}

final class DelegadoEscena: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        Estado.shared.abrir(atajo: shortcutItem.type)
        completionHandler(true)
    }
}

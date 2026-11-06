import Foundation
import UserNotifications

/// Las notificaciones del iPhone: cuando empieza algo, el «buenos días», el cierre del día
/// y la revisión del viernes. Y el numerito rojo del icono.
enum Avisos {
    static let categoriaCosa = "centro.cosa"
    static let categoriaDia = "centro.dia"
    static var centro: UNUserNotificationCenter { .current() }

    static func pedirPermiso() async {
        _ = try? await centro.requestAuthorization(options: [.alert, .badge, .sound])
    }

    static func registrarCategorias() {
        let hecho = UNNotificationAction(identifier: "hecho", title: "✅ Hecho", options: [])
        let luego = UNNotificationAction(identifier: "luego", title: "⏰ En 15 min", options: [])
        let manana = UNNotificationAction(identifier: "manana", title: "📅 Mañana", options: [])
        centro.setNotificationCategories([
            UNNotificationCategory(identifier: categoriaCosa, actions: [hecho, luego, manana], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: categoriaDia, actions: [], intentIdentifiers: [], options: []),
        ])
    }

    private static func permitido() async -> Bool {
        let s = await centro.notificationSettings()
        return s.authorizationStatus == .authorized || s.authorizationStatus == .provisional
    }

    /// Vuelve a preparar todas las notificaciones con lo último de tu Centro.
    static func reprogramar() async {
        guard Almacen.shared.permiso, await permitido() else { return }
        let c = Almacen.shared.cargar()
        guard c.hay else { return }
        let ahora = Date()
        let cal = Calendar.current

        // fuera las antiguas (menos los «en 15 min» que hayas pedido tú)
        let viejas = await centro.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix("centro.") && !$0.hasPrefix("centro.luego.") }
        centro.removePendingNotificationRequests(withIdentifiers: viejas)

        var nuevas: [UNNotificationRequest] = []

        for d in 0..<3 {
            guard let dia = cal.date(byAdding: .day, value: d, to: ahora) else { continue }
            let f = Fechas.clave(dia)
            let cosas = (c.dias[f] ?? []).filter { !$0.hecho && !c.pendientesIds.contains($0.id) }

            // ☀️ buenos días a las 8:30
            if let h = cal.date(bySettingHour: 8, minute: 30, second: 0, of: dia), h > ahora {
                let ct = UNMutableNotificationContent()
                ct.title = saludo(cal.component(.weekday, from: dia))
                if cosas.isEmpty {
                    ct.body = "Hoy tienes el día libre. Disfrútalo ✨"
                } else {
                    let tres = cosas.sorted { ($0.todoDia ? "99" : $0.ini) < ($1.todoDia ? "99" : $1.ini) }.prefix(3)
                        .map { ($0.todoDia ? "" : $0.ini + " ") + $0.titulo }
                    ct.body = "Tienes \(cosas.count) \(cosas.count == 1 ? "cosa" : "cosas"): " + tres.joined(separator: " · ")
                        + (cosas.count > 3 ? "…" : "") + "\nElige tus 3 importantes y a por ello 💪"
                }
                ct.sound = .default
                ct.categoryIdentifier = categoriaDia
                ct.threadIdentifier = "centro.dia"
                ct.interruptionLevel = .passive
                nuevas.append(peticion("centro.manana.\(f)", ct, h))
            }

            // ⏰ cuando empieza (o cuando pediste el aviso) cada cosa con hora
            for it in cosas where !it.todoDia {
                guard let ini = it.inicio else { continue }
                let antes = it.esTarea ? (it.aviso ?? 0) : 0
                let cuando = ini.addingTimeInterval(TimeInterval(-antes * 60))
                guard cuando > ahora else { continue }
                let ct = UNMutableNotificationContent()
                ct.title = (it.prioridad == "alta" ? "❗️ " : "") + it.titulo
                let fin = it.fin.isEmpty ? "" : "–\(it.fin)"
                ct.body = antes > 0 ? "En \(Fechas.duracion(antes)) · \(it.ini)\(fin)" : "Ahora · \(it.ini)\(fin)"
                if !it.lista.isEmpty { ct.subtitle = it.lista }
                ct.sound = .default
                ct.categoryIdentifier = categoriaCosa
                ct.threadIdentifier = "centro.cosas"
                ct.interruptionLevel = .timeSensitive
                ct.userInfo = ["id": it.id, "tipo": it.tipo, "fecha": it.fecha, "titulo": it.titulo, "ini": it.ini]
                nuevas.append(peticion("centro.t.\(it.id)", ct, cuando))
            }
        }

        // el iPhone deja preparar 64 como mucho: primero las más cercanas
        for r in nuevas.sorted(by: { fechaDe($0) < fechaDe($1) }).prefix(56) {
            try? await centro.add(r)
        }

        // 🌙 cierre del día (cada noche a las 21:00)
        var noche = DateComponents(); noche.hour = 21; noche.minute = 0
        let cn = UNMutableNotificationContent()
        cn.title = "¿Cerramos el día? 🌙"
        cn.body = "Dos minutos: qué salió bien, cómo te sientes y lo de mañana."
        cn.sound = .default
        cn.categoryIdentifier = categoriaDia
        cn.threadIdentifier = "centro.dia"
        try? await centro.add(UNNotificationRequest(identifier: "centro.noche", content: cn,
                                                    trigger: UNCalendarNotificationTrigger(dateMatching: noche, repeats: true)))

        // ✨ revisión del viernes (18:30)
        var vie = DateComponents(); vie.weekday = 6; vie.hour = 18; vie.minute = 30
        let cv = UNMutableNotificationContent()
        cv.title = "Es viernes ✨"
        cv.body = "Mira todo lo que has hecho esta semana y deja lista la que viene."
        cv.sound = .default
        cv.categoryIdentifier = categoriaDia
        cv.threadIdentifier = "centro.dia"
        try? await centro.add(UNNotificationRequest(identifier: "centro.viernes", content: cv,
                                                    trigger: UNCalendarNotificationTrigger(dateMatching: vie, repeats: true)))

        let hoy = Fechas.clave(ahora)
        let quedan = (c.dias[hoy] ?? []).filter { !$0.hecho && !c.pendientesIds.contains($0.id) }.count
        await ponerNumero(quedan)
    }

    /// El numerito rojo del icono = lo que te queda hoy.
    static func ponerNumero(_ n: Int) async {
        try? await centro.setBadgeCount(max(0, n))
    }

    static func alTachar(id: String, pendientesHoy: Int) async {
        centro.removePendingNotificationRequests(withIdentifiers: ["centro.t.\(id)", "centro.luego.\(id)"])
        centro.removeDeliveredNotifications(withIdentifiers: ["centro.t.\(id)", "centro.luego.\(id)"])
        await ponerNumero(pendientesHoy)
    }

    /// «En 15 min»: te lo vuelve a recordar.
    static func otraVez(_ original: UNNotificationContent, id: String, minutos: Int = 15) async {
        let ct = (original.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        ct.body = "Te lo recuerdo otra vez 😊"
        try? await centro.add(peticion("centro.luego.\(id)", ct, Date().addingTimeInterval(TimeInterval(minutos * 60))))
    }

    private static func saludo(_ diaSemana: Int) -> String {
        switch diaSemana {
        case 2: return "Buenos días, Paula ☀️ ¡Empieza la semana!"
        case 6: return "¡Buenos días! Ya es viernes 🎉"
        case 7, 1: return "Buenos días ☀️ Hoy, con calma"
        default: return "Buenos días, Paula ☀️"
        }
    }

    private static func peticion(_ id: String, _ ct: UNNotificationContent, _ cuando: Date) -> UNNotificationRequest {
        let comp = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: cuando)
        return UNNotificationRequest(identifier: id, content: ct,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: comp, repeats: false))
    }

    private static func fechaDe(_ r: UNNotificationRequest) -> Date {
        (r.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
    }
}

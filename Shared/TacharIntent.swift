import AppIntents
import WidgetKit
import UserNotifications

/// Lo que pasa al tocar la casilla del widget.
struct TacharIntent: AppIntent {
    static let title: LocalizedStringResource = "Tachar"
    static let isDiscoverable: Bool = false

    @Parameter(title: "Id") var id: String
    @Parameter(title: "Tipo") var tipo: String
    @Parameter(title: "Fecha") var fecha: String

    init() {}

    init(id: String, tipo: String, fecha: String) {
        self.id = id
        self.tipo = tipo
        self.fecha = fecha
    }

    func perform() async throws -> some IntentResult {
        try Almacen.shared.tachar(id: id, tipo: tipo, fecha: fecha)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["centro.t.\(id)"])
        let a = Agenda.cargar()
        try? await UNUserNotificationCenter.current().setBadgeCount(a.hoy.count)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Lo que pasa al tocar un hábito del widget.
struct HabitoIntent: AppIntent {
    static let title: LocalizedStringResource = "Marcar hábito"
    static let isDiscoverable: Bool = false

    @Parameter(title: "Id") var id: String
    @Parameter(title: "Hecho") var hecho: Bool

    init() {}
    init(id: String, hecho: Bool) { self.id = id; self.hecho = hecho }

    func perform() async throws -> some IntentResult {
        try Almacen.shared.alternarHabito(id: id, ahora: hecho)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Tachar algo de la lista de la compra desde el widget.
struct CompraIntent: AppIntent {
    static let title: LocalizedStringResource = "Comprado"
    static let isDiscoverable: Bool = false

    @Parameter(title: "Id") var id: String

    init() {}
    init(id: String) { self.id = id }

    func perform() async throws -> some IntentResult {
        try Almacen.shared.alternarCompra(id: id)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

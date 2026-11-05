import AppIntents
import WidgetKit

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
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

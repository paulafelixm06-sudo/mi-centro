import ActivityKit
import AppIntents
import Foundation
import WidgetKit

/// «Lo siguiente» en la pantalla de bloqueo y en la isla de arriba.
struct SiguienteAtributos: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var titulo: String
        var lista: String
        var colorHex: String
        var inicio: Date
        var fin: Date
        var id: String
        var tipo: String
        var fecha: String
        var empezada: Bool
        var despues: String     // lo que viene luego (para que no te pille por sorpresa)
    }
}

enum Vivo {
    /// Pone (o quita) «Lo siguiente» en la pantalla de bloqueo.
    /// Sale cuando falta menos de 2 horas para lo próximo con hora, y se va cuando termina.
    static func actualizar(_ a: Agenda, crear: Bool = true) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let actuales = Activity<SiguienteAtributos>.activities
        guard let s = a.siguiente, let ini = s.inicio, let fin = s.final,
              ini.timeIntervalSinceNow < 2 * 3600 else {
            for x in actuales { await x.end(nil, dismissalPolicy: .immediate) }
            return
        }
        let empezada = ini <= Date()
        let luego = a.hoy.first { !$0.todoDia && $0.id != s.id && Fechas.minutos($0.ini) >= Fechas.minutos(s.ini) }
        let estado = SiguienteAtributos.ContentState(
            titulo: s.titulo, lista: s.lista, colorHex: s.colorHex.isEmpty ? "#c9748a" : s.colorHex,
            inicio: ini, fin: fin, id: s.id, tipo: s.tipo, fecha: s.fecha, empezada: empezada,
            despues: luego.map { "\($0.ini) · \($0.titulo)" } ?? "")
        let contenido = ActivityContent(state: estado, staleDate: empezada ? fin : ini, relevanceScore: 100)
        if let x = actuales.first(where: { $0.content.state.id == s.id }) {
            await x.update(contenido)
            for o in actuales where o.id != x.id { await o.end(nil, dismissalPolicy: .immediate) }
        } else {
            for o in actuales { await o.end(nil, dismissalPolicy: .immediate) }
            if crear {
                _ = try? Activity.request(attributes: SiguienteAtributos(), content: contenido, pushType: nil)
            }
        }
    }

    static func quitar(id: String) async {
        for x in Activity<SiguienteAtributos>.activities where x.content.state.id == id {
            await x.end(nil, dismissalPolicy: .immediate)
        }
    }
}

/// El botón «Hecho» de la pantalla de bloqueo / isla.
struct HechoActividadIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Hecho"
    static let isDiscoverable: Bool = false

    @Parameter(title: "Id") var id: String
    @Parameter(title: "Tipo") var tipo: String
    @Parameter(title: "Fecha") var fecha: String

    init() {}
    init(id: String, tipo: String, fecha: String) {
        self.id = id; self.tipo = tipo; self.fecha = fecha
    }

    func perform() async throws -> some IntentResult {
        try Almacen.shared.tachar(id: id, tipo: tipo, fecha: fecha)
        await Vivo.quitar(id: id)
        let a = Agenda.cargar()
        await Vivo.actualizar(a)
        await Avisos.alTachar(id: id, pendientesHoy: a.hoy.count)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

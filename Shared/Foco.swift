import ActivityKit
import Foundation

/// El temporizador de foco (pomodoro) del Centro, en la isla y en la pantalla de bloqueo.
struct FocoAtributos: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var titulo: String
        var fase: String        // "foco" o "descanso"
        var fin: Date
        var minutos: Int
        var enPausa: Bool
        var quedanSeg: Int      // si está en pausa, lo que quedaba
    }
}

enum VivoFoco {
    /// `d` llega de tu Centro: {fase, fin (ms), resto (ms), tit, min}
    static func actualizar(_ d: [String: Any]) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let fase = d["fase"] as? String ?? ""
        let actuales = Activity<FocoAtributos>.activities
        guard !fase.isEmpty else {
            for a in actuales { await a.end(nil, dismissalPolicy: .immediate) }
            return
        }
        let finMs = (d["fin"] as? NSNumber)?.doubleValue ?? 0
        let restoMs = (d["resto"] as? NSNumber)?.doubleValue ?? 0
        let estado = FocoAtributos.ContentState(
            titulo: d["tit"] as? String ?? "",
            fase: fase,
            fin: Date(timeIntervalSince1970: finMs / 1000),
            minutos: (d["min"] as? NSNumber)?.intValue ?? 25,
            enPausa: restoMs > 0,
            quedanSeg: Int(restoMs / 1000))
        let contenido = ActivityContent(state: estado, staleDate: estado.enPausa ? nil : estado.fin)
        if let a = actuales.first {
            await a.update(contenido)
        } else {
            #if APP
            _ = try? Activity.request(attributes: FocoAtributos(), content: contenido, pushType: nil)
            #endif
        }
    }
}

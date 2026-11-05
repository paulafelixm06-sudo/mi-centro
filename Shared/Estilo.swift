import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        let v = UInt64(s, radix: 16) ?? 0xC9748A
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }

    static func tema(_ claro: String, _ oscuro: String) -> Color {
        let c = UIColor(Color(hex: claro)), o = UIColor(Color(hex: oscuro))
        return Color(UIColor { $0.userInterfaceStyle == .dark ? o : c })
    }

    static let rosa = Color(hex: "#c9748a")
    static let fondo = Color.tema("#fbf4f3", "#1c1417")
    static let papel = Color.tema("#ffffff", "#2a1d22")
    static let tinta = Color.tema("#3d2730", "#f6e8ec")
    static let gris = Color.tema("#9c8189", "#b09aa2")
    static let linea = Color.tema("#f0e2e5", "#3e2d34")
    static let tarjeta = Color.tema("#3d2730", "#33242b")
}

/// Texto de debajo de cada cosa: hora y lista.
func subtitulo(_ it: Item) -> String {
    var p: [String] = []
    if !it.todoDia {
        let a = Fechas.minutos(it.ini), b = Fechas.minutos(it.fin.isEmpty ? it.ini : it.fin)
        p.append(it.ini + (b > a ? " · " + Fechas.duracion(b - a) : ""))
    }
    if !it.lista.isEmpty { p.append(it.lista) }
    return p.joined(separator: " · ")
}

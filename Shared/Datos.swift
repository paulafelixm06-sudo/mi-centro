import Foundation
import EventKit

// Una cosa de tu día: una tarea del Centro ("t") o una cita del calendario ("e").
struct Item: Identifiable, Hashable {
    let id: String
    let tipo: String
    let fecha: String      // "yyyy-MM-dd"
    let ini: String        // "HH:mm" o "" (todo el día)
    let fin: String
    let titulo: String
    let colorHex: String
    let lista: String
    let hecho: Bool

    var todoDia: Bool { ini.isEmpty }
    var esTarea: Bool { tipo == "t" }
}

enum Fechas {
    static func clave(_ d: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
    static func minutos(_ hhmm: String) -> Int {
        let p = hhmm.split(separator: ":").compactMap { Int($0) }
        return p.count == 2 ? p[0] * 60 + p[1] : 0
    }
    static func ahoraMin() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    static func duracion(_ m: Int) -> String {
        if m < 60 { return "\(max(5, m)) min" }
        let h = m / 60, r = m % 60
        return r > 0 ? "\(h) h \(r)" : "\(h) h"
    }
    static func titulo(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "EEEE d"
        let s = f.string(from: d)
        return s.prefix(1).uppercased() + s.dropFirst()
    }
}

/// Lee y escribe en tu calendario del iPhone.
/// - El Centro deja una copia de tus próximos días en un evento escondido (1 ene 2030, «datos del widget»).
/// - Lo que tachas aquí se apunta en otro evento escondido (2 ene 2030, «tachados desde el iPhone»)
///   y tu Centro lo marca de verdad en cuanto lo abres.
final class Almacen {
    static let shared = Almacen()
    let store = EKEventStore()

    static let textoDatos = "datos del widget"
    static let textoTachados = "tachados desde el iphone"
    static let tituloTachados = "📱 Centro · tachados desde el iPhone (no borrar)"

    var permiso: Bool {
        let s = EKEventStore.authorizationStatus(for: .event)
        return s == .fullAccess
    }

    func pedirPermiso() async -> Bool {
        do { return try await store.requestFullAccessToEvents() } catch { return false }
    }

    private func dia2030(_ dia: Int) -> Date {
        var c = DateComponents()
        c.year = 2030; c.month = 1; c.day = dia; c.hour = 12
        return Calendar.current.date(from: c) ?? Date()
    }

    private func evento(_ texto: String, dia: Int) -> EKEvent? {
        let d = dia2030(dia)
        let pred = store.predicateForEvents(withStart: d.addingTimeInterval(-2 * 86400),
                                            end: d.addingTimeInterval(2 * 86400),
                                            calendars: nil)
        return store.events(matching: pred).first { ($0.title ?? "").lowercased().contains(texto) }
    }

    private func json(_ txt: String?) -> [String: Any]? {
        guard let t = txt, let a = t.firstIndex(of: "{"), let b = t.lastIndex(of: "}"), a < b else { return nil }
        let trozo = String(t[a...b])
        guard let data = trozo.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private func numero(_ v: Any?) -> Int {
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String { return Int(s) ?? 0 }
        return 0
    }

    /// Ids que ya tachaste en el iPhone y que el Centro todavía no ha recogido.
    func tachadosPendientes() -> [[String: Any]] {
        guard let ev = evento(Self.textoTachados, dia: 2),
              let o = json(ev.notes),
              let xs = o["x"] as? [[String: Any]] else { return [] }
        return xs
    }

    /// Todos los días que dejó el Centro. `hay` = false si aún no hay copia.
    func cargar() -> (dias: [String: [Item]], hay: Bool, tachados: Set<String>) {
        let tach = Set(tachadosPendientes().compactMap { $0["id"] as? String })
        guard let ev = evento(Self.textoDatos, dia: 1),
              let o = json(ev.notes),
              let d = o["d"] as? [String: Any] else { return ([:], false, tach) }
        var out: [String: [Item]] = [:]
        for (f, valor) in d {
            guard let filas = valor as? [[Any]] else { continue }
            var items: [Item] = []
            for r in filas {
                func s(_ i: Int) -> String { i < r.count ? (r[i] as? String ?? "") : "" }
                let idOriginal = s(7)
                let id = idOriginal.isEmpty ? "\(f)|\(s(2))|\(s(0))" : idOriginal
                let hecho = (r.count > 5 ? numero(r[5]) : 0) == 1 || tach.contains(id)
                items.append(Item(id: id, tipo: s(6), fecha: f, ini: s(0), fin: s(1), titulo: s(2),
                                  colorHex: s(3), lista: s(4), hecho: hecho))
            }
            out[f] = items
        }
        return (out, true, tach)
    }

    /// Apunta que has tachado algo. Tu Centro lo marcará de verdad al abrirlo.
    func tachar(id: String, tipo: String, fecha: String) throws {
        let ev: EKEvent
        if let e = evento(Self.textoTachados, dia: 2) {
            ev = e
        } else {
            guard let datos = evento(Self.textoDatos, dia: 1) else {
                throw NSError(domain: "Centro", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Abre tu Centro una vez para que lleguen tus tareas."])
            }
            ev = EKEvent(eventStore: store)
            ev.calendar = datos.calendar
            ev.title = Self.tituloTachados
            let d = Calendar.current.startOfDay(for: dia2030(2))
            ev.startDate = d
            ev.endDate = d
            ev.isAllDay = true
            ev.availability = .free
        }
        var xs = (json(ev.notes)?["x"] as? [[String: Any]]) ?? []
        if !xs.contains(where: { ($0["id"] as? String) == id }) {
            xs.append(["id": id, "t": tipo, "f": fecha, "at": ISO8601DateFormatter().string(from: Date())])
        }
        try guardar(ev, xs)
    }

    /// Deshace un tachado que todavía no ha llegado al Centro.
    func destachar(id: String) throws {
        guard let ev = evento(Self.textoTachados, dia: 2) else { return }
        let xs = ((json(ev.notes)?["x"] as? [[String: Any]]) ?? []).filter { ($0["id"] as? String) != id }
        try guardar(ev, xs)
    }

    private func guardar(_ ev: EKEvent, _ xs: [[String: Any]]) throws {
        let data = try JSONSerialization.data(withJSONObject: ["x": xs])
        ev.notes = String(data: data, encoding: .utf8)
        try store.save(ev, span: .thisEvent, commit: true)
    }
}

/// Tu día ya ordenado, listo para pintar.
struct Agenda {
    var hoy: [Item] = []
    var manana: [Item] = []
    var recien: [Item] = []      // tachadas en el iPhone que aún no ha recogido el Centro
    var hay = false

    static func cargar() -> Agenda {
        let r = Almacen.shared.cargar()
        let ahora = Date()
        let h = Fechas.clave(ahora)
        let m = Fechas.clave(Calendar.current.date(byAdding: .day, value: 1, to: ahora) ?? ahora)
        func orden(_ xs: [Item]) -> [Item] {
            xs.filter { !$0.hecho }.sorted {
                ($0.todoDia ? 1 : 0, $0.ini, $0.titulo) < ($1.todoDia ? 1 : 0, $1.ini, $1.titulo)
            }
        }
        let todos = r.dias.values.flatMap { $0 }
        let recien = todos.filter { r.tachados.contains($0.id) }
        return Agenda(hoy: orden(r.dias[h] ?? []), manana: orden(r.dias[m] ?? []), recien: recien, hay: r.hay)
    }

    /// Lo que tienes ahora o lo próximo con hora.
    var siguiente: Item? {
        let n = Fechas.ahoraMin()
        return hoy.first { !$0.todoDia && Fechas.minutos($0.fin.isEmpty ? $0.ini : $0.fin) > n }
    }

    static let ejemplo = Agenda(
        hoy: [
            Item(id: "1", tipo: "t", fecha: "", ini: "17:45", fin: "18:15", titulo: "Coger la tarta", colorHex: "#d9a441", lista: "Familia", hecho: false),
            Item(id: "2", tipo: "e", fecha: "", ini: "18:30", fin: "19:00", titulo: "Llamar a mamá", colorHex: "#d98c9f", lista: "Personal", hecho: false),
            Item(id: "3", tipo: "t", fecha: "", ini: "", fin: "", titulo: "Rediseñar kit marcos", colorHex: "#6f8fd8", lista: "Trabajo", hecho: false),
        ],
        manana: [], recien: [], hay: true)
}

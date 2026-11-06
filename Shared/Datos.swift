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
    var aviso: Int? = nil   // minutos antes (si la tarea ya tiene su aviso en Google Calendar)
    var prioridad: String = ""

    var todoDia: Bool { ini.isEmpty }
    var esTarea: Bool { tipo == "t" }

    /// Fecha y hora de inicio (o nil si es de todo el día).
    var inicio: Date? { todoDia ? nil : Fechas.fecha(fecha, ini) }
    var final: Date? {
        guard let a = inicio else { return nil }
        if !fin.isEmpty, let b = Fechas.fecha(fecha, fin), b > a { return b }
        return a.addingTimeInterval(30 * 60)
    }
}

struct Habito: Identifiable, Hashable {
    let id: String
    let nombre: String
    let emoji: String
    let hecho: Bool
    let racha: Int
}

struct Compra: Identifiable, Hashable {
    let id: String      // la clave en tu despensa
    let nombre: String
    let cantidad: String
    let comprado: Bool
}

struct Dinero: Hashable {
    let libre: Int?
    let dia: Int?
    let etiqueta: String
    let gastado: Int?
    let plan: Int?
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
    static func fecha(_ dia: String, _ hhmm: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: dia + " " + hhmm)
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
        if m < 60 { return "\(max(1, m)) min" }
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
/// - Lo que haces aquí (tachar, marcar hábitos, apuntar cosas nuevas) se apunta en otro evento escondido
///   (2 ene 2030, «tachados desde el iPhone») y tu Centro lo recoge en cuanto lo abres.
final class Almacen {
    static let shared = Almacen()
    let store = EKEventStore()

    static let textoDatos = "datos del widget"
    static let textoTachados = "tachados desde el iphone"
    static let tituloTachados = "📱 Centro · tachados desde el iPhone (no borrar)"

    var permiso: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

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
        guard let data = String(t[a...b]).data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private func numero(_ v: Any?) -> Int? {
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String { return Int(s) }
        return nil
    }

    /// Pide al iPhone que mire ya si hay cambios en tus calendarios de Google.
    func refrescar() { store.refreshSourcesIfNecessary() }

    /// Tu Centro (abierto dentro de la app) nos pasa sus datos directamente: se guardan al momento
    /// en la copia del calendario del iPhone, sin esperar a que Google sincronice.
    @discardableResult
    func guardarCopia(_ texto: String) -> Bool {
        guard permiso, texto.hasPrefix("{"), let ev = evento(Self.textoDatos, dia: 1) else { return false }
        if ev.notes == texto { return false }
        ev.notes = texto
        do { try store.save(ev, span: .thisEvent, commit: true); return true } catch { return false }
    }

    /// Lo que has hecho en el iPhone y el Centro aún no ha recogido.
    func pendientes() -> [[String: Any]] {
        guard let ev = evento(Self.textoTachados, dia: 2), let o = json(ev.notes),
              let xs = o["x"] as? [[String: Any]] else { return [] }
        return xs
    }

    struct Copia {
        var dias: [String: [Item]] = [:]
        var comida: [String: [String: String]] = [:]
        var habitos: [Habito] = []
        var dinero: Dinero?
        var hechasHoy = 0
        var racha = 0
        var nivel = ""
        var hay = false
        var pendientesIds: Set<String> = []
        var pendientesPorId: [String: [String: Any]] = [:]
        var compra: [Compra] = []
        var nuevas: [String] = []
    }

    func cargar() -> Copia {
        var c = Copia()
        let pend = pendientes()
        c.pendientesIds = Set(pend.compactMap { $0["id"] as? String })
        for p in pend { if let id = p["id"] as? String { c.pendientesPorId[id] = p } }
        c.nuevas = pend.filter { ($0["t"] as? String) == "n" }.compactMap { $0["x"] as? String }
        guard let ev = evento(Self.textoDatos, dia: 1), let o = json(ev.notes) else { return c }
        c.hay = true
        if let d = o["d"] as? [String: Any] {
            for (f, valor) in d {
                guard let filas = valor as? [[Any]] else { continue }
                c.dias[f] = filas.map { r in
                    func s(_ i: Int) -> String { i < r.count ? (r[i] as? String ?? "") : "" }
                    let idOriginal = s(7)
                    let id = idOriginal.isEmpty ? "\(f)|\(s(2))|\(s(0))" : idOriginal
                    let hecho = (r.count > 5 ? (numero(r[5]) ?? 0) : 0) == 1 || c.pendientesIds.contains(id)
                    return Item(id: id, tipo: s(6), fecha: f, ini: s(0), fin: s(1), titulo: s(2),
                                colorHex: s(3), lista: s(4), hecho: hecho,
                                aviso: r.count > 8 ? numero(r[8]) : nil, prioridad: s(9))
                }
            }
        }
        if let m = o["m"] as? [String: [String: String]] { c.comida = m }
        let hoy = Fechas.clave(Date())
        if let h = o["h"] as? [[Any]] {
            c.habitos = h.compactMap { r in
                guard r.count >= 4, let id = r[0] as? String else { return nil }
                // si lo has tocado en el iPhone y el Centro aún no lo ha recogido, manda lo del iPhone
                var marcado = (numero(r[3]) ?? 0) == 1
                if let p = c.pendientesPorId["\(id)|\(hoy)"] { marcado = (p["on"] as? Bool) ?? true }
                return Habito(id: id, nombre: r[1] as? String ?? id, emoji: r[2] as? String ?? "",
                              hecho: marcado, racha: r.count > 4 ? (numero(r[4]) ?? 0) : 0)
            }
        }
        if let cs = o["c"] as? [[Any]] {
            c.compra = cs.compactMap { r in
                guard r.count >= 2, let k = r[0] as? String, let n = r[1] as? String else { return nil }
                return Compra(id: k, nombre: n, cantidad: r.count > 2 ? (r[2] as? String ?? "") : "",
                              comprado: c.pendientesIds.contains("cp|" + k))
            }
        }
        if let z = o["z"] as? [String: Any] {
            c.dinero = Dinero(libre: numero(z["libre"]), dia: numero(z["dia"]), etiqueta: z["tag"] as? String ?? "",
                              gastado: numero(z["gastado"]), plan: numero(z["plan"]))
        }
        if let k = o["k"] as? [String: Any] {
            c.hechasHoy = numero(k["hechas"]) ?? 0
            c.racha = numero(k["racha"]) ?? 0
            if let nv = k["nivel"] as? [Any], let n = nv.first as? String { c.nivel = n }
        }
        return c
    }

    // MARK: escribir

    private func eventoPendientes() throws -> EKEvent {
        if let e = evento(Self.textoTachados, dia: 2) { return e }
        guard let datos = evento(Self.textoDatos, dia: 1) else {
            throw NSError(domain: "Centro", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Abre tu Centro una vez para que lleguen tus cosas."])
        }
        let ev = EKEvent(eventStore: store)
        ev.calendar = datos.calendar
        ev.title = Self.tituloTachados
        let d = Calendar.current.startOfDay(for: dia2030(2))
        ev.startDate = d
        ev.endDate = d
        ev.isAllDay = true
        ev.availability = .free
        return ev
    }

    private func anadir(_ entrada: [String: Any]) throws {
        let ev = try eventoPendientes()
        var xs = (json(ev.notes)?["x"] as? [[String: Any]]) ?? []
        let id = entrada["id"] as? String ?? ""
        if !xs.contains(where: { ($0["id"] as? String) == id }) {
            var e = entrada
            e["at"] = ISO8601DateFormatter().string(from: Date())
            xs.append(e)
        }
        try guardar(ev, xs)
    }

    /// Apunta que has tachado algo. Tu Centro lo marcará de verdad al abrirlo.
    func tachar(id: String, tipo: String, fecha: String) throws {
        try anadir(["id": id, "t": tipo, "f": fecha])
    }

    /// Marca (o desmarca) un hábito de hoy. `ahora` es como se ve ahora mismo.
    func alternarHabito(id: String, ahora: Bool) throws {
        let hoy = Fechas.clave(Date())
        let clave = "\(id)|\(hoy)"
        if pendientes().contains(where: { ($0["id"] as? String) == clave }) {
            try deshacer(id: clave)          // vuelve a como estaba en tu Centro
        } else {
            try anadir(["id": clave, "t": "h", "f": hoy, "on": !ahora])
        }
    }

    /// Apunta un gasto (importe negativo) o un ingreso (positivo).
    func apuntarDinero(importe: Double, concepto: String, origen: String, categoria: String, fecha: Date) throws {
        try anadir(["id": "g-" + UUID().uuidString.prefix(8).lowercased(), "t": "g", "i": importe,
                    "x": concepto, "o": origen, "k": categoria, "f": Fechas.clave(fecha)])
    }

    /// Añade una comida: «menu» la planea en tu menú; «comido» la apunta en Mi comida.
    func apuntarComida(_ plato: String, momento: String, fecha: Date, modo: String) throws {
        let t = plato.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        try anadir(["id": "m-" + UUID().uuidString.prefix(8).lowercased(), "t": "m", "x": t,
                    "mom": momento, "f": Fechas.clave(fecha), "modo": modo])
    }

    /// Añade algo a la lista de la compra.
    func apuntarCompra(_ texto: String) throws {
        let t = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        try anadir(["id": "ca-" + UUID().uuidString.prefix(8).lowercased(), "t": "ca", "x": t])
    }

    /// Tacha (o destacha) algo de la lista de la compra.
    func alternarCompra(id: String) throws {
        let clave = "cp|" + id
        if pendientes().contains(where: { ($0["id"] as? String) == clave }) { try deshacer(id: clave) }
        else { try anadir(["id": clave, "t": "cp"]) }
    }

    /// Apunta algo nuevo (con Siri o con «Nueva tarea»). El Centro lo entiende como si lo escribieras allí.
    /// Si `rutina` es true, va a tu calendario Rutina (solo se ve en «Día», sin avisos).
    func apuntar(_ texto: String, rutina: Bool = false) throws {
        let t = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var e: [String: Any] = ["id": "n-" + UUID().uuidString.prefix(8).lowercased(), "t": "n", "x": t]
        if rutina { e["rut"] = true }
        try anadir(e)
    }

    /// Pasa algo a otro día (el botón «📅 Mañana» de las notificaciones).
    func mover(id: String, tipo: String, a dia: Date) throws {
        try anadir(["id": "mv|" + id, "t": "mv", "k": tipo, "f": Fechas.clave(dia)])
    }

    /// Deshace algo que todavía no ha llegado al Centro.
    func deshacer(id: String) throws {
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
    var hoy: [Item] = []            // lo que queda por hacer hoy
    var manana: [Item] = []
    var hechasHoy = 0
    var racha = 0
    var nivel = ""
    var comidaHoy: [String: String] = [:]
    var habitos: [Habito] = []
    var dinero: Dinero?
    var compra: [Compra] = []
    var nuevas: [String] = []
    var hay = false

    static func cargar() -> Agenda {
        let c = Almacen.shared.cargar()
        let ahora = Date()
        let h = Fechas.clave(ahora)
        let m = Fechas.clave(Calendar.current.date(byAdding: .day, value: 1, to: ahora) ?? ahora)
        func orden(_ xs: [Item]) -> [Item] {
            xs.filter { !$0.hecho }.sorted {
                ($0.todoDia ? 1 : 0, $0.ini, $0.titulo) < ($1.todoDia ? 1 : 0, $1.ini, $1.titulo)
            }
        }
        let movidas = Set(c.pendientesIds.filter { $0.hasPrefix("mv|") }.map { String($0.dropFirst(3)) })
        let todosHoy = (c.dias[h] ?? []).filter { !movidas.contains($0.id) }
        let tachadasAqui = todosHoy.filter { c.pendientesIds.contains($0.id) }.count
        return Agenda(hoy: orden(todosHoy), manana: orden(c.dias[m] ?? []),
                      hechasHoy: c.hechasHoy + tachadasAqui, racha: c.racha, nivel: c.nivel,
                      comidaHoy: c.comida[h] ?? [:], habitos: c.habitos, dinero: c.dinero,
                      compra: c.compra, nuevas: c.nuevas, hay: c.hay)
    }

    /// Lo que tienes ahora o lo próximo con hora.
    var siguiente: Item? {
        let n = Fechas.ahoraMin()
        return hoy.first { !$0.todoDia && Fechas.minutos($0.fin.isEmpty ? $0.ini : $0.fin) > n }
    }

    /// Cuánto llevas del día (0…1) contando lo hecho y lo que queda.
    var progreso: Double {
        let total = hechasHoy + hoy.count
        return total == 0 ? 1 : Double(hechasHoy) / Double(total)
    }

    /// Qué comida toca ahora.
    var comidaAhora: (momento: String, plato: String)? {
        let n = Fechas.ahoraMin()
        let orden: [(String, Int)] = [("desayuno", 11 * 60), ("comida", 16 * 60 + 30), ("merienda", 19 * 60), ("cena", 24 * 60)]
        for (k, limite) in orden where n < limite {
            if let p = comidaHoy[k] { return (k, p) }
        }
        return nil
    }

    static let ejemplo = Agenda(
        hoy: [
            Item(id: "1", tipo: "t", fecha: "", ini: "17:45", fin: "18:15", titulo: "Coger la tarta", colorHex: "#d9a441", lista: "Familia", hecho: false),
            Item(id: "2", tipo: "e", fecha: "", ini: "18:30", fin: "19:00", titulo: "Llamar a mamá", colorHex: "#d98c9f", lista: "Personal", hecho: false),
            Item(id: "3", tipo: "t", fecha: "", ini: "", fin: "", titulo: "Rediseñar kit marcos", colorHex: "#6f8fd8", lista: "Trabajo", hecho: false),
        ],
        manana: [], hechasHoy: 3, racha: 4, nivel: "Brote",
        comidaHoy: ["desayuno": "Tostadas con jamón", "comida": "Macarrones con carne", "merienda": "Sándwich mixto", "cena": "Lubina al horno"],
        habitos: [Habito(id: "a", nombre: "Recoger 45 min", emoji: "🧹", hecho: true, racha: 3),
                  Habito(id: "b", nombre: "Leer", emoji: "📖", hecho: false, racha: 0),
                  Habito(id: "c", nombre: "2 ejercicios", emoji: "🏃‍♀️", hecho: false, racha: 1)],
        dinero: Dinero(libre: 420, dia: 17, etiqueta: "Vamos bien", gastado: 900, plan: 1300),
        compra: [Compra(id: "a", nombre: "Leche", cantidad: "2", comprado: false),
                 Compra(id: "b", nombre: "Huevos", cantidad: "1 docena", comprado: false),
                 Compra(id: "c", nombre: "Pan de molde", cantidad: "", comprado: true),
                 Compra(id: "d", nombre: "Plátanos", cantidad: "", comprado: false)],
        nuevas: [], hay: true)
}

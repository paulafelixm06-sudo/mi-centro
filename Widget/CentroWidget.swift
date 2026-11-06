import WidgetKit
import SwiftUI
import AppIntents

// MARK: - datos para todos los widgets

struct Entrada: TimelineEntry {
    let date: Date
    let agenda: Agenda
    let permiso: Bool
}

struct Proveedor: TimelineProvider {
    var principal = false   // solo el widget «Mi día» se encarga de preparar las notificaciones

    func placeholder(in context: Context) -> Entrada {
        Entrada(date: Date(), agenda: .ejemplo, permiso: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entrada) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : actual())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entrada>) -> Void) {
        let e = actual()
        // Se vuelve a mirar cada 15 minutos (el iPhone decide el momento exacto),
        // y justo cuando empieza o termina lo siguiente, para que la tarjeta cambie a tiempo.
        var entradas = [e]
        if let s = e.agenda.siguiente, let ini = s.inicio, let fin = s.final {
            for d in [ini, fin] where d > Date() && d < Date().addingTimeInterval(15 * 60) {
                entradas.append(Entrada(date: d, agenda: e.agenda, permiso: e.permiso))
            }
        }
        let tl = Timeline(entries: entradas.sorted { $0.date < $1.date }, policy: .after(Date().addingTimeInterval(15 * 60)))
        if principal && e.permiso {
            Task {
                await Avisos.reprogramar()
                completion(tl)
            }
        } else {
            completion(tl)
        }
    }

    private func actual() -> Entrada {
        let p = Almacen.shared.permiso
        return Entrada(date: Date(), agenda: p ? Agenda.cargar() : Agenda(), permiso: p)
    }
}

// MARK: - piezas

struct Anillo: View {
    let progreso: Double
    var grosor: CGFloat = 5
    var body: some View {
        ZStack {
            Circle().stroke(Color.rosa.opacity(0.18), lineWidth: grosor)
            Circle().trim(from: 0, to: max(0.001, min(1, progreso)))
                .stroke(Color.rosa, style: StrokeStyle(lineWidth: grosor, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
        }
    }
}

struct BotonMas: View {
    let url: String
    var body: some View {
        Link(destination: URL(string: url)!) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.rosa))
        }
    }
}

/// Casilla que se toca para tachar (sin abrir nada).
struct Casilla: View {
    let it: Item
    var tam: CGFloat = 18
    var body: some View {
        Button(intent: TacharIntent(id: it.id, tipo: it.tipo, fecha: it.fecha)) {
            ZStack {
                if it.esTarea {
                    RoundedRectangle(cornerRadius: tam * 0.3).strokeBorder(Color(hex: it.colorHex), lineWidth: 2)
                } else {
                    Circle().strokeBorder(Color(hex: it.colorHex), lineWidth: 2)
                }
            }
            .frame(width: tam, height: tam)
            .contentShape(Rectangle().inset(by: -6))
        }
        .buttonStyle(.plain)
    }
}

struct Fila: View {
    let it: Item
    var body: some View {
        HStack(spacing: 9) {
            Casilla(it: it)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 3) {
                    if it.prioridad == "alta" {
                        Image(systemName: "flag.fill").font(.system(size: 8)).foregroundStyle(Color(hex: "#d65a5a"))
                    }
                    Text(it.titulo)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.tinta)
                        .lineLimit(1)
                }
                Text(subtitulo(it))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.gris)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

struct TarjetaSiguiente: View {
    let it: Item
    let ahora: Date
    var compacta = false
    var body: some View {
        let c = Calendar.current.dateComponents([.hour, .minute], from: ahora)
        let n = (c.hour ?? 0) * 60 + (c.minute ?? 0), a = Fechas.minutos(it.ini)
        let fin = it.fin.isEmpty ? it.ini : it.fin
        let etiqueta = a <= n ? "AHORA · HASTA LAS \(fin)" : "EN \(Fechas.duracion(a - n).uppercased()) · \(it.ini)"
        HStack(spacing: 10) {
            Casilla(it: it, tam: compacta ? 18 : 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(etiqueta).font(.system(size: compacta ? 8.5 : 9.5, weight: .semibold)).opacity(0.75)
                Text(it.titulo).font(.system(size: compacta ? 13 : 14.5, weight: .semibold)).lineLimit(compacta ? 2 : 1)
                if !compacta {
                    Text("\(it.ini) – \(fin)" + (it.lista.isEmpty ? "" : " · \(it.lista)"))
                        .font(.system(size: 10.5)).opacity(0.75).lineLimit(1)
                }
            }
            .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, compacta ? 8 : 9)
        .background(
            RoundedRectangle(cornerRadius: 16).fill(Color.tarjeta)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: it.colorHex)).frame(width: 3).padding(.vertical, 10)
                }
        )
    }
}

func avisoVacio(_ e: Entrada) -> String? {
    if !e.permiso { return "Abre la app «Centro» una vez y dale permiso al calendario." }
    if !e.agenda.hay { return "Abre tu Centro un momento para que lleguen tus cosas." }
    return nil
}

func textoAviso(_ t: String) -> some View {
    Text(t).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.gris)
}

// MARK: - 1. Mi día

struct VistaMiDia: View {
    @Environment(\.widgetFamily) var fam
    let e: Entrada
    var a: Agenda { e.agenda }

    var body: some View {
        if let t = avisoVacio(e) {
            textoAviso(t)
        } else {
            switch fam {
            case .systemSmall: pequeno
            case .systemMedium: mediano
            case .accessoryRectangular: bloqueo
            case .accessoryCircular: circulo
            case .accessoryInline: linea
            default: grande
            }
        }
    }

    var dia: String { Fechas.titulo(e.date) }
    var resumen: String {
        var p: [String] = []
        if a.hechasHoy > 0 { p.append("\(a.hechasHoy) hechas") }
        p.append(a.hoy.isEmpty ? "todo listo ✨" : "\(a.hoy.count) por hacer")
        return p.joined(separator: " · ")
    }
    var racha: String? { a.racha > 1 ? "🔥 \(a.racha) días seguidos" : nil }

    func anillo(_ tam: CGFloat, _ grosor: CGFloat, texto: Bool = true) -> some View {
        ZStack {
            Anillo(progreso: a.progreso, grosor: grosor)
            if texto {
                if a.hoy.isEmpty && a.hechasHoy > 0 {
                    Image(systemName: "checkmark").font(.system(size: tam * 0.32, weight: .bold)).foregroundStyle(Color.rosa)
                } else {
                    Text("\(a.hechasHoy)").font(.system(size: tam * 0.36, weight: .bold, design: .rounded)).foregroundStyle(Color.tinta)
                }
            }
        }
        .frame(width: tam, height: tam)
    }

    var nadaMas: some View {
        HStack(spacing: 6) {
            Text(a.hechasHoy > 0 ? "¡Día completado! 🎉" : "Nada más por hoy ✨")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.tinta)
        }
    }

    var pequeno: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                anillo(32, 4)
                VStack(alignment: .leading, spacing: 0) {
                    Text(dia).font(.system(size: 14, weight: .bold)).foregroundStyle(Color.tinta).lineLimit(1)
                    Text(a.racha > 1 ? "🔥 \(a.racha) días" : (a.hoy.isEmpty ? "todo listo" : "\(a.hoy.count) por hacer"))
                        .font(.system(size: 10.5)).foregroundStyle(Color.gris)
                }
                Spacer(minLength: 0)
            }
            if let s = a.siguiente {
                TarjetaSiguiente(it: s, ahora: e.date, compacta: true)
            } else if let p = a.hoy.first {
                Fila(it: p)
                if a.hoy.count > 1 { Fila(it: a.hoy[1]) }
            } else {
                nadaMas
            }
            Spacer(minLength: 0)
        }
        .widgetURL(URL(string: "centro://hoy"))
    }

    var mediano: some View {
        let sig = a.siguiente
        let resto = a.hoy.filter { $0.id != sig?.id }
        let caben = sig == nil ? 4 : 2
        return HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 6) {
                anillo(64, 7)
                Text(dia).font(.system(size: 12.5, weight: .bold)).foregroundStyle(Color.tinta).lineLimit(1).minimumScaleFactor(0.8)
                Text(a.racha > 1 ? "🔥 \(a.racha) días" : (a.hoy.isEmpty ? "todo listo" : "\(a.hoy.count) por hacer"))
                    .font(.system(size: 10)).foregroundStyle(Color.gris)
            }
            .frame(width: 84)
            VStack(alignment: .leading, spacing: 7) {
                if let s = sig { TarjetaSiguiente(it: s, ahora: e.date, compacta: true) }
                if a.hoy.isEmpty { nadaMas.padding(.top, 18) }
                ForEach(Array(resto.prefix(caben))) { Fila(it: $0) }
                if resto.count > caben {
                    Text("+ \(resto.count - caben) más").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.gris)
                }
                Spacer(minLength: 0)
            }
        }
        .overlay(alignment: .topTrailing) { BotonMas(url: "centro://nueva").offset(x: 4, y: -4) }
    }

    var grande: some View {
        let sig = a.siguiente
        let resto = a.hoy.filter { $0.id != sig?.id }
        let caben = sig == nil ? 8 : 6
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                anillo(40, 5)
                VStack(alignment: .leading, spacing: 0) {
                    Text(dia).font(.system(size: 18, weight: .bold)).foregroundStyle(Color.tinta)
                    Text(resumen + (racha.map { " · " + $0 } ?? "")).font(.system(size: 11)).foregroundStyle(Color.gris).lineLimit(1)
                }
                Spacer(minLength: 0)
                BotonMas(url: "centro://nueva")
            }
            if let s = sig { TarjetaSiguiente(it: s, ahora: e.date) }
            if a.hoy.isEmpty { nadaMas.padding(.vertical, 6) }
            ForEach(Array(resto.prefix(caben))) { Fila(it: $0) }
            if resto.count > caben {
                Text("+ \(resto.count - caben) más").font(.system(size: 10.5, weight: .medium)).foregroundStyle(Color.gris)
            }
            Spacer(minLength: 0)
            if !a.manana.isEmpty {
                HStack(spacing: 6) {
                    Text("MAÑANA").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.rosa)
                    Text("\(a.manana.count) \(a.manana.count == 1 ? "cosa" : "cosas") · " + a.manana.prefix(2).map { ($0.todoDia ? "" : $0.ini + " ") + $0.titulo }.joined(separator: ", "))
                        .font(.system(size: 10.5)).foregroundStyle(Color.gris).lineLimit(1)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.linea.opacity(0.6)))
            }
        }
    }

    var bloqueo: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let s = a.siguiente ?? a.hoy.first {
                Text(s.todoDia ? "Hoy · \(a.hoy.count) por hacer" : s.ini + (s.lista.isEmpty ? "" : " · \(s.lista)"))
                    .font(.system(size: 11, weight: .semibold))
                Text(s.titulo).font(.system(size: 14, weight: .bold)).lineLimit(2)
            } else {
                Text("Nada más por hoy ✨").font(.system(size: 13, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var circulo: some View {
        Gauge(value: a.progreso) {
            Image(systemName: "checkmark")
        } currentValueLabel: {
            Text("\(a.hoy.count)")
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    @ViewBuilder var linea: some View {
        if let s = a.siguiente {
            Text("\(s.ini) \(s.titulo)")
        } else {
            Text(a.hoy.isEmpty ? "Todo hecho ✨" : "\(a.hoy.count) por hacer hoy")
        }
    }
}

// MARK: - 2. Hábitos

struct VistaHabitos: View {
    @Environment(\.widgetFamily) var fam
    let e: Entrada

    var body: some View {
        if let t = avisoVacio(e) { textoAviso(t) }
        else if e.agenda.habitos.isEmpty { textoAviso("Configura tus hábitos en tu Centro (Mi día → Hábitos).") }
        else {
            let hs = e.agenda.habitos
            let hechos = hs.filter(\.hecho).count
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Anillo(progreso: Double(hechos) / Double(max(1, hs.count)), grosor: 3.5).frame(width: 18, height: 18)
                    Text("Hábitos").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.tinta)
                    Spacer(minLength: 0)
                    Text("\(hechos)/\(hs.count)").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(Color.gris)
                }
                if fam == .systemSmall {
                    ForEach(Array(hs.prefix(4))) { BotonHabito(h: $0, compacto: true) }
                } else {
                    let max = fam == .systemLarge ? 14 : 6
                    let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
                    LazyVGrid(columns: cols, alignment: .leading, spacing: 7) {
                        ForEach(Array(hs.prefix(max))) { BotonHabito(h: $0, compacto: false) }
                    }
                }
                Spacer(minLength: 0)
                if hechos == hs.count {
                    Text("¡Todos hechos hoy! 🌟").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.rosa)
                }
            }
        }
    }
}

struct BotonHabito: View {
    let h: Habito
    let compacto: Bool
    var body: some View {
        Button(intent: HabitoIntent(id: h.id, hecho: h.hecho)) {
            HStack(spacing: 7) {
                ZStack {
                    Circle().fill(h.hecho ? Color.rosa : Color.clear)
                    Circle().strokeBorder(h.hecho ? Color.rosa : Color.gris.opacity(0.5), lineWidth: 1.8)
                    if h.hecho { Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(.white) }
                }
                .frame(width: 18, height: 18)
                Text((h.emoji.isEmpty ? "" : h.emoji + " ") + h.nombre)
                    .font(.system(size: compacto ? 12 : 12.5, weight: .medium))
                    .foregroundStyle(h.hecho ? Color.gris : Color.tinta)
                    .strikethrough(h.hecho, color: Color.gris)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if h.racha > 1 {
                    Text("🔥\(h.racha)").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(Color.gris)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 3. Comida

let MOMENTOS: [(clave: String, nombre: String, emoji: String)] = [
    ("desayuno", "Desayuno", "🥐"), ("comida", "Comida", "🍝"), ("merienda", "Merienda", "🍎"), ("cena", "Cena", "🌙"),
]

struct VistaComida: View {
    @Environment(\.widgetFamily) var fam
    let e: Entrada

    var body: some View {
        if let t = avisoVacio(e) { textoAviso(t) }
        else if fam == .systemSmall { pequeno }
        else { mediano }
    }

    var actual: String? { e.agenda.comidaAhora?.momento }

    var pequeno: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let c = e.agenda.comidaAhora, let m = MOMENTOS.first(where: { $0.clave == c.momento }) {
                Text("AHORA TOCA · \(m.nombre.uppercased())").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.rosa)
                Text(m.emoji).font(.system(size: 30))
                Text(c.plato).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.tinta).lineLimit(3)
            } else {
                Text("COCINA").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.rosa)
                Text("🍽️").font(.system(size: 30))
                Text("Sin menú para ahora").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.tinta)
                Text("Toca para añadir una comida").font(.system(size: 10.5)).foregroundStyle(Color.gris)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(URL(string: "centro://comida"))
    }

    var mediano: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Menú de hoy").font(.system(size: 15, weight: .bold)).foregroundStyle(Color.tinta)
                Spacer()
                BotonMas(url: "centro://comida")
            }
            ForEach(MOMENTOS, id: \.clave) { m in
                let plato = e.agenda.comidaHoy[m.clave]
                let ya = m.clave == actual
                HStack(spacing: 9) {
                    Text(m.emoji).font(.system(size: 15)).frame(width: 22)
                    Text(m.nombre).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(ya ? Color.rosa : Color.gris).frame(width: 62, alignment: .leading)
                    Text(plato ?? "—").font(.system(size: 13, weight: ya ? .bold : .medium))
                        .foregroundStyle(plato == nil ? Color.gris : Color.tinta).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 9).fill(ya ? Color.rosa.opacity(0.12) : .clear))
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 4. Lista de la compra

struct VistaCompra: View {
    @Environment(\.widgetFamily) var fam
    let e: Entrada

    var body: some View {
        if let t = avisoVacio(e) { textoAviso(t) }
        else {
            let xs = e.agenda.compra
            let quedan = xs.filter { !$0.comprado }.count
            let max = fam == .systemSmall ? 4 : (fam == .systemMedium ? 6 : 16)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("🛒 Compra").font(.system(size: 15, weight: .bold)).foregroundStyle(Color.tinta)
                    Spacer()
                    if fam == .systemSmall {
                        Text("\(quedan)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Color.gris)
                    } else {
                        Text(quedan == 0 ? "todo comprado" : "\(quedan) por comprar").font(.system(size: 11)).foregroundStyle(Color.gris)
                        BotonMas(url: "centro://compra")
                    }
                }
                if xs.isEmpty {
                    Text("Lista vacía ✨").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.tinta).padding(.top, 4)
                    Text("Toca ＋ para apuntar algo").font(.system(size: 11)).foregroundStyle(Color.gris)
                } else if fam == .systemSmall {
                    ForEach(Array(xs.prefix(max))) { FilaCompra(c: $0) }
                } else {
                    let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
                    LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
                        ForEach(Array(xs.prefix(max))) { FilaCompra(c: $0) }
                    }
                }
                if xs.count > max {
                    Text("+ \(xs.count - max) más").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.gris)
                }
                Spacer(minLength: 0)
            }
            .widgetURL(fam == .systemSmall ? URL(string: "centro://compra") : nil)
        }
    }
}

struct FilaCompra: View {
    let c: Compra
    var body: some View {
        Button(intent: CompraIntent(id: c.id)) {
            HStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5).fill(c.comprado ? Color(hex: "#7fb8a4") : .clear)
                    RoundedRectangle(cornerRadius: 5).strokeBorder(c.comprado ? Color(hex: "#7fb8a4") : Color.gris.opacity(0.5), lineWidth: 1.8)
                    if c.comprado { Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(.white) }
                }
                .frame(width: 17, height: 17)
                Text(c.nombre + (c.cantidad.isEmpty ? "" : " · \(c.cantidad)"))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(c.comprado ? Color.gris : Color.tinta)
                    .strikethrough(c.comprado, color: Color.gris)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 5. Presupuesto

func euros(_ n: Int) -> String {
    let f = NumberFormatter()
    f.locale = Locale(identifier: "es_ES")
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    return (f.string(from: NSNumber(value: n)) ?? "\(n)") + " €"
}

struct VistaDinero: View {
    @Environment(\.widgetFamily) var fam
    let e: Entrada

    var body: some View {
        if let t = avisoVacio(e) { textoAviso(t) }
        else if let d = e.agenda.dinero, let libre = d.libre {
            if fam == .systemSmall { pequeno(d, libre) } else { mediano(d, libre) }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("💶 Presupuesto").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.tinta)
                textoAviso("Abre «Presupuesto» en tu Centro una vez para ver aquí lo que te queda.")
                Spacer(minLength: 0)
            }
            .widgetURL(URL(string: "centro://gasto"))
        }
    }

    func colorTag(_ t: String) -> Color {
        let s = t.lowercased()
        if s.contains("bien") || s.contains("genial") || s.contains("sobra") { return Color(hex: "#5f9e86") }
        if s.contains("cuidado") || s.contains("ojo") || s.contains("justo") { return Color(hex: "#d9a441") }
        if s.contains("pas") || s.contains("rojo") { return Color(hex: "#d65a5a") }
        return Color.rosa
    }

    func cifra(_ d: Dinero, _ libre: Int, grande: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("TE QUEDAN ESTE MES").font(.system(size: 8.5, weight: .bold)).foregroundStyle(Color.gris)
            Text(euros(libre)).font(.system(size: grande, weight: .bold, design: .rounded)).foregroundStyle(libre < 0 ? Color(hex: "#d65a5a") : Color.tinta)
                .minimumScaleFactor(0.6).lineLimit(1)
            if let dia = d.dia { Text("\(euros(dia)) al día").font(.system(size: 11.5, weight: .medium)).foregroundStyle(Color.gris) }
            if !d.etiqueta.isEmpty {
                Text(d.etiqueta).font(.system(size: 10, weight: .semibold)).foregroundStyle(colorTag(d.etiqueta))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(colorTag(d.etiqueta).opacity(0.14)))
                    .padding(.top, 3)
            }
        }
    }

    func pequeno(_ d: Dinero, _ libre: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("💶").font(.system(size: 16))
                Spacer()
                Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(Color.rosa)
            }
            Spacer(minLength: 4)
            cifra(d, libre, grande: 26)
        }
        .widgetURL(URL(string: "centro://gasto"))
    }

    func mediano(_ d: Dinero, _ libre: Int) -> some View {
        HStack(alignment: .top, spacing: 14) {
            cifra(d, libre, grande: 30)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 8) {
                if let g = d.gastado, let p = d.plan, p > 0 {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Gastado \(euros(g)) de \(euros(p))").font(.system(size: 10)).foregroundStyle(Color.gris)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.linea)
                                Capsule().fill(Double(g) / Double(p) > 1 ? Color(hex: "#d65a5a") : Color.rosa)
                                    .frame(width: geo.size.width * min(1, Double(g) / Double(p)))
                            }
                        }
                        .frame(width: 120, height: 6)
                    }
                }
                Spacer(minLength: 0)
                Link(destination: URL(string: "centro://gasto")!) {
                    Label("Gasto", systemImage: "minus").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 120, height: 32).background(Capsule().fill(Color.rosa))
                }
                Link(destination: URL(string: "centro://ingreso")!) {
                    Label("Ingreso", systemImage: "plus").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.rosa)
                        .frame(width: 120, height: 32).background(Capsule().fill(Color.rosa.opacity(0.14)))
                }
            }
        }
    }
}

// MARK: - los widgets

struct CentroWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CentroWidget", provider: Proveedor(principal: true)) { e in
            VistaMiDia(e: e).containerBackground(for: .widget) { Color.fondo }
        }
        .configurationDisplayName("Mi día")
        .description("Lo siguiente, tus tareas de hoy y tu progreso. Toca la casilla para tachar.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct HabitosWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CentroHabitos", provider: Proveedor()) { e in
            VistaHabitos(e: e).containerBackground(for: .widget) { Color.fondo }
        }
        .configurationDisplayName("Hábitos")
        .description("Marca tus hábitos de hoy sin abrir nada.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ComidaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CentroComida", provider: Proveedor()) { e in
            VistaComida(e: e).containerBackground(for: .widget) { Color.fondo }
        }
        .configurationDisplayName("Menú de hoy")
        .description("Qué toca comer ahora. Con ＋ añades una comida.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CompraWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CentroCompra", provider: Proveedor()) { e in
            VistaCompra(e: e).containerBackground(for: .widget) { Color.fondo }
        }
        .configurationDisplayName("Lista de la compra")
        .description("Ve tachando lo que compras. Con ＋ apuntas algo nuevo.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct DineroWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CentroDinero", provider: Proveedor()) { e in
            VistaDinero(e: e).containerBackground(for: .widget) { Color.fondo }
        }
        .configurationDisplayName("Presupuesto")
        .description("Lo que te queda este mes. Con ＋ apuntas un gasto o un ingreso.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PaqueteWidgets: WidgetBundle {
    var body: some Widget {
        CentroWidget()
        HabitosWidget()
        ComidaWidget()
        CompraWidget()
        DineroWidget()
        SiguienteActividad()
    }
}

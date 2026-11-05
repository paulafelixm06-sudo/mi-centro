import WidgetKit
import SwiftUI
import AppIntents

struct Entrada: TimelineEntry {
    let date: Date
    let agenda: Agenda
    let permiso: Bool
}

struct Proveedor: TimelineProvider {
    func placeholder(in context: Context) -> Entrada {
        Entrada(date: Date(), agenda: .ejemplo, permiso: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entrada) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : actual())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entrada>) -> Void) {
        let e = actual()
        // Se vuelve a mirar cada 15 minutos (el iPhone decide el momento exacto).
        completion(Timeline(entries: [e], policy: .after(Date().addingTimeInterval(15 * 60))))
    }

    private func actual() -> Entrada {
        let p = Almacen.shared.permiso
        return Entrada(date: Date(), agenda: p ? Agenda.cargar() : Agenda(), permiso: p)
    }
}

// Casilla que se toca para tachar (sin abrir nada).
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
                Text(it.titulo)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.tinta)
                    .lineLimit(1)
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
    var compacta = false
    var body: some View {
        let n = Fechas.ahoraMin(), a = Fechas.minutos(it.ini)
        let fin = it.fin.isEmpty ? it.ini : it.fin
        let etiqueta = a <= n ? "AHORA · HASTA LAS \(fin)" : "LO SIGUIENTE · EN \(Fechas.duracion(a - n).uppercased())"
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
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.tarjeta))
    }
}

struct VistaWidget: View {
    @Environment(\.widgetFamily) var fam
    let e: Entrada

    var body: some View {
        if !e.permiso {
            aviso("Abre la app «Centro» una vez y dale permiso al calendario.")
        } else if !e.agenda.hay {
            aviso("Abre tu Centro un momento para que lleguen tus tareas.")
        } else {
            switch fam {
            case .systemSmall: pequeno
            case .accessoryRectangular: bloqueo
            case .systemMedium: lista(max: 3)
            default: lista(max: 8)
            }
        }
    }

    func aviso(_ t: String) -> some View {
        Text(t).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.gris)
    }

    var cabecera: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(Fechas.titulo(e.date)).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.tinta)
            Spacer()
            let n = e.agenda.hoy.count
            Text(n == 0 ? "todo hecho ✨" : "\(n) por hacer").font(.system(size: 11)).foregroundStyle(Color.gris)
        }
    }

    var pequeno: some View {
        VStack(alignment: .leading, spacing: 8) {
            cabecera
            if let s = e.agenda.siguiente {
                TarjetaSiguiente(it: s, compacta: true)
            } else if let p = e.agenda.hoy.first {
                Fila(it: p)
            } else {
                Text("Nada más por hoy ✨").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.tinta)
            }
            Spacer(minLength: 0)
        }
    }

    var bloqueo: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let s = e.agenda.siguiente ?? e.agenda.hoy.first {
                Text(s.todoDia ? "Hoy" : s.ini).font(.system(size: 11, weight: .semibold))
                Text(s.titulo).font(.system(size: 14, weight: .bold)).lineLimit(2)
            } else {
                Text("Nada más por hoy ✨").font(.system(size: 13, weight: .semibold))
            }
        }
    }

    func lista(max: Int) -> some View {
        let sig = e.agenda.siguiente
        let resto = e.agenda.hoy.filter { $0.id != sig?.id }
        let hueco = max - (sig == nil ? 0 : (fam == .systemMedium ? 2 : 2))
        return VStack(alignment: .leading, spacing: 7) {
            cabecera
            if let s = sig { TarjetaSiguiente(it: s, compacta: fam == .systemMedium) }
            if e.agenda.hoy.isEmpty {
                Text("Nada más por hoy ✨").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.tinta)
            }
            ForEach(Array(resto.prefix(Swift.max(0, hueco)))) { Fila(it: $0) }
            if resto.count > hueco && hueco >= 0 {
                Text("+ \(resto.count - hueco) más").font(.system(size: 10.5, weight: .medium)).foregroundStyle(Color.gris)
            }
            Spacer(minLength: 0)
        }
    }
}

struct CentroWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CentroWidget", provider: Proveedor()) { e in
            VistaWidget(e: e)
                .containerBackground(for: .widget) { Color.fondo }
        }
        .configurationDisplayName("Mi día")
        .description("Tus tareas de hoy. Toca la casilla para tacharlas.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

@main
struct PaqueteWidgets: WidgetBundle {
    var body: some Widget {
        CentroWidget()
    }
}

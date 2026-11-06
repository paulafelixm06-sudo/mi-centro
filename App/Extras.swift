import SwiftUI
import UIKit
import LocalAuthentication
import Network
import AppIntents
import UserNotifications

// MARK: - 📚 portadas de libros (el iPhone sí puede buscarlas en internet)

enum Portadas {
    private static let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    static func buscar(_ libros: [[String: Any]]) async {
        var hechas: [String: Data?] = [:]
        for l in libros {
            guard let id = l["id"] as? String else { continue }
            let q = (l["q"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let autor = (l["autor"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let clave = (q + "|" + autor).lowercased()
            let jpg: Data?
            if let ya = hechas[clave] { jpg = ya } else {
                jpg = await una(q, autor)
                hechas[clave] = jpg
            }
            await Estado.shared.enviarPortada(id: id, jpg: jpg)
        }
    }

    /// Portadas que ya tienes en Notion: tu Centro nos pasa el enlace (dura 5 minutos) y la descargamos.
    static func descargar(_ ls: [[String: Any]]) async {
        for l in ls {
            guard let id = l["id"] as? String, let u = l["url"] as? String else { continue }
            var jpg = await imagen(u)
            if jpg == nil, let q = l["q"] as? String { jpg = await una(q, l["autor"] as? String ?? "") }
            await Estado.shared.enviarPortada(id: id, jpg: jpg)
        }
    }

    static func una(_ q: String, _ autor: String) async -> Data? {
        guard !q.isEmpty else { return nil }
        if let d = await google(q, autor, "es") { return d }
        if let d = await google(q, autor, nil) { return d }
        if let d = await openLibrary(q, autor) { return d }
        if !autor.isEmpty, let d = await google(q, "", "es") { return d }
        return nil
    }

    private static func pedir(_ s: String) async -> Data? {
        guard let u = URL(string: s) else { return nil }
        var r = URLRequest(url: u, timeoutInterval: 15)
        r.setValue(ua, forHTTPHeaderField: "User-Agent")
        guard let (d, resp) = try? await URLSession.shared.data(for: r),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return d
    }

    private static func cod(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+=?"))) ?? s
    }

    private static func google(_ q: String, _ autor: String, _ lang: String?) async -> Data? {
        var consulta = "intitle:\"\(q)\""
        if !autor.isEmpty { consulta += " inauthor:\"\(autor)\"" }
        var url = "https://www.googleapis.com/books/v1/volumes?maxResults=5&printType=books&q=" + cod(consulta)
        if let lang { url += "&langRestrict=" + lang }
        guard let d = await pedir(url),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let items = o["items"] as? [[String: Any]] else { return nil }
        for it in items {
            let il = (it["volumeInfo"] as? [String: Any])?["imageLinks"] as? [String: Any]
            guard var t = (il?["thumbnail"] as? String) ?? (il?["smallThumbnail"] as? String) else { continue }
            t = t.replacingOccurrences(of: "http://", with: "https://").replacingOccurrences(of: "&edge=curl", with: "")
            for v in [t + "&fife=w600", t] {
                if let img = await imagen(v) { return img }
            }
        }
        return nil
    }

    private static func openLibrary(_ q: String, _ autor: String) async -> Data? {
        var url = "https://openlibrary.org/search.json?limit=5&title=" + cod(q)
        if !autor.isEmpty { url += "&author=" + cod(autor) }
        guard let d = await pedir(url),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let docs = o["docs"] as? [[String: Any]] else { return nil }
        for doc in docs {
            if let c = doc["cover_i"] as? Int, let img = await imagen("https://covers.openlibrary.org/b/id/\(c)-L.jpg") { return img }
        }
        return nil
    }

    /// Descarga la imagen y la deja a 300 px de ancho, en JPEG.
    static func imagen(_ s: String) async -> Data? {
        guard let d = await pedir(s), let im = UIImage(data: d), im.size.width >= 90, im.size.height >= 120 else { return nil }
        let w: CGFloat = 300, h = (im.size.height * w / im.size.width).rounded()
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
        let r = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: f)
        return r.image { _ in im.draw(in: CGRect(x: 0, y: 0, width: w, height: h)) }.jpegData(compressionQuality: 0.8)
    }
}

// MARK: - 🔒 Face ID para el dinero

struct CandadoDinero: View {
    @ObservedObject var estado = Estado.shared
    @State private var fallo = false

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill").font(.system(size: 40, weight: .semibold)).foregroundStyle(Color.rosa)
                Text("Tu presupuesto está protegido").font(.system(size: 20, weight: .bold)).foregroundStyle(Color.tinta)
                Text(fallo ? "No se ha podido comprobar. Prueba otra vez." : "Desbloquéalo con Face ID para verlo.")
                    .font(.system(size: 15)).foregroundStyle(Color.gris).multilineTextAlignment(.center)
                BotonGrande(texto: "Desbloquear") { desbloquear() }.frame(maxWidth: 260)
                Button("Volver a Mi día") { estado.irA("agenda") }
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Color.gris)
            }
            .padding(30)
        }
        .onAppear { desbloquear() }
    }

    func desbloquear() {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "Usar código"
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            estado.dineroAbierto = true      // sin Face ID ni código: no bloqueamos
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Ver tu presupuesto") { ok, _ in
            DispatchQueue.main.async {
                if ok { withAnimation { estado.dineroAbierto = true } } else { fallo = true }
            }
        }
    }
}

// MARK: - 📡 sin conexión: lo último que tenías

struct VistaSinConexion: View {
    @ObservedObject var estado = Estado.shared
    @State private var a = Agenda.cargar()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sin conexión 📡").font(.system(size: 24, weight: .bold)).foregroundStyle(Color.tinta)
                        Text("Esto es lo último que tenías. Lo que taches aquí se guarda y llega a tu Centro en cuanto vuelva internet.")
                            .font(.system(size: 13.5)).foregroundStyle(Color.gris)
                    }
                    Spacer()
                }
                Button { estado.reintentar() } label: {
                    Label("Reintentar", systemImage: "arrow.clockwise").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 10).background(Capsule().fill(Color.rosa))
                }
                seccion("Hoy · " + Fechas.titulo(Date())) {
                    if a.hoy.isEmpty { Text("Nada pendiente ✨").foregroundStyle(Color.gris) }
                    ForEach(a.hoy) { it in
                        Button {
                            try? Almacen.shared.tachar(id: it.id, tipo: it.tipo, fecha: it.fecha)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation { a = Agenda.cargar() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: it.esTarea ? "square" : "circle").foregroundStyle(Color(hex: it.colorHex))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(it.titulo).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.tinta)
                                    Text(subtitulo(it)).font(.system(size: 12)).foregroundStyle(Color.gris)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !a.comidaHoy.isEmpty {
                    seccion("Menú de hoy") {
                        ForEach(MOMENTOS_APP, id: \.0) { m in
                            if let p = a.comidaHoy[m.0] {
                                HStack { Text(m.1).frame(width: 26); Text(p).foregroundStyle(Color.tinta); Spacer() }.font(.system(size: 14.5))
                            }
                        }
                    }
                }
                if !a.compra.isEmpty {
                    seccion("🛒 Compra") {
                        ForEach(a.compra) { c in
                            Button {
                                try? Almacen.shared.alternarCompra(id: c.id)
                                withAnimation { a = Agenda.cargar() }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: c.comprado ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(c.comprado ? Color(hex: "#7fb8a4") : Color.gris)
                                    Text(c.nombre + (c.cantidad.isEmpty ? "" : " · \(c.cantidad)"))
                                        .strikethrough(c.comprado).foregroundStyle(c.comprado ? Color.gris : Color.tinta)
                                    Spacer()
                                }
                                .font(.system(size: 15))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color.fondo.ignoresSafeArea())
    }

    func seccion<C: View>(_ t: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t.uppercased()).font(.system(size: 11.5, weight: .bold)).foregroundStyle(Color.gris)
            c()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.papel))
    }
}

let MOMENTOS_APP: [(String, String)] = [("desayuno", "🥐"), ("comida", "🍝"), ("merienda", "🍎"), ("cena", "🌙")]

/// Vigila si vuelve internet para recargar sola.
final class Red {
    static let shared = Red()
    private let monitor = NWPathMonitor()
    func empezar() {
        monitor.pathUpdateHandler = { p in
            if p.status == .satisfied {
                DispatchQueue.main.async { if Estado.shared.sinConexion { Estado.shared.reintentar() } }
            }
        }
        monitor.start(queue: DispatchQueue(label: "centro.red"))
    }
}

// MARK: - 🎯 modo Concentración

enum ModoVer: String, AppEnum {
    case todo, trabajo, personal, casa, familia
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Qué ver"
    static let caseDisplayRepresentations: [ModoVer: DisplayRepresentation] = [
        .todo: "Todo", .trabajo: "Solo trabajo", .personal: "Solo personal", .casa: "Solo casa", .familia: "Solo familia",
    ]
}

struct FiltroConcentracion: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Qué ver en Centro"
    static var description: IntentDescription? = IntentDescription("Con este modo de Concentración, tu Centro solo te enseña lo que toca.")

    @Parameter(title: "Ver", default: .todo) var ver: ModoVer

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Centro: \(ver.rawValue)")
    }

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(ver.rawValue, forKey: "centro-foco")
        await MainActor.run { Estado.shared.aplicarFoco() }
        return .result()
    }
}

// MARK: - 💳 pagos con el móvil (automatización de Atajos)

struct PagoConMovilIntent: AppIntent {
    static let title: LocalizedStringResource = "Apuntar pago con el móvil"
    static let description = IntentDescription("Para la automatización «Transacción» de Atajos: apunta cada pago con Apple Pay en tu Presupuesto.")

    @Parameter(title: "Importe") var importe: Double
    @Parameter(title: "Comercio", default: "") var comercio: String

    func perform() async throws -> some IntentResult {
        try Almacen.shared.apuntarPagoConMovil(importe: importe, tienda: comercio)
        let ct = UNMutableNotificationContent()
        let fmt = importe.formatted(.number.precision(.fractionLength(0...2)))
        ct.title = "💳 Apuntado: \(fmt) €"
        ct.body = comercio.isEmpty ? "Ya está en tu Presupuesto." : "\(comercio) · ya está en tu Presupuesto."
        ct.interruptionLevel = .passive
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "centro.pago.\(UUID().uuidString)", content: ct, trigger: nil))
        return .result()
    }
}

import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// «Compartir → Centro» desde Pinterest, Instagram, Safari…: guarda la receta en tu Cocina.
/// Aquí solo se lee la página; tu Centro la pasa a español y a gramos al abrirlo.
final class VistaCompartir: UIViewController {
    private let estado = EstadoCompartir()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        let host = UIHostingController(rootView: PantallaCompartir(estado: estado) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.didMove(toParent: self)
        Task { await procesar() }
    }

    private func procesar() async {
        var url: URL?
        var texto = ""
        for item in (extensionContext?.inputItems as? [NSExtensionItem]) ?? [] {
            if let t = item.attributedContentText?.string { texto += t + "\n" }
            for p in item.attachments ?? [] {
                if p.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let u = try? await p.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL, url == nil {
                    url = u
                } else if p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                          let t = try? await p.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                    texto += t + "\n"
                }
            }
        }
        if url == nil, let d = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
           let m = d.firstMatch(in: texto, range: NSRange(texto.startIndex..., in: texto)) {
            url = m.url
        }

        await MainActor.run { estado.paso = "Leyendo la receta…" }
        var titulo = "", cuerpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url {
            let r = await LectorRecetas.leer(url)
            titulo = r.titulo
            if !r.texto.isEmpty { cuerpo = r.texto + (cuerpo.isEmpty ? "" : "\n\n" + cuerpo) }
        }
        if titulo.isEmpty { titulo = cuerpo.split(separator: "\n").first.map(String.init) ?? "Receta" }

        guard !cuerpo.isEmpty || url != nil else {
            await MainActor.run { estado.fin(ok: false, "No he encontrado ninguna receta aquí.") }
            return
        }
        if !Almacen.shared.permiso { _ = await Almacen.shared.pedirPermiso() }
        do {
            try Almacen.shared.apuntarReceta(url: url?.absoluteString ?? "", titulo: titulo, texto: cuerpo)
            await MainActor.run { estado.fin(ok: true, titulo) }
        } catch {
            await MainActor.run { estado.fin(ok: false, "Abre la app Centro una vez y vuelve a probar.") }
        }
    }
}

final class EstadoCompartir: ObservableObject {
    @Published var paso = "Un momento…"
    @Published var listo = false
    @Published var ok = false
    @Published var detalle = ""
    func fin(ok: Bool, _ d: String) {
        withAnimation { self.ok = ok; self.detalle = d; self.listo = true }
    }
}

struct PantallaCompartir: View {
    @ObservedObject var estado: EstadoCompartir
    let cerrar: () -> Void

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 14) {
                if estado.listo {
                    Text(estado.ok ? "🍽️" : "😕").font(.system(size: 44))
                    Text(estado.ok ? "¡Receta guardada!" : "No se ha podido guardar")
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(Color.tinta)
                    Text(estado.ok ? "«\(estado.detalle)»\nTu Centro la pasa a español y a gramos y la deja en Cocina → Por probar."
                                   : estado.detalle)
                        .font(.system(size: 14.5)).foregroundStyle(Color.gris).multilineTextAlignment(.center)
                    BotonGrande(texto: "Listo", accion: cerrar)
                } else {
                    ProgressView().tint(Color.rosa).scaleEffect(1.3)
                    Text(estado.paso).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.tinta)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 26).fill(Color.fondo))
            .padding(14)
        }
        .onChange(of: estado.listo) { _, l in
            if l && estado.ok { DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { cerrar() } }
        }
    }
}

struct BotonGrande: View {
    let texto: String
    let accion: () -> Void
    var body: some View {
        Button(action: accion) {
            Text(texto).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.rosa))
        }
        .buttonStyle(.plain)
    }
}

/// Lee una página de receta: datos «Recipe» si los tiene; si no, título y descripción.
enum LectorRecetas {
    static let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    static func html(_ u: URL) async -> String? {
        var r = URLRequest(url: u, timeoutInterval: 15)
        r.setValue(ua, forHTTPHeaderField: "User-Agent")
        r.setValue("es-ES,es;q=0.9,en;q=0.6", forHTTPHeaderField: "Accept-Language")
        guard let (d, _) = try? await URLSession.shared.data(for: r) else { return nil }
        return String(data: d, encoding: .utf8) ?? String(data: d, encoding: .isoLatin1)
    }

    static func leer(_ u: URL) async -> (titulo: String, texto: String) {
        guard var h = await html(u) else { return ("", "") }
        // Pinterest: el pin apunta a la receta de verdad
        if (u.host ?? "").contains("pinterest") || (u.host ?? "").contains("pin.it") {
            if let l = primero(#""link":"(https?:\\?/\\?/[^"]+)""#, en: h)?.replacingOccurrences(of: "\\/", with: "/"),
               !l.contains("pinterest"), let lu = URL(string: l), let h2 = await html(lu) {
                let r = receta(h2)
                if !r.texto.isEmpty { return r }
                h += h2
            }
        }
        let r = receta(h)
        if !r.texto.isEmpty { return r }
        let t = meta("og:title", h) ?? primero(#"<title[^>]*>(.*?)</title>"#, en: h) ?? ""
        let d = meta("og:description", h) ?? meta("description", h) ?? ""
        return (limpiar(t), limpiar(d))
    }

    static func receta(_ h: String) -> (titulo: String, texto: String) {
        for bloque in todos(#"<script[^>]*application/ld\+json[^>]*>(.*?)</script>"#, en: h) {
            guard let d = bloque.data(using: .utf8), let j = try? JSONSerialization.jsonObject(with: d) else { continue }
            if let r = buscarReceta(j) {
                var t: [String] = []
                let nombre = r["name"] as? String ?? ""
                if let y = r["recipeYield"] { t.append("Raciones: \(y)") }
                if let ing = r["recipeIngredient"] as? [String] { t.append("Ingredientes:\n- " + ing.joined(separator: "\n- ")) }
                var pasos: [String] = []
                func pasosDe(_ x: Any) {
                    if let s = x as? String { pasos.append(s) }
                    else if let a = x as? [Any] { a.forEach(pasosDe) }
                    else if let o = x as? [String: Any] {
                        if let tx = o["text"] as? String { pasos.append(tx) }
                        if let el = o["itemListElement"] { pasosDe(el) }
                    }
                }
                if let ins = r["recipeInstructions"] { pasosDe(ins) }
                if !pasos.isEmpty { t.append("Pasos:\n" + pasos.enumerated().map { "\($0.offset + 1). \(limpiar($0.element))" }.joined(separator: "\n")) }
                return (limpiar(nombre), t.joined(separator: "\n\n"))
            }
        }
        return ("", "")
    }

    static func buscarReceta(_ j: Any) -> [String: Any]? {
        if let o = j as? [String: Any] {
            let tipo = o["@type"]
            if (tipo as? String) == "Recipe" || ((tipo as? [String])?.contains("Recipe") ?? false) { return o }
            if let g = o["@graph"] { return buscarReceta(g) }
        }
        if let a = j as? [Any] { for x in a { if let r = buscarReceta(x) { return r } } }
        return nil
    }

    static func meta(_ nombre: String, _ h: String) -> String? {
        primero("<meta[^>]+(?:property|name)=[\"']\(NSRegularExpression.escapedPattern(for: nombre))[\"'][^>]+content=[\"']([^\"']*)[\"']", en: h)
            ?? primero("<meta[^>]+content=[\"']([^\"']*)[\"'][^>]+(?:property|name)=[\"']\(NSRegularExpression.escapedPattern(for: nombre))[\"']", en: h)
    }

    static func primero(_ patron: String, en s: String) -> String? { todos(patron, en: s).first }

    static func todos(_ patron: String, en s: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: patron, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
        return re.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap {
            $0.numberOfRanges > 1 ? Range($0.range(at: 1), in: s).map { String(s[$0]) } : nil
        }
    }

    static func limpiar(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        for (a, b) in [("&amp;", "&"), ("&quot;", "\""), ("&#39;", "'"), ("&#x27;", "'"), ("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">")] {
            t = t.replacingOccurrences(of: a, with: b)
        }
        return t.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

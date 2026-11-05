import SwiftUI
import EventKit
import WidgetKit
import UIKit
import WebKit

let urlCentro = URL(string: "https://claude.ai/artifact/UQyDm4sV8C5uj9dxeB77Uu")!

@main
struct CentroApp: App {
    var body: some Scene {
        WindowGroup { Raiz() }
    }
}

/// La app entera es tu Centro (la misma web, pero dentro de la app),
/// y además da permiso al widget para leer y tachar.
struct Raiz: View {
    @State private var permiso = Almacen.shared.permiso
    @Environment(\.scenePhase) private var fase

    var body: some View {
        ZStack(alignment: .top) {
            Color.fondo.ignoresSafeArea()
            WebCentro(url: urlCentro)
                .ignoresSafeArea(edges: .bottom)

            if !permiso {
                bannerPermiso
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear { permiso = Almacen.shared.permiso }
        .onChange(of: fase) { _, f in
            if f == .active { permiso = Almacen.shared.permiso }
            if f == .background { WidgetCenter.shared.reloadAllTimelines() }
        }
    }

    var bannerPermiso: some View {
        HStack(spacing: 10) {
            Image(systemName: "checklist").foregroundStyle(Color.rosa)
            Text("Para que el widget pueda tachar, dale permiso al calendario.")
                .font(.system(size: 13))
                .foregroundStyle(Color.tinta)
            Spacer(minLength: 4)
            Button {
                Task {
                    _ = await Almacen.shared.pedirPermiso()
                    withAnimation { permiso = Almacen.shared.permiso }
                    WidgetCenter.shared.reloadAllTimelines()
                }
            } label: {
                Text("Dar permiso").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(Color.rosa))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.papel).shadow(color: .black.opacity(0.12), radius: 10, y: 4))
    }
}

/// Navegador de la app, con la sesión de Claude guardada.
struct WebCentro: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinador { Coordinador() }

    func makeUIView(context: Context) -> WKWebView {
        let conf = WKWebViewConfiguration()
        conf.websiteDataStore = .default()          // se queda con tu sesión
        conf.allowsInlineMediaPlayback = true
        conf.mediaTypesRequiringUserActionForPlayback = []
        let web = WKWebView(frame: .zero, configuration: conf)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.isOpaque = false
        web.backgroundColor = UIColor(Color.fondo)
        web.scrollView.backgroundColor = UIColor(Color.fondo)
        context.coordinator.web = web
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}

    final class Coordinador: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var web: WKWebView?

        // Enlaces que abren otra ventana (inicio de sesión, etc.): dentro de la misma app.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let u = navigationAction.request.url {
                if esDeClaude(u) { webView.load(URLRequest(url: u)) } else { UIApplication.shared.open(u) }
            }
            return nil
        }

        // Lo que no es de Claude (WhatsApp, Notion, Google Calendar…) se abre fuera, en su app.
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let u = navigationAction.request.url else { return decisionHandler(.allow) }
            let esquema = u.scheme?.lowercased() ?? ""
            if esquema != "http" && esquema != "https" && esquema != "about" && esquema != "blob" && esquema != "data" {
                UIApplication.shared.open(u)
                return decisionHandler(.cancel)
            }
            if navigationAction.targetFrame?.isMainFrame == true && navigationAction.navigationType == .linkActivated && !esDeClaude(u) {
                UIApplication.shared.open(u)
                return decisionHandler(.cancel)
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            presentar(UIAlertController(title: nil, message: message, preferredStyle: .alert), ok: completionHandler)
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { _ in completionHandler(false) })
            a.addAction(UIAlertAction(title: "Aceptar", style: .default) { _ in completionHandler(true) })
            raiz()?.present(a, animated: true)
        }

        private func presentar(_ a: UIAlertController, ok: @escaping () -> Void) {
            a.addAction(UIAlertAction(title: "Aceptar", style: .default) { _ in ok() })
            if let r = raiz() { r.present(a, animated: true) } else { ok() }
        }

        private func raiz() -> UIViewController? {
            let escena = UIApplication.shared.connectedScenes.first as? UIWindowScene
            var v = escena?.keyWindow?.rootViewController
            while let p = v?.presentedViewController { v = p }
            return v
        }

        private func esDeClaude(_ u: URL) -> Bool {
            let h = (u.host ?? "").lowercased()
            return h.hasSuffix("claude.ai") || h.hasSuffix("anthropic.com") || h.hasSuffix("claudeusercontent.com")
                || h.hasSuffix("claude.site") || h.hasSuffix("accounts.google.com") || h.hasSuffix("appleid.apple.com")
        }
    }
}

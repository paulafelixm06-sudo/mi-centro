import SwiftUI
import EventKit
import WidgetKit
import UIKit
import WebKit

let urlCentro = URL(string: "https://claude.ai/artifact/UQyDm4sV8C5uj9dxeB77Uu")!

@main
struct CentroApp: App {
    @UIApplicationDelegateAdaptor(Delegado.self) var delegado

    var body: some Scene {
        WindowGroup { Raiz() }
            .backgroundTask(.appRefresh(Estado.refresco)) {
                // de vez en cuando, aunque no abras la app: avisos, número del icono y «Lo siguiente» al día
                await Estado.shared.ponerAlDia(crearActividad: false)
                await MainActor.run { Estado.shared.programarRefresco() }
            }
    }
}

/// La app entera es tu Centro (la misma web, pero dentro de la app),
/// y además da permiso al widget para leer y tachar.
struct Raiz: View {
    @State private var permiso = Almacen.shared.permiso
    @State private var cargando = true
    @StateObject private var estado = Estado.shared
    @Environment(\.scenePhase) private var fase

    var body: some View {
        ZStack(alignment: .top) {
            Color.fondo.ignoresSafeArea()
            WebCentro(url: urlCentro, cargando: $cargando)
                .ignoresSafeArea(edges: .bottom)

            if cargando {
                Portada().transition(.opacity)
            }

            if !permiso && !cargando {
                bannerPermiso
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            permiso = Almacen.shared.permiso
            Task {
                await Avisos.pedirPermiso()
                await estado.ponerAlDia(crearActividad: true)
            }
        }
        .onChange(of: fase) { _, f in
            if f == .active {
                permiso = Almacen.shared.permiso
                Task { await estado.ponerAlDia(crearActividad: true) }
            }
            if f == .inactive {
                // justo al salir: «Lo siguiente» a la pantalla de bloqueo
                Task { await Vivo.actualizar(Agenda.cargar(), crear: true) }
            }
            if f == .background {
                WidgetCenter.shared.reloadAllTimelines()
                estado.programarRefresco()
            }
        }
        .onChange(of: cargando) { _, c in
            if !c && !UserDefaults.standard.bool(forKey: Novedades.version) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { estado.novedades = true }
            }
        }
        .onOpenURL { u in
            if u.host == "novedades" { estado.novedades = true }
            else if let h = Hoja(url: u) { estado.hoja = h }
        }
        .sheet(item: $estado.hoja) { h in
            Group {
                switch h {
                case .nueva: HojaNueva()
                case .gasto: HojaDinero(ingreso: false)
                case .ingreso: HojaDinero(ingreso: true)
                case .comida: HojaComida()
                case .compra: HojaCompra()
                }
            }
            .presentationDetents(h == .nueva ? [.medium, .large] : [.large])
            .presentationCornerRadius(28)
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $estado.novedades) { Novedades() }
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

/// Pantalla rosa con tu casita mientras se abre el Centro.
struct Portada: View {
    @State private var latido = false
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#dc8ca0"), Color(hex: "#bc627a")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "house")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.white)
                    .scaleEffect(latido ? 1.06 : 0.96)
                Text("Centro de Paula")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { latido = true } }
    }
}

/// Esconde la barra de Claude: el Centro ocupa toda la pantalla, como una app.
/// Si Claude enseña un aviso o una pregunta (permisos, etc.), se deja ver para poder contestar.
let scriptPantallaCompleta = """
(function(){
  var listo = false;
  function avisar(m){ try{ window.webkit.messageHandlers.centro.postMessage(m) }catch(e){} }
  function grande(){
    var best=null, area=0;
    document.querySelectorAll('iframe').forEach(function(f){
      var r=f.getBoundingClientRect(), a=r.width*r.height;
      if(f.dataset.centro==='1'){ a=Infinity }
      if(a>area){ area=a; best=f }
    });
    return area>20000 ? best : null;
  }
  function hayDialogo(){
    var d=document.querySelectorAll('[role="dialog"],[role="alertdialog"],[aria-modal="true"]');
    for(var i=0;i<d.length;i++){ var r=d[i].getBoundingClientRect(); if(r.width>0&&r.height>0) return true }
    return false;
  }
  var PROPS=['position','top','left','right','bottom','width','height','max-width','max-height','z-index','border','border-radius','margin'];
  function quitar(f){ PROPS.forEach(function(p){ f.style.removeProperty(p) }) }
  function poner(f){
    var v={position:'fixed',top:'0',left:'0',right:'0',bottom:'0',width:'100%',height:'100%','max-width':'none','max-height':'none','z-index':'2147483646',border:'0','border-radius':'0',margin:'0'};
    for(var k in v){ f.style.setProperty(k, v[k], 'important') }
    var p=f.parentElement;
    while(p && p!==document.body){
      var cs=getComputedStyle(p);
      if(cs.transform!=='none'){ p.style.setProperty('transform','none','important') }
      if(cs.filter!=='none'){ p.style.setProperty('filter','none','important') }
      if(cs.contain && cs.contain!=='none'){ p.style.setProperty('contain','none','important') }
      p=p.parentElement;
    }
  }
  function arreglar(){
    document.documentElement.style.setProperty('background','#fbf4f3','important');
    if(!/\\/artifact\\//.test(location.pathname)){ avisar('web'); return }
    var f=grande(); if(!f) return;
    f.dataset.centro='1';
    if(hayDialogo()){ quitar(f); return }
    poner(f);
    if(!listo){ listo=true; setTimeout(function(){ avisar('listo') }, 600) }
  }
  setInterval(arreglar, 500);
  document.addEventListener('DOMContentLoaded', arreglar);
})();
"""

/// En cada «ventanita» de dentro: si llega el aviso «refrescar» (cosas nuevas del iPhone), se pasa hacia dentro
/// hasta que llega a tu Centro, que las recoge al momento.
let scriptReenviar = """
(function(){
  if(window.__centroFw) return; window.__centroFw = 1;
  window.addEventListener('message', function(e){
    var d = e.data;
    if(!d || d.centro !== 'refrescar' || e.source === window) return;
    var fs = document.querySelectorAll('iframe');
    for(var i=0;i<fs.length;i++){ try{ fs[i].contentWindow.postMessage({centro:'refrescar'}, '*') }catch(x){} }
  });
})();
"""

/// Navegador de la app, con la sesión de Claude guardada.
struct WebCentro: UIViewRepresentable {
    let url: URL
    @Binding var cargando: Bool

    func makeCoordinator() -> Coordinador { Coordinador(cargando: $cargando) }

    func makeUIView(context: Context) -> WKWebView {
        let conf = WKWebViewConfiguration()
        conf.websiteDataStore = .default()          // se queda con tu sesión
        conf.allowsInlineMediaPlayback = true
        conf.mediaTypesRequiringUserActionForPlayback = []
        conf.userContentController.addUserScript(WKUserScript(source: scriptPantallaCompleta, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        conf.userContentController.addUserScript(WKUserScript(source: scriptReenviar, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        conf.userContentController.add(context.coordinator, name: "centro")
        let web = WKWebView(frame: .zero, configuration: conf)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.isOpaque = false
        web.backgroundColor = UIColor(Color.fondo)
        web.scrollView.backgroundColor = UIColor(Color.fondo)
        context.coordinator.web = web
        Estado.shared.web = web
        web.load(URLRequest(url: url))
        // por si algo tarda: la portada no se queda nunca más de 10 segundos
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { context.coordinator.quitarPortada() }
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}

    final class Coordinador: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        weak var web: WKWebView?
        var cargando: Binding<Bool>
        init(cargando: Binding<Bool>) { self.cargando = cargando }

        func quitarPortada() {
            DispatchQueue.main.async {
                if self.cargando.wrappedValue { withAnimation(.easeOut(duration: 0.35)) { self.cargando.wrappedValue = false } }
            }
        }

        // «listo» = tu Centro ya se ve a pantalla completa; «web» = otra página (por ejemplo, iniciar sesión)
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if let m = message.body as? String, m == "listo" || m == "web" { quitarPortada() }
        }

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

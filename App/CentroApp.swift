import SwiftUI
import EventKit
import WidgetKit
import UIKit

let urlCentro = URL(string: "https://claude.ai/artifact/UQyDm4sV8C5uj9dxeB77Uu")!

@main
struct CentroApp: App {
    var body: some Scene {
        WindowGroup { Inicio() }
    }
}

struct Inicio: View {
    @State private var agenda = Agenda()
    @State private var permiso = Almacen.shared.permiso
    @State private var aviso: String?
    @Environment(\.scenePhase) private var fase

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.fondo.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    cabecera
                    if !permiso {
                        bloquePermiso
                    } else if !agenda.hay {
                        nota("Abre tu Centro un momento (el botón de abajo) para que lleguen aquí tus tareas.")
                    } else {
                        if let s = agenda.siguiente { tarjetaSiguiente(s) }
                        seccion("Hoy", agenda.hoy, vacio: "Nada más por hoy ✨")
                        if !agenda.manana.isEmpty { seccion("Mañana", agenda.manana, vacio: "") }
                        if !agenda.recien.isEmpty { seccionRecien }
                    }
                    Spacer(minLength: 90)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
            .refreshable { recargar() }

            Link(destination: urlCentro) {
                HStack(spacing: 8) {
                    Image(systemName: "house")
                    Text("Abrir mi Centro").fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22).padding(.vertical, 14)
                .background(Capsule().fill(Color.rosa))
                .shadow(color: Color.rosa.opacity(0.35), radius: 10, y: 4)
            }
            .padding(.bottom, 12)

            if let a = aviso {
                Text(a)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(Color.tarjeta))
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear { recargar() }
        .onChange(of: fase) { _, f in if f == .active { recargar() } }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in recargar() }
    }

    // MARK: piezas

    var cabecera: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Fechas.titulo(Date()))
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color.tinta)
            Text(agenda.hay ? (agenda.hoy.isEmpty ? "Todo hecho por hoy ✨" : "\(agenda.hoy.count) por hacer hoy") : " ")
                .font(.system(size: 15))
                .foregroundStyle(Color.gris)
        }
    }

    var bloquePermiso: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Para ver y tachar tus cosas, la app necesita mirar tu calendario.")
                .foregroundStyle(Color.tinta)
            Button {
                Task {
                    _ = await Almacen.shared.pedirPermiso()
                    permiso = Almacen.shared.permiso
                    recargar()
                }
            } label: {
                Text("Dar permiso").fontWeight(.semibold).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Capsule().fill(Color.rosa))
            }
            Text("Si ya dijiste que no: Ajustes → Centro → Calendarios → Acceso total.")
                .font(.footnote).foregroundStyle(Color.gris)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.papel))
    }

    func nota(_ t: String) -> some View {
        Text(t).foregroundStyle(Color.gris).padding(.vertical, 8)
    }

    func tarjetaSiguiente(_ it: Item) -> some View {
        let n = Fechas.ahoraMin(), a = Fechas.minutos(it.ini)
        let fin = it.fin.isEmpty ? it.ini : it.fin
        return HStack(spacing: 14) {
            casilla(it, tam: 26, blanca: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(a <= n ? "AHORA · HASTA LAS \(fin)" : "LO SIGUIENTE · EN \(Fechas.duracion(a - n).uppercased())")
                    .font(.system(size: 11, weight: .semibold)).opacity(0.75)
                Text(it.titulo).font(.system(size: 17, weight: .semibold))
                Text("\(it.ini) – \(fin)" + (it.lista.isEmpty ? "" : " · \(it.lista)"))
                    .font(.system(size: 13)).opacity(0.75)
            }
            .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.tarjeta))
    }

    func seccion(_ titulo: String, _ xs: [Item], vacio: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo.uppercased())
                .font(.system(size: 12, weight: .semibold)).tracking(0.8)
                .foregroundStyle(Color.gris)
            if xs.isEmpty && !vacio.isEmpty {
                Text(vacio).foregroundStyle(Color.gris)
            }
            ForEach(xs) { it in
                HStack(spacing: 12) {
                    casilla(it, tam: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(it.titulo).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(Color.tinta)
                        let sub = subtitulo(it)
                        if !sub.isEmpty { Text(sub).font(.system(size: 12.5)).foregroundStyle(Color.gris) }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.papel))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.linea, lineWidth: 1))
            }
        }
    }

    var seccionRecien: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TACHADO AQUÍ · LLEGARÁ A TU CENTRO AL ABRIRLO")
                .font(.system(size: 11, weight: .semibold)).tracking(0.6)
                .foregroundStyle(Color.gris)
            ForEach(agenda.recien) { it in
                HStack {
                    Text(it.titulo).strikethrough().foregroundStyle(Color.gris)
                    Spacer()
                    Button("Deshacer") { destachar(it) }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.rosa)
                }
            }
        }
    }

    func casilla(_ it: Item, tam: CGFloat, blanca: Bool = false) -> some View {
        Button { tachar(it) } label: {
            ZStack {
                if it.esTarea {
                    RoundedRectangle(cornerRadius: tam * 0.3).strokeBorder(blanca ? Color.white : Color(hex: it.colorHex), lineWidth: 2)
                } else {
                    Circle().strokeBorder(blanca ? Color.white : Color(hex: it.colorHex), lineWidth: 2)
                }
            }
            .frame(width: tam, height: tam)
            .contentShape(Rectangle().inset(by: -8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tachar \(it.titulo)")
    }

    // MARK: acciones

    func recargar() {
        permiso = Almacen.shared.permiso
        if permiso { agenda = Agenda.cargar() }
    }

    func tachar(_ it: Item) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        do {
            try Almacen.shared.tachar(id: it.id, tipo: it.tipo, fecha: it.fecha)
            withAnimation { recargar() }
            WidgetCenter.shared.reloadAllTimelines()
            mostrar("✅ Tachada")
        } catch {
            mostrar(error.localizedDescription)
        }
    }

    func destachar(_ it: Item) {
        try? Almacen.shared.destachar(id: it.id)
        withAnimation { recargar() }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func mostrar(_ t: String) {
        withAnimation { aviso = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { if aviso == t { aviso = nil } } }
    }
}

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

/// «Lo siguiente» en la pantalla de bloqueo y en la isla de arriba.
struct SiguienteActividad: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SiguienteAtributos.self) { ctx in
            VistaBloqueo(ctx: ctx)
                .activityBackgroundTint(Color(hex: "#2e2027").opacity(0.94))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { ctx in
            let s = ctx.state
            let ahora = estaPasando(ctx)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: s.colorHex)).frame(width: 9, height: 9)
                        Text(ahora ? "AHORA" : "LO SIGUIENTE").font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Cuenta(ctx: ctx).font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: s.colorHex)).padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(s.titulo).font(.system(size: 17, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                        HStack {
                            Text(rango(s) + (s.lista.isEmpty ? "" : " · \(s.lista)"))
                                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                            Spacer()
                            BotonHecho(s: s)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: s.colorHex)).frame(width: 8, height: 8)
                    Text(s.titulo).font(.system(size: 12, weight: .semibold)).lineLimit(1).frame(maxWidth: 70)
                }
            } compactTrailing: {
                Cuenta(ctx: ctx).font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: s.colorHex)).frame(maxWidth: 46)
            } minimal: {
                Circle().fill(Color(hex: s.colorHex)).frame(width: 10, height: 10)
            }
            .keylineTint(Color(hex: s.colorHex))
        }
    }
}

/// ¿Ya ha empezado? (si el iPhone no ha podido actualizarlo, nos fijamos en si está «caducado»)
func estaPasando(_ ctx: ActivityViewContext<SiguienteAtributos>) -> Bool {
    ctx.state.empezada || ctx.isStale || ctx.state.inicio <= Date()
}

func rango(_ s: SiguienteAtributos.ContentState) -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return "\(f.string(from: s.inicio)) – \(f.string(from: s.fin))"
}

/// Sin cuentas atrás (agobian): solo a qué hora empieza o hasta cuándo dura.
struct Cuenta: View {
    let ctx: ActivityViewContext<SiguienteAtributos>
    var body: some View {
        let s = ctx.state
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return Text(estaPasando(ctx) ? "hasta \(f.string(from: s.fin))" : f.string(from: s.inicio))
            .monospacedDigit().multilineTextAlignment(.trailing)
    }
}

struct BotonHecho: View {
    let s: SiguienteAtributos.ContentState
    var body: some View {
        Button(intent: HechoActividadIntent(id: s.id, tipo: s.tipo, fecha: s.fecha)) {
            Label("Hecho", systemImage: "checkmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(Color(hex: s.colorHex)))
        }
        .buttonStyle(.plain)
    }
}

struct VistaBloqueo: View {
    let ctx: ActivityViewContext<SiguienteAtributos>
    var body: some View {
        let s = ctx.state
        let ahora = estaPasando(ctx)
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: s.colorHex)).frame(width: 5)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(ahora ? "AHORA" : "A LAS").font(.system(size: 10.5, weight: .bold)).foregroundStyle(.white.opacity(0.6))
                }
                Text(s.titulo).font(.system(size: 17, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                Text(rango(s) + (s.lista.isEmpty ? "" : " · \(s.lista)"))
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                if !s.despues.isEmpty {
                    Text("Luego: " + s.despues).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 8) {
                Cuenta(ctx: ctx).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    .frame(maxWidth: 90, alignment: .trailing)
                BotonHecho(s: s)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

// MARK: - ⏱ foco (pomodoro)

struct FocoActividad: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocoAtributos.self) { ctx in
            VistaFoco(s: ctx.state, caducado: ctx.isStale)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .activityBackgroundTint(Color(hex: "#2e2027").opacity(0.94))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { ctx in
            let s = ctx.state
            let color = s.fase == "descanso" ? Color(hex: "#7fb8a4") : Color(hex: "#e29aae")
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(s.fase == "descanso" ? "☕ DESCANSO" : "⏱ FOCO").font(.system(size: 11, weight: .bold))
                        .foregroundStyle(color).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CuentaFoco(s: s).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(.white).padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(s.titulo.isEmpty ? (s.fase == "descanso" ? "Respira, estira, bebe agua" : "Sesión de foco") : s.titulo)
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: s.fase == "descanso" ? "cup.and.saucer.fill" : "timer").foregroundStyle(color)
            } compactTrailing: {
                CuentaFoco(s: s).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(color).frame(maxWidth: 46)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(color)
            }
            .keylineTint(color)
        }
    }
}

struct CuentaFoco: View {
    let s: FocoAtributos.ContentState
    var body: some View {
        if s.enPausa {
            Text(String(format: "%d:%02d", s.quedanSeg / 60, s.quedanSeg % 60)).monospacedDigit()
        } else if s.fin > Date() {
            Text(timerInterval: Date()...s.fin, countsDown: true).monospacedDigit().multilineTextAlignment(.trailing)
        } else {
            Text("¡ya!")
        }
    }
}

struct VistaFoco: View {
    let s: FocoAtributos.ContentState
    let caducado: Bool
    var body: some View {
        let color = s.fase == "descanso" ? Color(hex: "#7fb8a4") : Color(hex: "#e29aae")
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(color.opacity(0.25), lineWidth: 5)
                if !s.enPausa && s.fin > Date() {
                    ProgressView(timerInterval: s.fin.addingTimeInterval(TimeInterval(-s.minutos * 60))...s.fin, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                        .progressViewStyle(.circular).tint(color)
                }
                Image(systemName: s.fase == "descanso" ? "cup.and.saucer.fill" : "timer").font(.system(size: 16, weight: .semibold)).foregroundStyle(color)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(caducado ? "¡TIEMPO!" : s.enPausa ? "EN PAUSA" : s.fase == "descanso" ? "DESCANSO" : "FOCO")
                    .font(.system(size: 10.5, weight: .bold)).foregroundStyle(.white.opacity(0.6))
                Text(s.titulo.isEmpty ? (s.fase == "descanso" ? "Respira, estira, bebe agua" : "Sesión de foco") : s.titulo)
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(.white).lineLimit(1)
            }
            Spacer(minLength: 4)
            CuentaFoco(s: s).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(.white).frame(maxWidth: 100, alignment: .trailing)
        }
    }
}

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

/// Cuenta atrás: hasta que empieza, o hasta que termina.
struct Cuenta: View {
    let ctx: ActivityViewContext<SiguienteAtributos>
    var body: some View {
        let s = ctx.state
        let objetivo = estaPasando(ctx) ? s.fin : s.inicio
        let ya = Date()
        if objetivo > ya {
            Text(timerInterval: ya...objetivo, countsDown: true).monospacedDigit().multilineTextAlignment(.trailing)
        } else {
            Text("ya").monospacedDigit()
        }
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
                    Text(ahora ? "AHORA" : "LO SIGUIENTE").font(.system(size: 10.5, weight: .bold)).foregroundStyle(.white.opacity(0.6))
                    if !ahora {
                        Text("·").foregroundStyle(.white.opacity(0.4))
                        Text("empieza en").font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.6))
                    }
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

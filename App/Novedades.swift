import SwiftUI

/// Lo nuevo de la app, explicado paso a paso. Sale sola la primera vez que abres esta versión
/// (y cuando quieras desde centro://novedades).
struct Novedades: View {
    @Environment(\.dismiss) var cerrar
    @State private var pagina = 0
    static let version = "novedades-2"

    struct Pagina {
        let emoji: String
        let titulo: String
        let texto: String
        let truco: String
        let dibujo: AnyView
    }

    var paginas: [Pagina] { [
        Pagina(emoji: "🎁", titulo: "¡Tu Centro ha crecido!",
               texto: "Te enseño en un minuto todo lo nuevo para que le saques partido. Desliza para pasar.",
               truco: "Para volver a verlo cuando quieras: «Oye Siri, novedades de Centro».",
               dibujo: AnyView(DibujoPortada())),
        Pagina(emoji: "🔔", titulo: "Avisos con botones",
               texto: "Cuando empieza algo te llega un aviso. Sin abrir nada, puedes marcarlo como hecho, que te lo recuerde en 15 minutos o pasarlo a mañana.",
               truco: "Además: «Buenos días» a las 8:30, «¿Cerramos el día?» a las 21:00 y la revisión del viernes a las 18:30. Para no tener avisos repetidos, apaga los de Google Calendar: Ajustes → Notificaciones → Google Calendar (y Calendario).",
               dibujo: AnyView(DibujoAviso())),
        Pagina(emoji: "⏳", titulo: "«Lo siguiente», siempre a la vista",
               texto: "Cuando falten menos de 2 horas para algo, aparece en la pantalla de bloqueo y arriba, en la isla, con la cuenta atrás. Tócalo en «Hecho» y listo.",
               truco: "Si no lo ves: Ajustes → Centro → Actividades en vivo → activado.",
               dibujo: AnyView(DibujoIsla())),
        Pagina(emoji: "🔴", titulo: "El numerito del icono",
               texto: "El icono de la app te dice cuántas cosas te quedan hoy. Va bajando según tachas.",
               truco: "Es tu marcador del día: el objetivo es dejarlo a cero 😉",
               dibujo: AnyView(DibujoIcono())),
        Pagina(emoji: "🧩", titulo: "5 widgets nuevos",
               texto: "«Mi día» con anillo de progreso y racha 🔥, «Hábitos» para marcarlos con un toque, «Menú de hoy», «Lista de la compra» y «Presupuesto» con ＋ para gastos e ingresos.",
               truco: "Para ponerlos: mantén pulsada la pantalla de inicio → «Editar» → «Añadir widget» → busca «Centro». Si los antiguos se ven raros, quítalos y ponlos otra vez.",
               dibujo: AnyView(DibujoWidgets())),
        Pagina(emoji: "⚡️", titulo: "Apuntar en 2 segundos",
               texto: "Mantén pulsado el icono de Centro: «Nueva tarea», «Gasto o ingreso», «Añadir comida» y «Compra». También desde el ＋ de los widgets.",
               truco: "Con Siri: «Oye Siri, apunta en Centro», «Gasto en Centro», «Añade a la compra en Centro» o «Qué me toca en Centro».",
               dibujo: AnyView(DibujoMenuIcono())),
        Pagina(emoji: "🔁", titulo: "Tu rutina, en beige",
               texto: "En la vista «Día» del calendario ves tu rutina en beige, discreta, para saber tus huecos de verdad. Puedes moverla o quitarla de ese día, y nunca te avisa.",
               truco: "Para crear una rutina nueva: al apuntar algo, toca «⋯» → «Es rutina» (o el interruptor en la app).",
               dibujo: AnyView(DibujoRutina())),
        Pagina(emoji: "🎉", titulo: "Cada logro se celebra",
               texto: "Al tachar te sale una frase distinta cada vez, y cuando terminas el día… ¡confeti! Tu racha de días seguidos sale en el widget.",
               truco: "Pequeños pasos cada día suman mucho más que un día perfecto. ¡A por ello, Paula! 💪",
               dibujo: AnyView(DibujoConfeti())),
    ] }

    var body: some View {
        let ps = paginas
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Saltar") { terminar() }
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Color.gris)
                    .opacity(pagina == ps.count - 1 ? 0 : 1)
            }
            .padding(.horizontal, 22).padding(.top, 14)

            TabView(selection: $pagina) {
                ForEach(ps.indices, id: \.self) { i in
                    VistaPagina(p: ps[i]).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 7) {
                ForEach(ps.indices, id: \.self) { i in
                    Capsule().fill(i == pagina ? Color.rosa : Color.linea)
                        .frame(width: i == pagina ? 22 : 7, height: 7)
                }
            }
            .animation(.snappy, value: pagina)
            .padding(.bottom, 16)

            BotonGrande(texto: pagina == ps.count - 1 ? "¡Empezar!" : "Siguiente") {
                if pagina == ps.count - 1 { terminar() } else { withAnimation { pagina += 1 } }
            }
            .padding(.horizontal, 22).padding(.bottom, 18)
        }
        .background(Color.fondo.ignoresSafeArea())
    }

    func terminar() {
        UserDefaults.standard.set(true, forKey: Self.version)
        cerrar()
    }
}

struct VistaPagina: View {
    let p: Novedades.Pagina
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                p.dibujo
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 28).fill(
                        LinearGradient(colors: [Color.rosa.opacity(0.16), Color.rosa.opacity(0.05)], startPoint: .top, endPoint: .bottom)))
                    .padding(.top, 8)
                Text(p.emoji + "  " + p.titulo)
                    .font(.system(size: 24, weight: .bold)).foregroundStyle(Color.tinta)
                    .multilineTextAlignment(.center)
                Text(p.texto)
                    .font(.system(size: 16.5)).foregroundStyle(Color.tinta.opacity(0.85))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: 10) {
                    Text("💡").font(.system(size: 16))
                    Text(p.truco).font(.system(size: 14)).foregroundStyle(Color.tinta.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.papel))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.linea))
            }
            .padding(.horizontal, 22)
        }
    }
}

// MARK: - dibujitos (maquetas de lo nuevo)

private let oscuro = Color(hex: "#2e2027")

struct DibujoPortada: View {
    @State private var arriba = false
    var body: some View {
        ZStack {
            ForEach(0..<5) { i in
                let iconos = ["bell.badge.fill", "square.grid.2x2.fill", "mic.fill", "cart.fill", "eurosign.circle.fill"]
                Image(systemName: iconos[i]).font(.system(size: 24)).foregroundStyle(Color.rosa.opacity(0.8))
                    .offset(x: cos(Double(i) * 1.256) * 100, y: sin(Double(i) * 1.256) * 80 + (arriba ? -4 : 4))
            }
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [Color(hex: "#dc8ca0"), Color(hex: "#bc627a")], startPoint: .top, endPoint: .bottom))
                .frame(width: 96, height: 96)
                .overlay(Image(systemName: "house").font(.system(size: 42, weight: .semibold)).foregroundStyle(.white))
                .shadow(color: Color.rosa.opacity(0.4), radius: 14, y: 8)
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.6).repeatForever()) { arriba = true } }
    }
}

struct DibujoAviso: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [Color(hex: "#dc8ca0"), Color(hex: "#bc627a")], startPoint: .top, endPoint: .bottom))
                    .frame(width: 34, height: 34)
                    .overlay(Image(systemName: "house").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 2) {
                    HStack { Text("CENTRO").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary); Spacer(); Text("ahora").font(.system(size: 11)).foregroundStyle(.secondary) }
                    Text("Llamar a mamá").font(.system(size: 14, weight: .semibold))
                    Text("Ahora · 18:30–19:00").font(.system(size: 13)).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 18).fill(.regularMaterial))
            VStack(spacing: 0) {
                ForEach(["✅ Hecho", "⏰ En 15 min", "📅 Mañana"], id: \.self) { t in
                    Text(t).font(.system(size: 14)).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.vertical, 10)
                    if t != "📅 Mañana" { Divider() }
                }
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(.regularMaterial))
            .padding(.top, 6)
        }
        .padding(.horizontal, 26)
    }
}

struct DibujoIsla: View {
    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                Circle().fill(Color(hex: "#d9a441")).frame(width: 9, height: 9)
                Text("Coger la tarta").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Text("24:12").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(Color(hex: "#d9a441"))
            }
            .padding(.horizontal, 14).frame(width: 220, height: 36)
            .background(Capsule().fill(.black))
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#d9a441")).frame(width: 5, height: 58)
                VStack(alignment: .leading, spacing: 2) {
                    Text("LO SIGUIENTE · empieza en").font(.system(size: 9.5, weight: .bold)).foregroundStyle(.white.opacity(0.6))
                    Text("Coger la tarta").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    Text("17:45 – 18:15 · Familia").font(.system(size: 11)).foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("24:12").font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("✓ Hecho").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 9).padding(.vertical, 4).background(Capsule().fill(Color(hex: "#d9a441")))
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 20).fill(oscuro))
            .padding(.horizontal, 22)
        }
    }
}

struct DibujoIcono: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(LinearGradient(colors: [Color(hex: "#dc8ca0"), Color(hex: "#bc627a")], startPoint: .top, endPoint: .bottom))
            .frame(width: 110, height: 110)
            .overlay(Image(systemName: "house").font(.system(size: 48, weight: .semibold)).foregroundStyle(.white))
            .overlay(alignment: .topTrailing) {
                Text("4").font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 38, height: 38).background(Circle().fill(Color(hex: "#ff3b30")))
                    .offset(x: 12, y: -12)
            }
    }
}

struct DibujoWidgets: View {
    var body: some View {
        let ag = Agenda.ejemplo
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    ZStack {
                        Circle().stroke(Color.rosa.opacity(0.18), lineWidth: 4)
                        Circle().trim(from: 0, to: 0.5).stroke(Color.rosa, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
                        Text("3").font(.system(size: 11, weight: .bold))
                    }
                    .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Viernes 6").font(.system(size: 12, weight: .bold))
                        Text("🔥 4 días").font(.system(size: 9)).foregroundStyle(Color.gris)
                    }
                }
                Text("EN 25 MIN\nCoger la tarta").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                    .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.tarjeta))
            }
            .foregroundStyle(Color.tinta)
            .padding(12).frame(width: 140, height: 140, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color.papel))
            VStack(alignment: .leading, spacing: 6) {
                Text("Hábitos  2/5").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.tinta)
                ForEach(ag.habitos) { h in
                    HStack(spacing: 5) {
                        Image(systemName: h.hecho ? "checkmark.circle.fill" : "circle").font(.system(size: 13)).foregroundStyle(h.hecho ? Color.rosa : Color.gris)
                        Text(h.emoji + " " + h.nombre).font(.system(size: 10.5)).foregroundStyle(Color.tinta).lineLimit(1)
                    }
                }
            }
            .padding(12).frame(width: 140, height: 140, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color.papel))
        }
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}

struct DibujoMenuIcono: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach([("Nueva tarea", "square.and.pencil"), ("Gasto o ingreso", "eurosign.circle"), ("Añadir comida", "fork.knife"), ("Compra", "cart")], id: \.0) { x in
                HStack {
                    Text(x.0).font(.system(size: 15))
                    Spacer()
                    Image(systemName: x.1).font(.system(size: 16))
                }
                .padding(.horizontal, 16).padding(.vertical, 11)
                if x.0 != "Compra" { Divider() }
            }
        }
        .foregroundStyle(Color.tinta)
        .frame(width: 240)
        .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
    }
}

struct DibujoRutina: View {
    var body: some View {
        VStack(spacing: 7) {
            fila("15:00", "Comer", rutina: true)
            fila("15:30", "Gimnasio", rutina: true)
            fila("17:30", "🛋️ Zona salón", rutina: false)
            HStack(spacing: 8) {
                Text("17:55").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.rosa).frame(width: 40, alignment: .leading)
                Text("Hueco libre · 35 min").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.rosa)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(9)
                    .background(RoundedRectangle(cornerRadius: 11).strokeBorder(Color.rosa.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4])))
            }
            fila("18:30", "🐶🐶 Paseo", rutina: true)
        }
        .padding(.horizontal, 26)
    }

    func fila(_ h: String, _ t: String, rutina: Bool) -> some View {
        HStack(spacing: 8) {
            Text(h).font(.system(size: 11, weight: .semibold)).foregroundStyle(rutina ? Color(hex: "#8a7a66") : Color.tinta).frame(width: 40, alignment: .leading)
            HStack(spacing: 6) {
                if rutina { Text("🔁").font(.system(size: 10)).grayscale(1).opacity(0.6) }
                else { Circle().strokeBorder(Color(hex: "#7fb8a4"), lineWidth: 2).frame(width: 14, height: 14) }
                Text(t).font(.system(size: 12.5, weight: rutina ? .regular : .semibold)).foregroundStyle(rutina ? Color(hex: "#8a7a66") : Color.tinta)
                Spacer()
            }
            .padding(9)
            .background(RoundedRectangle(cornerRadius: 11).fill(rutina ? Color(hex: "#f4ede2") : Color.papel))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(rutina ? Color(hex: "#e7dccb") : Color.linea, style: StrokeStyle(lineWidth: 1, dash: rutina ? [3] : [])))
        }
    }
}

struct DibujoConfeti: View {
    @State private var cae = false
    var body: some View {
        ZStack {
            ForEach(0..<36, id: \.self) { i in
                let colores = [Color.rosa, Color(hex: "#d9a441"), Color(hex: "#7fb8a4"), Color(hex: "#8fa7e0")]
                RoundedRectangle(cornerRadius: 2).fill(colores[i % 4])
                    .frame(width: 7, height: 10)
                    .rotationEffect(.degrees(Double(i) * 37 + (cae ? 180 : 0)))
                    .offset(x: CGFloat((i * 53) % 280) - 140, y: cae ? 120 : -120 + CGFloat((i * 29) % 60))
                    .opacity(cae ? 0.2 : 1)
            }
            Text("¡Día completado! 🎉").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 11)
                .background(Capsule().fill(Color.rosa))
        }
        .clipped()
        .onAppear { withAnimation(.easeIn(duration: 2.4).repeatForever(autoreverses: false)) { cae = true } }
    }
}

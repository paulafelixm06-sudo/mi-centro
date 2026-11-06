import SwiftUI
import UIKit
import WidgetKit

// Hojas rápidas: se abren desde el ＋ de los widgets, manteniendo pulsado el icono, o desde el Centro.

// MARK: - piezas comunes

struct Chip: View {
    let texto: String
    var activo = false
    let accion: () -> Void
    var body: some View {
        Button(action: accion) {
            Text(texto)
                .font(.system(size: 13.5, weight: activo ? .semibold : .medium))
                .foregroundStyle(activo ? .white : Color.tinta)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(activo ? Color.rosa : Color.papel))
                .overlay(Capsule().strokeBorder(activo ? Color.clear : Color.linea, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct Seleccion<T: Hashable>: View {
    let opciones: [(T, String)]
    @Binding var valor: T
    var body: some View {
        HStack(spacing: 4) {
            ForEach(opciones, id: \.0) { o in
                Button {
                    withAnimation(.snappy(duration: 0.2)) { valor = o.0 }
                } label: {
                    Text(o.1).font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(valor == o.0 ? Color.tinta : Color.gris)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 11).fill(valor == o.0 ? Color.papel : Color.clear)
                            .shadow(color: .black.opacity(valor == o.0 ? 0.08 : 0), radius: 4, y: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.linea.opacity(0.7)))
    }
}

struct Etiqueta: View {
    let t: String
    var body: some View {
        Text(t.uppercased()).font(.system(size: 11, weight: .bold)).foregroundStyle(Color.gris).padding(.top, 4)
    }
}

struct BotonGrande: View {
    let texto: String
    var activo = true
    let accion: () -> Void
    var body: some View {
        Button(action: accion) {
            Text(texto).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 16).fill(activo ? Color.rosa : Color.gris.opacity(0.5)))
        }
        .buttonStyle(.plain)
        .disabled(!activo)
    }
}

struct Campo: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.papel))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.linea, lineWidth: 1))
    }
}

struct Cabecera: View {
    let titulo: String
    let emoji: String
    @Environment(\.dismiss) var cerrar
    var body: some View {
        HStack {
            Text(emoji).font(.system(size: 22))
            Text(titulo).font(.system(size: 21, weight: .bold)).foregroundStyle(Color.tinta)
            Spacer()
            Button { cerrar() } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.gris)
                    .frame(width: 30, height: 30).background(Circle().fill(Color.linea))
            }
        }
    }
}

func vibrarBien() { UINotificationFeedbackGenerator().notificationOccurred(.success) }

struct SinPermiso: View {
    var body: some View {
        Text("Primero dale permiso al calendario (en la app, arriba), que es por donde llegan tus cosas a tu Centro.")
            .font(.system(size: 13)).foregroundStyle(Color.gris)
    }
}

struct ErrorTexto: View {
    let t: String?
    var body: some View {
        if let t { Text(t).font(.system(size: 13)).foregroundStyle(Color(hex: "#d65a5a")) }
    }
}

// MARK: - Nueva tarea

struct HojaNueva: View {
    @Environment(\.dismiss) var cerrar
    @State private var texto = ""
    @State private var rutina = false
    @State private var error: String?
    @FocusState private var foco: Bool

    let sugerencias = ["hoy", "mañana", "a las 18:00", "#casa", "#personal", "#familia", "!alta", "cada día", "el lunes"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Cabecera(titulo: rutina ? "Nueva rutina" : "Nueva tarea", emoji: rutina ? "🔁" : "✏️")
            TextField("¿Qué tienes que hacer?", text: $texto, axis: .vertical)
                .font(.system(size: 18))
                .lineLimit(1...4)
                .focused($foco)
                .submitLabel(.done)
                .modifier(Campo())
            Text("Escríbelo como lo dirías: «dentista mañana a las 10 #personal !alta»")
                .font(.system(size: 12)).foregroundStyle(Color.gris)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(sugerencias, id: \.self) { s in
                        Chip(texto: s) {
                            texto = texto.trimmingCharacters(in: .whitespaces) + (texto.isEmpty ? "" : " ") + s
                        }
                    }
                }
            }
            Toggle(isOn: $rutina) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Es rutina").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.tinta)
                    Text("Solo sale en «Día», en beige, para ver tus huecos. Sin avisos.").font(.system(size: 12)).foregroundStyle(Color.gris)
                }
            }
            .tint(Color(hex: "#bfae96"))
            .modifier(Campo())
            ErrorTexto(t: error)
            if !Almacen.shared.permiso { SinPermiso() }
            Spacer(minLength: 0)
            BotonGrande(texto: rutina ? "Añadir a mi rutina" : "Apuntar", activo: !texto.trimmingCharacters(in: .whitespaces).isEmpty) {
                do {
                    try Almacen.shared.apuntar(texto, rutina: rutina)
                    vibrarBien()
                    Estado.shared.trasCambio()
                    cerrar()
                } catch { self.error = error.localizedDescription }
            }
        }
        .padding(20)
        .background(Color.fondo.ignoresSafeArea())
        .onAppear { foco = true }
    }
}

// MARK: - Gasto / ingreso

struct HojaDinero: View {
    @Environment(\.dismiss) var cerrar
    @State var ingreso: Bool
    @State private var importe = ""
    @State private var concepto = ""
    @State private var origen = "efectivo"
    @State private var categoria = ""
    @State private var fecha = Date()
    @State private var error: String?
    @FocusState private var foco: Bool

    static let gastos: [(String, String)] = [
        ("comida", "🛒 Súper"), ("ocio", "🍹 Ocio / comer fuera"), ("gasolina", "⛽️ Gasolina"),
        ("paula", "🌸 Cosas mías"), ("ramses", "👤 Cosas Ramses"), ("perras", "🐶 Perras"),
        ("regalos", "🎁 Regalos"), ("coche", "🚗 Coche"), ("suscripciones", "📺 Suscripciones"), ("imprevistos", "🧾 Otros"),
    ]
    static let ingresos: [(String, String)] = [
        ("otros_ing", "💸 Bizum / otros"), ("sueldo_paula", "👩‍💼 Mi sueldo"), ("sueldo_ramses", "👨‍💼 Sueldo Ramses"), ("extra", "✨ Extra"),
    ]

    var lista: [(String, String)] { ingreso ? Self.ingresos : Self.gastos }
    var numero: Double? {
        let t = importe.replacingOccurrences(of: "€", with: "").replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        guard let v = Double(t), v > 0 else { return nil }
        return v
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Cabecera(titulo: ingreso ? "Nuevo ingreso" : "Nuevo gasto", emoji: ingreso ? "💰" : "💸")
                Seleccion(opciones: [(false, "Gasto"), (true, "Ingreso")], valor: $ingreso)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(ingreso ? "+" : "−").font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(ingreso ? Color(hex: "#5f9e86") : Color.rosa)
                    TextField("0", text: $importe)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .focused($foco)
                        .foregroundStyle(Color.tinta)
                    Text("€").font(.system(size: 30, weight: .semibold, design: .rounded)).foregroundStyle(Color.gris)
                }
                .padding(.vertical, 4)
                TextField(ingreso ? "¿De qué? (ej.: mamá por la Switch)" : "¿En qué? (ej.: compra del día)", text: $concepto)
                    .font(.system(size: 16)).modifier(Campo())
                Etiqueta(t: "Cómo")
                Seleccion(opciones: [("efectivo", "💵 Efectivo"), ("banco", "💳 Tarjeta / banco")], valor: $origen)
                Etiqueta(t: "Categoría")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 7)], alignment: .leading, spacing: 7) {
                    ForEach(lista, id: \.0) { c in
                        Chip(texto: c.1, activo: categoria == c.0) { categoria = c.0 }
                    }
                }
                DatePicker("Día", selection: $fecha, displayedComponents: .date)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.tinta)
                    .environment(\.locale, Locale(identifier: "es_ES"))
                    .modifier(Campo())
                ErrorTexto(t: error)
                if !Almacen.shared.permiso { SinPermiso() }
                BotonGrande(texto: ingreso ? "Apuntar ingreso" : "Apuntar gasto", activo: numero != nil) {
                    guard let v = numero else { return }
                    let cat = categoria.isEmpty ? (ingreso ? "otros_ing" : "imprevistos") : categoria
                    let nombre = concepto.trimmingCharacters(in: .whitespaces)
                    let porDefecto = lista.first { $0.0 == cat }.map { String($0.1.drop { !$0.isLetter }) } ?? ""
                    do {
                        try Almacen.shared.apuntarDinero(importe: ingreso ? v : -v, concepto: nombre.isEmpty ? porDefecto : nombre,
                                                         origen: origen, categoria: cat, fecha: fecha)
                        vibrarBien()
                        Estado.shared.trasCambio()
                        cerrar()
                    } catch { self.error = error.localizedDescription }
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(Color.fondo.ignoresSafeArea())
        .onChange(of: ingreso) { _, _ in categoria = "" }
        .onAppear { foco = true }
    }
}

// MARK: - Comida

struct HojaComida: View {
    @Environment(\.dismiss) var cerrar
    @State private var plato = ""
    @State private var modo = "menu"
    @State private var momento = HojaComida.momentoAhora()
    @State private var dia = 0
    @State private var fecha = Date()
    @State private var error: String?
    @FocusState private var foco: Bool

    static func momentoAhora() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 11 ? "desayuno" : h < 16 ? "comida" : h < 19 ? "merienda" : "cena"
    }

    var fechaElegida: Date {
        dia == 2 ? fecha : (Calendar.current.date(byAdding: .day, value: dia, to: Date()) ?? Date())
    }

    let momentos: [(String, String)] = [("desayuno", "🥐 Desayuno"), ("comida", "🍝 Comida"), ("merienda", "🍎 Merienda"), ("cena", "🌙 Cena")]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Cabecera(titulo: "Añadir comida", emoji: "🍽️")
                Seleccion(opciones: [("menu", "📅 Al menú"), ("comido", "✅ Ya me la he comido")], valor: $modo)
                TextField("¿Qué plato? (ej.: lentejas con chorizo)", text: $plato)
                    .font(.system(size: 17)).focused($foco).modifier(Campo())
                Etiqueta(t: "Cuándo")
                HStack(spacing: 7) {
                    Chip(texto: "Hoy", activo: dia == 0) { dia = 0 }
                    Chip(texto: "Mañana", activo: dia == 1) { dia = 1 }
                    Chip(texto: "Otro día", activo: dia == 2) { dia = 2 }
                }
                if dia == 2 {
                    DatePicker("Día", selection: $fecha, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "es_ES")).modifier(Campo())
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 7), GridItem(.flexible(), spacing: 7)], spacing: 7) {
                    ForEach(momentos, id: \.0) { m in
                        Chip(texto: m.1, activo: momento == m.0) { momento = m.0 }
                    }
                }
                Text(modo == "menu"
                     ? "Va a tu menú de Cocina. Si ya tienes esa receta, la usa; si no, la deja en «Por probar» y calcula las calorías después."
                     : "Se apunta en «Mi comida» de ese día. Las calorías las puedes completar luego en Cocina.")
                    .font(.system(size: 12)).foregroundStyle(Color.gris)
                ErrorTexto(t: error)
                if !Almacen.shared.permiso { SinPermiso() }
                BotonGrande(texto: modo == "menu" ? "Añadir al menú" : "Apuntar comida", activo: !plato.trimmingCharacters(in: .whitespaces).isEmpty) {
                    do {
                        try Almacen.shared.apuntarComida(plato, momento: momento, fecha: fechaElegida, modo: modo)
                        vibrarBien()
                        Estado.shared.trasCambio()
                        cerrar()
                    } catch { self.error = error.localizedDescription }
                }
            }
            .padding(20)
        }
        .background(Color.fondo.ignoresSafeArea())
        .onAppear { foco = true }
    }
}

// MARK: - Lista de la compra

struct HojaCompra: View {
    @Environment(\.dismiss) var cerrar
    @State private var texto = ""
    @State private var lista: [Compra] = []
    @State private var recien: [String] = []
    @State private var error: String?
    @FocusState private var foco: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Cabecera(titulo: "Lista de la compra", emoji: "🛒")
            HStack(spacing: 8) {
                TextField("¿Qué hace falta? (ej.: 2 leches)", text: $texto)
                    .font(.system(size: 17)).focused($foco).submitLabel(.next)
                    .onSubmit(anadir)
                    .modifier(Campo())
                Button(action: anadir) {
                    Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 48, height: 48).background(Circle().fill(Color.rosa))
                }
                .disabled(texto.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ErrorTexto(t: error)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(recien, id: \.self) { r in
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles").foregroundStyle(Color.rosa).frame(width: 22)
                            Text(r).font(.system(size: 16)).foregroundStyle(Color.tinta)
                            Spacer()
                            Text("nuevo").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.rosa)
                        }
                        .padding(.vertical, 11)
                        Divider().overlay(Color.linea)
                    }
                    ForEach(lista) { c in
                        Button {
                            try? Almacen.shared.alternarCompra(id: c.id)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            cargar()
                            WidgetCenter.shared.reloadAllTimelines()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: c.comprado ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 20)).foregroundStyle(c.comprado ? Color(hex: "#7fb8a4") : Color.gris)
                                    .frame(width: 22)
                                Text(c.nombre + (c.cantidad.isEmpty ? "" : " · \(c.cantidad)"))
                                    .font(.system(size: 16))
                                    .foregroundStyle(c.comprado ? Color.gris : Color.tinta)
                                    .strikethrough(c.comprado)
                                Spacer()
                            }
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Color.linea)
                    }
                    if lista.isEmpty && recien.isEmpty {
                        Text("Tu lista está vacía ✨").font(.system(size: 14)).foregroundStyle(Color.gris).padding(.top, 8)
                    }
                }
            }
            BotonGrande(texto: "Listo") {
                Estado.shared.trasCambio()
                cerrar()
            }
        }
        .padding(20)
        .background(Color.fondo.ignoresSafeArea())
        .onAppear { cargar(); foco = true }
    }

    func cargar() { lista = Agenda.cargar().compra }

    func anadir() {
        let t = texto.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        do {
            try Almacen.shared.apuntarCompra(t)
            recien.insert(t, at: 0)
            texto = ""
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            foco = true
        } catch { self.error = error.localizedDescription }
    }
}

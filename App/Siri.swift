import AppIntents
import WidgetKit

// «Oye Siri, apunta en Centro…» y compañía.

func dlg(_ s: String) -> IntentDialog { IntentDialog(stringLiteral: s) }

struct ApuntarIntent: AppIntent {
    static let title: LocalizedStringResource = "Apuntar en Centro"
    static let description = IntentDescription("Apunta una tarea en tu Centro, como si la escribieras allí.")

    @Parameter(title: "Qué", requestValueDialog: IntentDialog("¿Qué te apunto?"))
    var texto: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try Almacen.shared.apuntar(texto)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: dlg("Apuntado ✅ Lo verás en tu Centro."))
    }
}

enum ComoPago: String, AppEnum {
    case efectivo, banco
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Cómo"
    static let caseDisplayRepresentations: [ComoPago: DisplayRepresentation] = [
        .efectivo: "Efectivo", .banco: "Tarjeta",
    ]
}

struct GastoIntent: AppIntent {
    static let title: LocalizedStringResource = "Apuntar un gasto"
    static let description = IntentDescription("Apunta un gasto en tu Presupuesto.")

    @Parameter(title: "Cuánto", requestValueDialog: IntentDialog("¿Cuánto has gastado?"))
    var importe: Double
    @Parameter(title: "En qué", requestValueDialog: IntentDialog("¿En qué?"))
    var concepto: String
    @Parameter(title: "Cómo", default: .efectivo)
    var como: ComoPago

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try Almacen.shared.apuntarDinero(importe: -abs(importe), concepto: concepto, origen: como.rawValue,
                                         categoria: "imprevistos", fecha: Date())
        return .result(dialog: dlg("Apuntado: \(concepto), \(importe.formatted(.number.precision(.fractionLength(0...2)))) € 💸"))
    }
}

struct IngresoIntent: AppIntent {
    static let title: LocalizedStringResource = "Apuntar un ingreso"
    static let description = IntentDescription("Apunta un ingreso en tu Presupuesto.")

    @Parameter(title: "Cuánto", requestValueDialog: IntentDialog("¿Cuánto te ha entrado?"))
    var importe: Double
    @Parameter(title: "De qué", requestValueDialog: IntentDialog("¿De qué es?"))
    var concepto: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try Almacen.shared.apuntarDinero(importe: abs(importe), concepto: concepto, origen: "banco",
                                         categoria: "otros_ing", fecha: Date())
        return .result(dialog: dlg("¡Bien! Apuntado: \(concepto), \(importe.formatted(.number.precision(.fractionLength(0...2)))) € 💰"))
    }
}

struct AnadirCompraIntent: AppIntent {
    static let title: LocalizedStringResource = "Añadir a la compra"
    static let description = IntentDescription("Añade algo a tu lista de la compra.")

    @Parameter(title: "Qué", requestValueDialog: IntentDialog("¿Qué hace falta?"))
    var texto: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try Almacen.shared.apuntarCompra(texto)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: dlg("Añadido a la compra 🛒"))
    }
}

struct QueTocaIntent: AppIntent {
    static let title: LocalizedStringResource = "¿Qué me toca?"
    static let description = IntentDescription("Te dice lo siguiente que tienes y cuánto te queda hoy.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let a = Agenda.cargar()
        if let s = a.siguiente {
            let n = Fechas.ahoraMin(), ini = Fechas.minutos(s.ini)
            let cuando = ini <= n ? "Ahora mismo" : "A las \(s.ini)"
            let resto = a.hoy.count - 1
            return .result(dialog: dlg("\(cuando): \(s.titulo).\(resto > 0 ? " Y luego \(resto) \(resto == 1 ? "cosa más" : "cosas más") hoy." : "")"))
        }
        if a.hoy.isEmpty { return .result(dialog: dlg("Nada más por hoy. ¡Descansa! ✨")) }
        return .result(dialog: dlg("No tienes nada con hora. Te quedan \(a.hoy.count) \(a.hoy.count == 1 ? "cosa" : "cosas"), la primera: \(a.hoy[0].titulo)."))
    }
}

struct VerNovedadesIntent: AppIntent {
    static let title: LocalizedStringResource = "Ver las novedades"
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Estado.shared.novedades = true
        return .result()
    }
}

struct AtajosCentro: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ApuntarIntent(), phrases: [
            "Apunta en \(.applicationName)",
            "Apúntame algo en \(.applicationName)",
            "Nueva tarea en \(.applicationName)",
            "Recuérdame algo en \(.applicationName)",
        ], shortTitle: "Apuntar", systemImageName: "square.and.pencil")
        AppShortcut(intent: GastoIntent(), phrases: [
            "Apunta un gasto en \(.applicationName)",
            "Gasto en \(.applicationName)",
            "He gastado dinero en \(.applicationName)",
        ], shortTitle: "Gasto", systemImageName: "eurosign.circle")
        AppShortcut(intent: IngresoIntent(), phrases: [
            "Apunta un ingreso en \(.applicationName)",
            "Ingreso en \(.applicationName)",
        ], shortTitle: "Ingreso", systemImageName: "banknote")
        AppShortcut(intent: AnadirCompraIntent(), phrases: [
            "Añade a la compra en \(.applicationName)",
            "Apunta en la compra de \(.applicationName)",
            "Lista de la compra de \(.applicationName)",
        ], shortTitle: "Compra", systemImageName: "cart")
        AppShortcut(intent: QueTocaIntent(), phrases: [
            "Qué me toca en \(.applicationName)",
            "Qué tengo ahora en \(.applicationName)",
            "Lo siguiente en \(.applicationName)",
        ], shortTitle: "¿Qué me toca?", systemImageName: "clock")
        AppShortcut(intent: VerNovedadesIntent(), phrases: [
            "Novedades de \(.applicationName)",
            "Qué hay nuevo en \(.applicationName)",
        ], shortTitle: "Novedades", systemImageName: "gift")
    }
}

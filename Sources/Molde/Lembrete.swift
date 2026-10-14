import A2UISwiftCore
import A2UISwiftUI
import MoldeContrato
import SwiftUI
import UserNotifications

/// Mostra o lembrete. O pedido de permissão e o agendamento só acontecem
/// depois do toque.
struct LembreteView: View {
    let node: ComponentNode
    let surface: SurfaceModel
    @Environment(\.a2uiActionHandler) private var aoTocar
    @State private var situacao = "Agendar lembrete"

    var body: some View {
        let leitor = LeitorDeProps(node: node, surface: surface)
        let titulo = leitor.texto("titulo")
        let quando = leitor.texto("quando")
        VStack(alignment: .leading, spacing: 8) {
            Label(titulo, systemImage: "bell")
            Text(Self.data(quando).map { $0.formatted(date: .abbreviated, time: .shortened) } ?? quando)
                .font(.footnote).foregroundStyle(.secondary)
            Button(situacao) { Task { await agendar(titulo: titulo, quando: quando) } }
                .disabled(situacao != "Agendar lembrete" || Self.data(quando) == nil)
        }
    }

    static func data(_ texto: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f.date(from: texto)
    }

    func agendar(titulo: String, quando: String) async {
        guard let data = Self.data(quando) else { return }
        let centro = UNUserNotificationCenter.current()
        guard (try? await centro.requestAuthorization(options: [.alert, .sound])) == true else {
            situacao = "Sem permissão para avisar"; return
        }
        let conteudo = UNMutableNotificationContent()
        conteudo.title = titulo; conteudo.sound = .default
        let quandoDisparar = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: data)
        let pedido = UNNotificationRequest(identifier: "molde-\(node.baseComponentId)-\(Int(data.timeIntervalSince1970))",
                                           content: conteudo,
                                           trigger: UNCalendarNotificationTrigger(dateMatching: quandoDisparar, repeats: false))
        guard (try? await centro.add(pedido)) != nil else { situacao = "Não deu para agendar"; return }
        situacao = "Lembrete agendado"
        aoTocar?(ResolvedAction(name: Nativos.agendarLembrete.nome, sourceComponentId: node.baseComponentId,
                                context: ["titulo": .string(titulo), "quando": .string(quando)]))
    }
}

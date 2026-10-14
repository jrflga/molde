#if DEBUG
import Molde
import MoldeContrato
import SwiftUI

/// O que o agente mandou, os dados e a árvore, lado a lado. Só em DEBUG.
public struct InspectorDoMolde: View {
    let superficie: SuperficieDoMolde
    let registro: [String]
    public init(superficie: SuperficieDoMolde, registro: [String]) { self.superficie = superficie; self.registro = registro }

    public var body: some View {
        List {
            Section("Árvore") { ForEach(superficie.arvore, id: \.self) { Text($0).font(.caption.monospaced()) } }
            Section("Modelo de dados") { Text(Self.bonito(superficie.modeloDeDados)).font(.caption.monospaced()) }
            Section("Mensagens") { Text(Self.bonito(.lista(superficie.mensagens))).font(.caption.monospaced()) }
            Section("Ações e erros") { ForEach(Array(registro.enumerated()), id: \.offset) { Text($0.element).font(.caption) } }
        }
    }

    static func bonito(_ json: JSON?) -> String {
        guard let json, let dados = try? json.dados(), let obj = try? JSONSerialization.jsonObject(with: dados),
              let lindo = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) else { return "—" }
        return String(decoding: lindo, as: UTF8.self)
    }
}
#endif

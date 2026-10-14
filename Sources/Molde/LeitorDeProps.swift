import A2UISwiftCore
import Foundation

/// Lê as props de um componente do app, resolvendo `{"path"}` e funções
/// contra os dados da superfície.
public struct LeitorDeProps {
    let node: ComponentNode
    let contexto: DataContext
    public init(node: ComponentNode, surface: SurfaceModel) {
        self.node = node
        contexto = DataContext(surface: surface, path: node.dataContextPath)
    }

    public func texto(_ chave: String) -> String {
        guard let bruto = node.instance.properties[chave], let dados = try? JSONEncoder().encode(bruto),
              let dinamico = try? JSONDecoder().decode(DynamicString.self, from: dados) else { return "" }
        return contexto.resolve(dinamico)
    }

    /// A ação da prop, com o `context` resolvido. `extra` entra no context.
    public func acao(_ chave: String = "action", extra: [String: AnyCodable] = [:]) -> ResolvedAction? {
        guard let bruto = node.instance.properties[chave], let dados = try? JSONEncoder().encode(bruto),
              let acao = try? JSONDecoder().decode(Action.self, from: dados),
              case .event(let nome, let contextoCru) = acao else { return nil }
        var resolvido: [String: AnyCodable] = extra
        for (k, v) in contextoCru ?? [:] { resolvido[k] = contexto.resolveDynamicValue(v) ?? .null }
        return ResolvedAction(name: nome, sourceComponentId: node.baseComponentId, context: resolvido)
    }
}

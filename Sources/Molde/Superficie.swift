import A2UISwiftCore
import A2UISwiftUI
import Foundation
import MoldeContrato
import Observation

/// Uma tela que o agente montou, já validada. Desenha só com o catálogo do
/// manifesto. Publicar dados refaz a tela sem chamar a IA.
@MainActor
@Observable
public final class SuperficieDoMolde: Identifiable {
    public nonisolated let id: String
    public let mensagens: [JSON]
    public let podeFixar: Bool
    let viewModel: SurfaceViewModel

    /// Valida antes. Se `processMessages` reclamar, a primeira falha sobe.
    public init(mensagens: [JSON], manifesto: Manifesto) throws {
        let decodificadas = try mensagens.map { try JSONDecoder().decode(A2uiMessage.self, from: $0.dados()) }
        let criacao = decodificadas.lazy.compactMap { m -> CreateSurfacePayload? in
            if case .createSurface(let p) = m { return p } else { return nil }
        }.first
        id = criacao?.surfaceId ?? "tela"
        self.mensagens = mensagens
        podeFixar = Validador(manifesto: manifesto).podeFixar(mensagens)
        let catalogo = Catalog(
            id: manifesto.catalogId,
            componentNames: Set(manifesto.componentes.keys),
            functions: basicCatalog.functions.filter { manifesto.funcoes.contains($0.key) }
        )
        viewModel = SurfaceViewModel(surface: SurfaceModel(id: id, catalog: catalogo, theme: criacao?.theme))
        if let falha = viewModel.processMessages(decodificadas).first { throw falha }
    }

    /// Escreve cada raiz (ex. "fila") e remonta a árvore, porque o template
    /// de lista só se expande na montagem.
    public func publicar(_ dados: JSON) {
        let contexto = viewModel.makeDataContext()
        for (raiz, valor) in dados.comoObjeto ?? [:] {
            guard let bruto = try? valor.dados(), let anyCodable = try? JSONDecoder().decode(AnyCodable.self, from: bruto) else { continue }
            try? contexto.set("/\(raiz)", value: anyCodable)
        }
        viewModel.rebuildComponentTree()
    }

    /// "id: Tipo" de cada nó, em profundidade. É para o inspector e os testes.
    public var arvore: [String] {
        func nos(_ n: ComponentNode?) -> [String] {
            guard let n else { return [] }
            return ["\(n.id): \(n.instance.component)"] + n.children.flatMap(nos)
        }
        return nos(viewModel.componentTree)
    }

    /// O modelo de dados inteiro da superfície. O `getClientDataModel` do
    /// A2UI-Swift só devolve quando a superfície pede `sendDataModel`.
    public var modeloDeDados: JSON? {
        guard let modelo = viewModel.surface.dataModel.get("/"), let bruto = try? JSONEncoder().encode(modelo) else { return nil }
        return try? JSON(dados: bruto)
    }
}

/// A mensagem da conversa do app guarda a superfície e é Equatable: vale a
/// identidade do objeto.
extension SuperficieDoMolde: Equatable {
    public nonisolated static func == (a: SuperficieDoMolde, b: SuperficieDoMolde) -> Bool { a === b }
}

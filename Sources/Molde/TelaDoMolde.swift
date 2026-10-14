import A2UISwiftCore
import A2UISwiftUI
import MoldeContrato
import SwiftUI

public struct AcaoTocada: Sendable, Equatable {
    public let nome: String
    public let componente: String
    public let contexto: JSON
}

/// Desenha a superfície. Os componentes nativos do pacote vêm antes dos do
/// app; os básicos o A2UI-Swift desenha.
public struct TelaDoMolde<Dominio: CustomComponentCatalog>: View {
    let superficie: SuperficieDoMolde
    let dominio: Dominio
    let toque: Toque

    public init(superficie: SuperficieDoMolde, dominio: Dominio, aoTocar: @escaping @MainActor (AcaoTocada) -> Void) {
        self.superficie = superficie; self.dominio = dominio; toque = Toque(aoTocar)
    }

    public var body: some View {
        let toque = toque
        A2UISurfaceView(viewModel: superficie.viewModel, catalog: CatalogoDoMolde(dominio: dominio), scrolls: false) { acao in
            let contexto = (try? JSONEncoder().encode(acao.context)).flatMap { try? JSON(dados: $0) } ?? .objeto([:])
            let tocada = AcaoTocada(nome: acao.name, componente: acao.sourceComponentId, contexto: contexto)
            Task { @MainActor in toque.aoTocar(tocada) }
        }
    }
}

/// Guarda o toque do app no ator principal. O A2UI-Swift chama o `onAction`
/// como `@Sendable`, e o app não precisa de closure `@Sendable`.
@MainActor
final class Toque {
    let aoTocar: @MainActor (AcaoTocada) -> Void
    init(_ aoTocar: @escaping @MainActor (AcaoTocada) -> Void) { self.aoTocar = aoTocar }
}

struct CatalogoDoMolde<Dominio: CustomComponentCatalog>: CustomComponentCatalog {
    let dominio: Dominio
    @ViewBuilder @MainActor
    func build(typeName: String, node: ComponentNode, surface: SurfaceModel) -> some View {
        if typeName == Nativos.lembrete.nome {
            LembreteView(node: node, surface: surface)
        } else {
            dominio.build(typeName: typeName, node: node, surface: surface)
        }
    }
}

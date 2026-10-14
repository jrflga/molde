import A2UISwiftCore
import Foundation
import MoldeContrato
import Testing
@testable import Molde

/// Manifesto com os 8 básicos sem limites apertados, os eventos que os
/// exemplos usam (o manifesto exige ação declarada) e o catalogId da
/// especificação.
private func manifestoDosExemplos(_ todos: [(String, [JSON])]) -> Manifesto {
    let eventos = Set(todos.flatMap { nomesDeEventos(em: .lista($0.1)) }).sorted()
    let contrato = Contrato(prefixo: "x", versao: "1",
        componentes: [Basicos.text(), Basicos.button, Basicos.card, Basicos.list(), Basicos.row(),
                      Basicos.column(), Basicos.divider, Basicos.icon(nomes: nomesDosIcones)],
        acoes: eventos.map { Acao(nome: $0, descricao: "", tipo: .doAgente) },
        funcoes: Basicos.funcoesSeguras)
    var json = Manifesto(contrato: contrato).json.comoObjeto!
    json["catalogId"] = .texto("https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json")
    return try! Manifesto(json: .objeto(json))
}

private func nomesDeEventos(em json: JSON) -> [String] {
    switch json {
    case .objeto(let o): (o["event"]?["name"]?.comoTexto.map { [$0] } ?? []) + o.values.flatMap(nomesDeEventos)
    case .lista(let l): l.flatMap(nomesDeEventos)
    default: []
    }
}

private func exemplos() throws -> [(String, [JSON])] {
    let pasta = Bundle.module.url(forResource: "Exemplos", withExtension: nil)!
    return try FileManager.default.contentsOfDirectory(at: pasta, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        .map { ($0.lastPathComponent, try JSON(dados: Data(contentsOf: $0))["messages"]?.comoLista ?? []) }
}

@Suite("Conformidade com a especificação 0.9.1")
struct ConformidadeTests {
    @Test("todo exemplo da especificação decodifica no A2UI-Swift do fork")
    func decodificam() throws {
        for (nome, mensagens) in try exemplos() {
            for m in mensagens {
                #expect(throws: Never.self, "\(nome)") { try JSONDecoder().decode(A2uiMessage.self, from: m.dados()) }
            }
        }
    }

    @Test("os exemplos só com os 8 básicos passam no validador")
    func passamNoValidador() throws {
        let todos = try exemplos()
        let manifesto = manifestoDosExemplos(todos)
        let declarados = Set(manifesto.componentes.keys)
        let validador = Validador(manifesto: manifesto)
        var conferidos = 0
        for (nome, mensagens) in todos {
            let usados = Set(mensagens.flatMap { $0["updateComponents"]?["components"]?.comoLista ?? [] }.compactMap { $0["component"]?.comoTexto })
            guard usados.isSubset(of: declarados) else { continue }
            conferidos += 1
            #expect(validador.validar(mensagens).isEmpty, "\(nome): \(validador.validar(mensagens).map(\.mensagem))")
        }
        #expect(conferidos >= 20)
    }
}

@Suite("Superfície")
@MainActor
struct SuperficieTests {
    @Test("publicar dados refaz a lista do template sem chamar ninguém")
    func publicarRefazALista() throws {
        let manifesto = Manifesto(contrato: Contrato(prefixo: "x", versao: "1",
            componentes: [Basicos.text(), Basicos.list(maximo: 5)], acoes: [], funcoes: [],
            caminhosPublicados: ["/itens"]))
        let id = manifesto.catalogId
        let mensagens: [JSON] = [
            .objeto(["version": .texto("v0.9.1"), "createSurface": .objeto(["surfaceId": .texto("s"), "catalogId": .texto(id)])]),
            .objeto(["version": .texto("v0.9.1"), "updateComponents": .objeto(["surfaceId": .texto("s"), "components": .lista([
                .objeto(["id": .texto("root"), "component": .texto("List"),
                         "children": .objeto(["componentId": .texto("item"), "path": .texto("/itens")])]),
                .objeto(["id": .texto("item"), "component": .texto("Text"), "text": .objeto(["path": .texto("nome")])]),
            ])])]),
        ]
        let superficie = try SuperficieDoMolde(mensagens: mensagens, manifesto: manifesto)
        #expect(superficie.podeFixar)
        superficie.publicar(.objeto(["itens": .lista([.objeto(["nome": .texto("A")]), .objeto(["nome": .texto("B")])])]))
        #expect(superficie.arvore.filter { $0.hasPrefix("item") }.count == 2)
        superficie.publicar(.objeto(["itens": .lista([.objeto(["nome": .texto("C")])])]))
        #expect(superficie.arvore.filter { $0.hasPrefix("item") }.count == 1)
    }
}

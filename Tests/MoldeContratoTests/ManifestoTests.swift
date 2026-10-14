import Foundation
import Testing
@testable import MoldeContrato

@Suite("Manifesto")
struct ManifestoTests {
    @Test("o catalogId leva prefixo, versão e uma marca de 8 letras do conteúdo")
    func catalogId() throws {
        let id = Exemplo.manifesto.catalogId
        #expect(id.hasPrefix("exemplo.molde:teste:1:"))
        #expect(id.split(separator: ":").last?.count == 8)
        #expect(id == Manifesto(contrato: Exemplo.contrato).catalogId, "a marca muda de uma execução para outra")
    }

    @Test("mudar um limite muda a marca")
    func marcaSegueOConteudo() {
        var componentes = Exemplo.contrato.componentes
        componentes[0] = Basicos.text(maximo: 41)
        let outro = Contrato(prefixo: "exemplo.molde:teste", versao: "1", componentes: componentes,
                             acoes: Exemplo.contrato.acoes, funcoes: Exemplo.contrato.funcoes)
        #expect(Manifesto(contrato: outro).catalogId != Exemplo.manifesto.catalogId)
    }

    @Test("o manifesto lido do JSON é o mesmo que saiu do contrato")
    func idaEVolta() throws {
        let original = Exemplo.manifesto
        let lido = try Manifesto(json: JSON(dados: original.json.dados()))
        #expect(lido.catalogId == original.catalogId)
        #expect(lido.componentes == original.componentes)
        #expect(lido.acoes == original.acoes)
        #expect(lido.funcoes == original.funcoes)
        #expect(lido.caminhosPublicados == ["/itens", "/resumo"])
    }

    @Test("o JSON segue o formato de catálogo da especificação")
    func formatoDeCatalogo() throws {
        let json = Exemplo.manifesto.json
        #expect(json["catalogId"]?.comoTexto == Exemplo.manifesto.catalogId)
        #expect(json["components"]?["Text"]?["properties"]?["text"]?["maxLength"] == .numero(40))
        #expect(json["components"]?["Text"]?["required"] == .lista([.texto("text")]))
        #expect(json["functions"] == .lista([.texto("formatString"), .texto("pluralize")]))
    }
}

import Testing
@testable import MoldeContrato

private let v = Validador(manifesto: Exemplo.manifesto)
private func criar(_ catalogId: String = Exemplo.manifesto.catalogId) -> JSON {
    .objeto(["version": .texto("v0.9.1"), "createSurface": .objeto(["surfaceId": .texto("s1"), "catalogId": .texto(catalogId)])])
}
private func componentes(_ lista: [[String: JSON]]) -> JSON {
    .objeto(["version": .texto("v0.9.1"), "updateComponents": .objeto(["surfaceId": .texto("s1"), "components": .lista(lista.map(JSON.objeto))])])
}
private func tela(_ lista: [[String: JSON]]) -> [JSON] { [criar(), componentes(lista)] }
private let raizComTexto: [String: JSON] = ["id": .texto("root"), "component": .texto("Text"), "text": .texto("Oi")]
private func botao(_ id: String, acao: String, variante: String = "default") -> [String: JSON] {
    ["id": .texto(id), "component": .texto("Button"), "child": .texto("root"), "variant": .texto(variante),
     "action": .objeto(["event": .objeto(["name": .texto(acao)])])]
}

@Suite("Validador")
struct ValidadorTests {
    @Test("tela dentro do manifesto passa")
    func valida() { #expect(v.validar(tela([raizComTexto])).isEmpty) }

    @Test("componente fora do manifesto é erro, com o caminho e o nome")
    func foraDoManifesto() {
        let erros = v.validar(tela([["id": .texto("root"), "component": .texto("Video"), "url": .texto("x")]]))
        #expect(erros.first?.regra == .foraDoManifesto)
        #expect(erros.first?.caminho == "/1/updateComponents/components/0/component")
        #expect(erros.first?.componente == "Video")
    }

    @Test("prop que o componente não tem é erro")
    func propDesconhecida() {
        var c = raizComTexto; c["cor"] = .texto("azul")
        #expect(v.validar(tela([c])).first?.regra == .foraDoManifesto)
    }

    @Test("texto acima do limite e lista com filhos demais são fora do limite")
    func foraDoLimite() {
        var longo = raizComTexto; longo["text"] = .texto(String(repeating: "a", count: 41))
        #expect(v.validar(tela([longo])).first?.regra == .foraDoLimite)
        let muitos: [String: JSON] = ["id": .texto("root"), "component": .texto("List"),
                                      "children": .lista((1...6).map { .texto("t\($0)") })]
        #expect(v.validar(tela([muitos])).first?.regra == .foraDoLimite)
    }

    @Test("opção fora da lista é fora do limite")
    func opcao() {
        let icone: [String: JSON] = ["id": .texto("root"), "component": .texto("Icon"), "name": .texto("home")]
        #expect(v.validar(tela([icone])).first?.regra == .foraDoLimite)
    }

    @Test("ação irreversível vinda do agente é recusada")
    func irreversivel() {
        let erros = v.validar(tela([raizComTexto, botao("b", acao: "apagar_tudo")]))
        #expect(erros.first?.regra == .acaoIrreversivel)
        #expect(erros.first?.caminho == "/1/updateComponents/components/1/action")
    }

    @Test("ação ou função que o manifesto não tem é erro; openUrl não passa")
    func acaoEFuncao() {
        #expect(v.validar(tela([raizComTexto, botao("b", acao: "voar")])).first?.regra == .foraDoManifesto)
        var b = botao("b", acao: "abrir_item")
        b["action"] = .objeto(["functionCall": .objeto(["call": .texto("openUrl"), "args": .objeto(["url": .texto("https://x")])])])
        #expect(v.validar(tela([raizComTexto, b])).first?.regra == .foraDoManifesto)
    }

    @Test("ligação a dado e função do manifesto passam no lugar do texto")
    func dinamicos() {
        var c = raizComTexto; c["text"] = .objeto(["path": .texto("/resumo/titulo")])
        #expect(v.validar(tela([c])).isEmpty)
        c["text"] = .objeto(["call": .texto("formatString"), "args": .objeto(["value": .texto("x")])])
        #expect(v.validar(tela([c])).isEmpty)
    }

    @Test("duas ações principais na mesma superfície passam do limite")
    func umaPrincipal() {
        let erros = v.validar(tela([raizComTexto, botao("a", acao: "abrir_item", variante: "primary"),
                                    botao("b", acao: "abrir_item", variante: "primary")]))
        #expect(erros.map(\.regra) == [.foraDoLimite])
    }

    @Test("catalogId de outro manifesto é manifesto errado")
    func manifestoErrado() {
        let erros = v.validar([criar("exemplo.molde:teste:0:deadbeef"), componentes([raizComTexto])])
        #expect(erros.first?.regra == .manifestoErrado)
    }

    @Test("mensagem com duas chaves, sem versão ou sem surfaceId é formato")
    func formato() {
        #expect(v.validar([.objeto(["createSurface": .objeto(["surfaceId": .texto("s1")])])]).first?.regra == .formato)
        #expect(v.validar([.objeto(["version": .texto("v0.9.1"), "createSurface": .objeto([:]), "deleteSurface": .objeto([:])])]).first?.regra == .formato)
    }

    @Test("superfície sem o componente root é formato")
    func semRaiz() {
        var c = raizComTexto; c["id"] = .texto("titulo")
        let erros = v.validar(tela([c]))
        #expect(erros.map(\.regra) == [.formato])
        #expect(erros.first?.explicacao.contains("root") == true)
    }

    @Test("o erro para o agente segue o VALIDATION_FAILED da 0.9.1")
    func paraOAgente() {
        let erro = v.validar(tela([["id": .texto("root"), "component": .texto("Video")]]))[0]
        #expect(erro.paraOAgente["version"] == .texto("v0.9.1"))
        #expect(erro.paraOAgente["error"]?["code"] == .texto("VALIDATION_FAILED"))
        #expect(erro.paraOAgente["error"]?["path"] == .texto(erro.caminho))
        #expect(erro.paraOAgente["error"]?["message"]?.comoTexto?.hasPrefix("fora_do_manifesto: ") == true)
    }

    @Test("pode fixar só tela sem dados copiados, ligada aos caminhos publicados")
    func podeFixar() {
        var ligado = raizComTexto; ligado["text"] = .objeto(["path": .texto("/resumo/titulo")])
        #expect(v.podeFixar(tela([ligado])))
        #expect(v.podeFixar(tela([raizComTexto])), "texto fixo, como um título, pode")
        var fora = raizComTexto; fora["text"] = .objeto(["path": .texto("/meus/dados")])
        #expect(!v.podeFixar(tela([fora])))
        let copiados = tela([ligado]) + [.objeto(["version": .texto("v0.9.1"),
            "updateDataModel": .objeto(["surfaceId": .texto("s1"), "value": .objeto(["x": .texto("Marcos")])])])]
        #expect(!v.podeFixar(copiados))
    }
}

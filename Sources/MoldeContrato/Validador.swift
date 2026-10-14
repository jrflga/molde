public enum Regra: String, Sendable {
    case foraDoManifesto = "fora_do_manifesto"
    case foraDoLimite = "fora_do_limite"
    case acaoIrreversivel = "acao_irreversivel"
    case manifestoErrado = "manifesto_errado"
    case formato
}

public struct ErroDeValidacao: Equatable, Sendable {
    public let regra: Regra
    public let surfaceId: String
    public let caminho: String
    public let componente: String?
    public let explicacao: String
    public var mensagem: String { "\(regra.rawValue): \(explicacao)" }

    /// Público: o app também monta erro, quando o renderer recusa a tela.
    public init(regra: Regra, surfaceId: String, caminho: String, componente: String?, explicacao: String) {
        self.regra = regra
        self.surfaceId = surfaceId
        self.caminho = caminho
        self.componente = componente
        self.explicacao = explicacao
    }
    /// O `error` da especificação 0.9.1: o código da regra vai no começo da
    /// `message`, porque o VALIDATION_FAILED não aceita campo a mais.
    public var paraOAgente: JSON {
        .objeto(["version": .texto("v0.9.1"), "error": .objeto([
            "code": .texto("VALIDATION_FAILED"), "surfaceId": .texto(surfaceId),
            "path": .texto(caminho), "message": .texto(mensagem),
        ])])
    }
}

public struct Validador: Sendable {
    let manifesto: Manifesto
    static let tiposDeMensagem: Set<String> = ["createSurface", "updateComponents", "updateDataModel", "deleteSurface"]
    static let chavesComuns: Set<String> = ["id", "component", "weight", "accessibility"]

    public init(manifesto: Manifesto) { self.manifesto = manifesto }

    public func validar(_ mensagens: [JSON]) -> [ErroDeValidacao] {
        var erros: [ErroDeValidacao] = []
        var principais: [String: Int] = [:]
        var criadas: [String] = []
        var raizes: Set<String> = []
        func erro(_ r: Regra, _ s: String, _ c: String, _ e: String, componente: String? = nil) {
            erros.append(ErroDeValidacao(regra: r, surfaceId: s, caminho: c, componente: componente, explicacao: e))
        }
        for (i, mensagem) in mensagens.enumerated() {
            guard let obj = mensagem.comoObjeto else { erro(.formato, "", "/\(i)", "a mensagem não é um objeto"); continue }
            guard let versao = obj["version"]?.comoTexto, ["v0.9", "v0.9.1"].contains(versao) else {
                erro(.formato, "", "/\(i)/version", "a versão precisa ser v0.9.1"); continue
            }
            let tipos = obj.keys.filter { $0 != "version" }
            guard tipos.count == 1, let tipo = tipos.first, Self.tiposDeMensagem.contains(tipo), let corpo = obj[tipo]?.comoObjeto else {
                erro(.formato, "", "/\(i)", "cada mensagem leva só um de createSurface, updateComponents, updateDataModel ou deleteSurface"); continue
            }
            guard let s = corpo["surfaceId"]?.comoTexto, !s.isEmpty else {
                erro(.formato, "", "/\(i)/\(tipo)/surfaceId", "falta o surfaceId"); continue
            }
            switch tipo {
            case "createSurface":
                criadas.append(s)
                if corpo["catalogId"]?.comoTexto != manifesto.catalogId {
                    erro(.manifestoErrado, s, "/\(i)/createSurface/catalogId", "use o catalogId \(manifesto.catalogId)")
                }
            case "updateComponents":
                guard let lista = corpo["components"]?.comoLista else {
                    erro(.formato, s, "/\(i)/updateComponents/components", "components precisa ser uma lista"); continue
                }
                for (j, comp) in lista.enumerated() {
                    let base = "/\(i)/updateComponents/components/\(j)"
                    if comp["id"]?.comoTexto == "root" { raizes.insert(s) }
                    if comp["component"]?.comoTexto == "Button", comp["variant"]?.comoTexto == "primary" {
                        principais[s, default: 0] += 1
                        if principais[s]! > manifesto.maximoDeAcoesPrincipais {
                            erro(.foraDoLimite, s, base + "/variant", "só \(manifesto.maximoDeAcoesPrincipais) botão primary por superfície", componente: "Button")
                        }
                    }
                    validarComponente(comp, s, base, &erros)
                }
            default: break
            }
        }
        for s in criadas where !raizes.contains(s) {
            erro(.formato, s, "/", "falta o componente root na superfície \(s)")
        }
        return erros
    }

    func validarComponente(_ comp: JSON, _ s: String, _ base: String, _ erros: inout [ErroDeValidacao]) {
        func erro(_ r: Regra, _ c: String, _ e: String, _ nome: String?) {
            erros.append(ErroDeValidacao(regra: r, surfaceId: s, caminho: c, componente: nome, explicacao: e))
        }
        guard let obj = comp.comoObjeto, let id = obj["id"]?.comoTexto, !id.isEmpty else {
            erro(.formato, base + "/id", "todo componente precisa de id", nil); return
        }
        let nome = obj["component"]?.comoTexto ?? ""
        guard let decl = manifesto.componentes[nome] else {
            erro(.foraDoManifesto, base + "/component", "o componente \(nome) não existe no catálogo", nome); return
        }
        for prop in decl.props where prop.obrigatoria && obj[prop.nome] == nil {
            erro(.formato, base + "/\(prop.nome)", "falta \(prop.nome) em \(nome)", nome)
        }
        for (chave, valor) in obj where !Self.chavesComuns.contains(chave) {
            guard let prop = decl.props.first(where: { $0.nome == chave }) else {
                erro(.foraDoManifesto, base + "/\(chave)", "\(nome) não tem a prop \(chave)", nome); continue
            }
            if let (regra, explicacao) = conferir(valor, prop.tipo) { erro(regra, base + "/\(chave)", explicacao, nome) }
        }
    }

    /// Devolve a regra quebrada, ou nil.
    func conferir(_ valor: JSON, _ tipo: TipoDaProp) -> (Regra, String)? {
        if case .objeto(let o) = valor, o.keys.sorted() == ["path"], o["path"]?.comoTexto != nil {
            switch tipo { case .componente, .filhos, .acao: return (.formato, "aqui não cabe ligação a dado"); default: return nil }
        }
        if case .objeto(let o) = valor, let funcao = o["call"]?.comoTexto {
            return manifesto.funcoes.contains(funcao) ? nil : (.foraDoManifesto, "a função \(funcao) não existe no catálogo")
        }
        switch tipo {
        case .texto(let maximo):
            guard let t = valor.comoTexto else { return (.formato, "esperava texto, {\"path\"} ou {\"call\"}") }
            return t.count > maximo ? (.foraDoLimite, "o texto passa de \(maximo) caracteres") : nil
        case .numero(let minimo, let maximo):
            guard let n = valor.comoNumero else { return (.formato, "esperava número") }
            if let minimo, n < minimo { return (.foraDoLimite, "o número fica abaixo de \(minimo)") }
            if let maximo, n > maximo { return (.foraDoLimite, "o número passa de \(maximo)") }
            return nil
        case .booleano:
            if case .booleano = valor { return nil }
            return (.formato, "esperava true ou false")
        case .opcao(let valores):
            guard let t = valor.comoTexto else { return (.formato, "esperava um texto da lista") }
            return valores.contains(t) ? nil : (.foraDoLimite, "use um de: \(valores.joined(separator: ", "))")
        case .componente:
            return (valor.comoTexto?.isEmpty == false) ? nil : (.formato, "esperava o id de um componente")
        case .filhos(let maximo):
            if let lista = valor.comoLista {
                return lista.count > maximo ? (.foraDoLimite, "no máximo \(maximo) filhos") : nil
            }
            if valor["componentId"]?.comoTexto != nil, valor["path"]?.comoTexto != nil { return nil }
            return (.formato, "esperava uma lista de ids ou {\"componentId\", \"path\"}")
        case .acao:
            if let evento = valor["event"] {
                guard let nome = evento["name"]?.comoTexto else { return (.formato, "a ação precisa de event.name") }
                guard let acao = manifesto.acoes[nome] else { return (.foraDoManifesto, "a ação \(nome) não existe no catálogo") }
                return acao.irreversivel ? (.acaoIrreversivel, "a ação \(nome) só existe num botão do próprio app") : nil
            }
            if let chamada = valor["functionCall"]?["call"]?.comoTexto {
                return manifesto.funcoes.contains(chamada) ? nil : (.foraDoManifesto, "a função \(chamada) não existe no catálogo")
            }
            return (.formato, "esperava {\"event\": …} ou {\"functionCall\": …}")
        }
    }

    /// Uma superfície só, sem `updateDataModel`, válida e com toda ligação
    /// absoluta dentro dos caminhos publicados. Assim ela se refaz com os
    /// dados do momento.
    public func podeFixar(_ mensagens: [JSON]) -> Bool {
        guard validar(mensagens).isEmpty else { return false }
        let tipos = mensagens.compactMap { $0.comoObjeto?.keys.first { $0 != "version" } }
        guard tipos.filter({ $0 == "createSurface" }).count == 1, !tipos.contains("updateDataModel") else { return false }
        return Self.caminhos(em: .lista(mensagens)).allSatisfy { caminho in
            !caminho.hasPrefix("/") || manifesto.caminhosPublicados.contains { caminho == $0 || caminho.hasPrefix($0 + "/") }
        }
    }

    static func caminhos(em json: JSON) -> [String] {
        switch json {
        case .objeto(let o):
            let aqui = o["path"]?.comoTexto.map { [$0] } ?? []
            return aqui + o.values.flatMap { caminhos(em: $0) }
        case .lista(let l): return l.flatMap { caminhos(em: $0) }
        default: return []
        }
    }
}

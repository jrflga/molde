import CryptoKit
import Foundation

public enum ErroDoManifesto: Error, Equatable { case formato(String) }

/// O que o agente recebe: o catálogo no formato da especificação 0.9.1, mais
/// as chaves `x-molde` que só o Molde lê. O validador lê este mesmo JSON.
public struct Manifesto: Sendable {
    public let json: JSON
    public let catalogId: String
    public let componentes: [String: Componente]
    public let acoes: [String: Acao]
    public let funcoes: Set<String>
    public let caminhosPublicados: [String]
    public let maximoDeAcoesPrincipais: Int

    public init(contrato: Contrato) {
        let semMarca = Self.montar(contrato, catalogId: "\(contrato.prefixo):\(contrato.versao)")
        let resumo = SHA256.hash(data: (try? semMarca.dados()) ?? Data())
        let marca = resumo.map { String(format: "%02x", $0) }.joined().prefix(8)
        let id = "\(contrato.prefixo):\(contrato.versao):\(marca)"
        // `init(json:)` não falha com o JSON que `montar` acabou de gerar.
        try! self.init(json: Self.montar(contrato, catalogId: id))
    }

    public init(json: JSON) throws {
        guard let id = json["catalogId"]?.comoTexto, let comps = json["components"]?.comoObjeto,
              let extra = json["x-molde"] else { throw ErroDoManifesto.formato("faltam catalogId, components ou x-molde") }
        self.json = json
        catalogId = id
        componentes = Dictionary(uniqueKeysWithValues: try comps.map { nome, esquema in (nome, try Self.lerComponente(esquema).comNome(nome)) })
        acoes = Dictionary(uniqueKeysWithValues: (extra["acoes"]?.comoLista ?? []).compactMap(Self.lerAcao).map { ($0.nome, $0) })
        funcoes = Set((json["functions"]?.comoLista ?? []).compactMap(\.comoTexto))
        caminhosPublicados = (extra["caminhosPublicados"]?.comoLista ?? []).compactMap(\.comoTexto)
        maximoDeAcoesPrincipais = Int(extra["maximoDeAcoesPrincipais"]?.comoNumero ?? 1)
    }

    // MARK: Gerar

    static func montar(_ c: Contrato, catalogId: String) -> JSON {
        .objeto([
            "$schema": .texto("https://json-schema.org/draft/2020-12/schema"),
            "catalogId": .texto(catalogId),
            "title": .texto("Catálogo do Molde"),
            "components": .objeto(Dictionary(uniqueKeysWithValues: c.componentes.map { ($0.nome, esquema($0)) })),
            "functions": .lista(c.funcoes.map(JSON.texto)),
            "x-molde": .objeto([
                "versao": .texto(c.versao),
                "acoes": .lista(c.acoes.map { a in .objeto([
                    "nome": .texto(a.nome), "descricao": .texto(a.descricao), "tipo": .texto(a.tipo.rawValue),
                    "irreversivel": .booleano(a.irreversivel), "contexto": .lista(a.contexto.map(JSON.texto)),
                ]) }),
                "caminhosPublicados": .lista(c.caminhosPublicados.map(JSON.texto)),
                "maximoDeAcoesPrincipais": .numero(Double(c.maximoDeAcoesPrincipais)),
            ]),
        ])
    }

    static func esquema(_ comp: Componente) -> JSON {
        var obj: [String: JSON] = [
            "type": .texto("object"),
            "description": .texto(comp.descricao),
            "properties": .objeto(Dictionary(uniqueKeysWithValues: comp.props.map { ($0.nome, esquema($0)) })),
            "required": .lista(comp.props.filter(\.obrigatoria).map { .texto($0.nome) }),
            "x-molde-dados": .lista(comp.dados.map(JSON.texto)),
        ]
        if let permissao = comp.permissao { obj["x-molde-permissao"] = .texto(permissao) }
        return .objeto(obj)
    }

    static func esquema(_ prop: Prop) -> JSON {
        var obj: [String: JSON] = [:]
        if !prop.descricao.isEmpty { obj["description"] = .texto(prop.descricao) }
        switch prop.tipo {
        case .texto(let maximo):
            obj["x-molde-tipo"] = .texto("texto"); obj["maxLength"] = .numero(Double(maximo))
        case .numero(let minimo, let maximo):
            obj["x-molde-tipo"] = .texto("numero")
            if let minimo { obj["minimum"] = .numero(minimo) }
            if let maximo { obj["maximum"] = .numero(maximo) }
        case .booleano: obj["x-molde-tipo"] = .texto("booleano")
        case .opcao(let valores): obj["x-molde-tipo"] = .texto("opcao"); obj["enum"] = .lista(valores.map(JSON.texto))
        case .componente: obj["x-molde-tipo"] = .texto("componente")
        case .filhos(let maximo): obj["x-molde-tipo"] = .texto("filhos"); obj["maxItems"] = .numero(Double(maximo))
        case .acao: obj["x-molde-tipo"] = .texto("acao")
        }
        return .objeto(obj)
    }

    // MARK: Ler

    static func lerComponente(_ esquema: JSON) throws -> Componente {
        let obrigatorias = Set((esquema["required"]?.comoLista ?? []).compactMap(\.comoTexto))
        let props = try (esquema["properties"]?.comoObjeto ?? [:]).map { nome, p in
            Prop(nome, try lerTipo(p), obrigatoria: obrigatorias.contains(nome), descricao: p["description"]?.comoTexto ?? "")
        }.sorted { $0.nome < $1.nome }
        return Componente(nome: "", descricao: esquema["description"]?.comoTexto ?? "", props: props,
                          dados: (esquema["x-molde-dados"]?.comoLista ?? []).compactMap(\.comoTexto),
                          permissao: esquema["x-molde-permissao"]?.comoTexto)
    }

    static func lerTipo(_ p: JSON) throws -> TipoDaProp {
        switch p["x-molde-tipo"]?.comoTexto {
        case "texto": .texto(maximo: Int(p["maxLength"]?.comoNumero ?? 0))
        case "numero": .numero(minimo: p["minimum"]?.comoNumero, maximo: p["maximum"]?.comoNumero)
        case "booleano": .booleano
        case "opcao": .opcao((p["enum"]?.comoLista ?? []).compactMap(\.comoTexto))
        case "componente": .componente
        case "filhos": .filhos(maximo: Int(p["maxItems"]?.comoNumero ?? 0))
        case "acao": .acao
        default: throw ErroDoManifesto.formato("prop sem x-molde-tipo")
        }
    }

    static func lerAcao(_ a: JSON) -> Acao? {
        guard let nome = a["nome"]?.comoTexto else { return nil }
        return Acao(nome: nome, descricao: a["descricao"]?.comoTexto ?? "",
                    tipo: TipoDaAcao(rawValue: a["tipo"]?.comoTexto ?? "") ?? .doApp,
                    irreversivel: a["irreversivel"] == .booleano(true),
                    contexto: (a["contexto"]?.comoLista ?? []).compactMap(\.comoTexto))
    }
}

extension Componente {
    /// O nome vem da chave em `components`, não de dentro do esquema.
    func comNome(_ nome: String) -> Componente {
        Componente(nome: nome, descricao: descricao, props: props, dados: dados, permissao: permissao)
    }
}

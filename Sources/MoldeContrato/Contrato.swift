/// Como uma prop é conferida. Texto, número e booleano aceitam também
/// `{"path": …}` (ligação a dado) e `{"call": …}` (função do manifesto).
public enum TipoDaProp: Sendable, Equatable {
    case texto(maximo: Int)
    case numero(minimo: Double?, maximo: Double?)
    case booleano
    case opcao([String])
    case componente                 // id de outro componente
    case filhos(maximo: Int)        // ["a", "b"] ou {"componentId", "path"}
    case acao                       // {"event": …} ou {"functionCall": …}
}

public struct Prop: Sendable, Equatable {
    public let nome: String
    public let tipo: TipoDaProp
    public let obrigatoria: Bool
    public let descricao: String
    public init(_ nome: String, _ tipo: TipoDaProp, obrigatoria: Bool = false, descricao: String = "") {
        self.nome = nome; self.tipo = tipo; self.obrigatoria = obrigatoria; self.descricao = descricao
    }
}

public struct Componente: Sendable, Equatable {
    public let nome: String
    public let descricao: String
    public let props: [Prop]
    /// Caminhos do modelo de dados que o componente lê ou escreve.
    public let dados: [String]
    /// Permissão do sistema, pedida só depois de um toque.
    public let permissao: String?
    public init(nome: String, descricao: String, props: [Prop], dados: [String] = [], permissao: String? = nil) {
        // Em ordem de nome: o manifesto lido de volta compara igual ao gerado.
        self.nome = nome; self.descricao = descricao; self.props = props.sorted { $0.nome < $1.nome }
        self.dados = dados; self.permissao = permissao
    }
}

public enum TipoDaAcao: String, Sendable { case doApp = "app", doAgente = "agente" }

public struct Acao: Sendable, Equatable {
    public let nome: String
    public let descricao: String
    public let tipo: TipoDaAcao
    /// Nunca pode vir da IA: só existe num botão do próprio app.
    public let irreversivel: Bool
    /// As chaves que o `context` da ação leva.
    public let contexto: [String]
    public init(nome: String, descricao: String, tipo: TipoDaAcao, irreversivel: Bool = false, contexto: [String] = []) {
        self.nome = nome; self.descricao = descricao; self.tipo = tipo; self.irreversivel = irreversivel; self.contexto = contexto
    }
}

public struct Contrato: Sendable {
    /// Domínio do app, ex. "app.exemplo:molde". O manifesto acrescenta a
    /// versão e a marca do conteúdo.
    public let prefixo: String
    public let versao: String
    public let componentes: [Componente]
    public let acoes: [Acao]
    /// Funções da especificação que o agente pode chamar.
    public let funcoes: [String]
    /// Raízes dos dados que o app publica, ex. "/fila".
    public let caminhosPublicados: [String]
    public let maximoDeAcoesPrincipais: Int
    public init(prefixo: String, versao: String, componentes: [Componente], acoes: [Acao], funcoes: [String],
                caminhosPublicados: [String] = [], maximoDeAcoesPrincipais: Int = 1) {
        self.prefixo = prefixo; self.versao = versao; self.componentes = componentes; self.acoes = acoes
        self.funcoes = funcoes; self.caminhosPublicados = caminhosPublicados
        self.maximoDeAcoesPrincipais = maximoDeAcoesPrincipais
    }
}

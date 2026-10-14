/// Os básicos do A2UI que um app pode pôr no manifesto, com as props da
/// especificação 0.9.1. Os limites são do app.
public enum Basicos {
    static let alinhar = ["start", "center", "end", "stretch"]
    static let distribuir = ["start", "center", "end", "spaceBetween", "spaceAround", "spaceEvenly", "stretch"]

    public static func text(maximo: Int = 2000) -> Componente {
        Componente(nome: "Text", descricao: "Texto curto.", props: [
            Prop("text", .texto(maximo: maximo), obrigatoria: true),
            Prop("variant", .opcao(["h1", "h2", "h3", "h4", "h5", "caption", "body"])),
        ])
    }
    public static let button = Componente(nome: "Button", descricao: "Botão. O rótulo é um Text filho.", props: [
        Prop("child", .componente, obrigatoria: true),
        Prop("action", .acao, obrigatoria: true),
        Prop("variant", .opcao(["default", "primary", "borderless"]), descricao: "primary é a ação principal."),
    ])
    public static let card = Componente(nome: "Card", descricao: "Cartão com um filho.", props: [
        Prop("child", .componente, obrigatoria: true),
    ])
    public static func list(maximo: Int = 100) -> Componente {
        Componente(nome: "List", descricao: "Lista; use um template ligado a uma lista de dados.", props: [
            Prop("children", .filhos(maximo: maximo), obrigatoria: true),
            Prop("direction", .opcao(["vertical", "horizontal"])),
            Prop("align", .opcao(alinhar)),
        ])
    }
    public static func row(maximo: Int = 100) -> Componente {
        Componente(nome: "Row", descricao: "Linha.", props: [
            Prop("children", .filhos(maximo: maximo), obrigatoria: true),
            Prop("justify", .opcao(distribuir)),
            Prop("align", .opcao(alinhar)),
        ])
    }
    public static func column(maximo: Int = 100) -> Componente {
        Componente(nome: "Column", descricao: "Coluna.", props: [
            Prop("children", .filhos(maximo: maximo), obrigatoria: true),
            Prop("justify", .opcao(distribuir)),
            Prop("align", .opcao(alinhar)),
        ])
    }
    public static let divider = Componente(nome: "Divider", descricao: "Linha divisória.", props: [
        Prop("axis", .opcao(["horizontal", "vertical"])),
    ])
    public static func icon(nomes: [String]) -> Componente {
        Componente(nome: "Icon", descricao: "Ícone da lista.", props: [
            Prop("name", .opcao(nomes), obrigatoria: true),
        ])
    }
    /// Todas as funções da especificação, menos `openUrl`, que abriria
    /// qualquer endereço.
    public static let funcoesSeguras = [
        "add", "subtract", "multiply", "divide", "equals", "not_equals", "greater_than", "less_than",
        "and", "or", "not", "capitalize", "contains", "starts_with", "ends_with", "required", "regex",
        "length", "numeric", "email", "formatString", "formatNumber", "formatCurrency", "formatDate",
        "pluralize", "now",
    ]
}

/// As capacidades nativas do pacote.
public enum Nativos {
    public static let lembrete = Componente(
        nome: "Lembrete",
        descricao: "Lembrete no aparelho. Mostra o título e a hora; só agenda depois do toque.",
        props: [
            Prop("titulo", .texto(maximo: 60), obrigatoria: true),
            Prop("quando", .texto(maximo: 16), obrigatoria: true, descricao: "Data e hora locais: AAAA-MM-DDTHH:MM."),
        ],
        permissao: "notificacoes"
    )
    public static let agendarLembrete = Acao(
        nome: "agendar_lembrete", descricao: "Avisa que o lembrete foi agendado.",
        tipo: .doApp, contexto: ["titulo", "quando"]
    )
}

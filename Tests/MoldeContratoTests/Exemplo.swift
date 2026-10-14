import MoldeContrato

/// Contrato pequeno, sem nada de app real.
enum Exemplo {
    static let contrato = Contrato(
        prefixo: "exemplo.molde:teste",
        versao: "1",
        componentes: [
            Basicos.text(maximo: 40), Basicos.button, Basicos.card, Basicos.list(maximo: 5),
            Basicos.column(maximo: 6), Basicos.row(maximo: 3), Basicos.divider,
            Basicos.icon(nomes: ["star", "info"]), Nativos.lembrete,
        ],
        acoes: [
            Acao(nome: "abrir_item", descricao: "Abre um item.", tipo: .doApp, contexto: ["id"]),
            Acao(nome: "apagar_tudo", descricao: "Apaga tudo.", tipo: .doApp, irreversivel: true),
            Nativos.agendarLembrete,
        ],
        funcoes: ["formatString", "pluralize"],
        caminhosPublicados: ["/itens", "/resumo"]
    )
    static var manifesto: Manifesto { Manifesto(contrato: contrato) }
}

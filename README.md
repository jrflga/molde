<p align="center"><img src="docs/logo.png" width="160" alt="Logo do Molde: uma forma desenhada à caneta azul, com cavidades de cartão, ícone e botão; o botão sai da forma"></p>

# Molde

Telas que a IA monta com os componentes do seu app. O agente responde com
mensagens [A2UI 0.9.1](https://a2ui.org): layout, dados e ligações, nunca
código. O Molde confere cada mensagem contra o catálogo do app e só então
desenha, com componentes compilados no binário.

- **O catálogo é do app.** Você declara os componentes, as props, os limites
  e as ações. O agente recebe isso como manifesto e não sai dele.
- **Nada quebrado na tela.** Componente desconhecido, texto longo demais ou
  ação que não existe voltam ao agente como erro, antes de desenhar.
- **Ação irreversível fica no app.** Ela é declarada no manifesto para ser
  recusada: só um botão do próprio app a dispara.
- **Telas que se refazem.** Uma tela ligada só aos dados que o app publica
  pode ficar fixa e se refazer com os dados do momento, sem chamar a IA.

Swift 6, iOS 17+ e macOS 14+. Desenha com o renderer SwiftUI do
[A2UI-Swift](https://github.com/BBC6BAE9/a2ui-swift), por um fork
([Cadeia de dependências](#cadeia-de-dependências)).

[Começar](#começar) · [O contrato](#o-contrato) ·
[O loop do agente](#o-loop-do-agente) · [A regra 2.5.2](#a-fronteira-da-regra-252) ·
[Cadeia de dependências](#cadeia-de-dependências) · [O comando do Mac](#o-comando-do-mac)

## Começar

1. Adicione o pacote `https://github.com/jrflga/molde`, com `exact: "0.1.1"`.
   O `MoldeContrato` não tem tela; o `Molde` desenha; o `MoldeInspector` só
   existe em DEBUG.
2. Declare o catálogo e gere o manifesto:

   ```swift
   import MoldeContrato

   let contrato = Contrato(
       prefixo: "com.exemplo.app:molde",
       versao: "1",
       componentes: [
           Basicos.text(maximo: 120), Basicos.button, Basicos.card,
           Basicos.list(maximo: 5), Basicos.column(maximo: 8),
           Nativos.lembrete,
       ],
       acoes: [
           Acao(nome: "abrir_item", descricao: "Abre um item.", tipo: .doApp, contexto: ["id"]),
           Acao(nome: "apagar_tudo", descricao: "Só no botão do app.", tipo: .doApp, irreversivel: true),
           Nativos.agendarLembrete,
       ],
       funcoes: ["formatString", "pluralize"],
       caminhosPublicados: ["/itens"]
   )
   let manifesto = Manifesto(contrato: contrato)
   // manifesto.json vai para o agente; manifesto.catalogId vai no createSurface.
   ```

3. Confira o que o agente mandou e desenhe:

   ```swift
   import Molde

   let erros = Validador(manifesto: manifesto).validar(mensagens)
   if erros.isEmpty {
       let superficie = try SuperficieDoMolde(mensagens: mensagens, manifesto: manifesto)
       superficie.publicar(.objeto(["itens": itensDoApp]))
       // na view:
       TelaDoMolde(superficie: superficie, dominio: MeusComponentes()) { acao in
           // acao.nome, acao.contexto
       }
   } else {
       // erros.map(\.paraOAgente) volta ao agente, uma vez
   }
   ```

   `MeusComponentes` é um `CustomComponentCatalog` do A2UI-Swift com os
   visuais do app. O `LeitorDeProps` lê as props já resolvidas contra os
   dados.

## O contrato

São três camadas:

- **Básicos** (`Basicos`): Text, Button, Card, List, Row, Column, Divider e
  Icon, com as props da especificação 0.9.1 e os limites que o app escolhe.
- **Visuais do app:** componentes próprios, com props tipadas e os caminhos de
  dados que leem.
- **Capacidades nativas** (`Nativos`): hoje, o lembrete. Ele só pede
  permissão e só agenda depois de um toque.

O manifesto segue o formato de catálogo da especificação, mais as chaves
`x-molde` (ações, caminhos publicados, versão). O `catalogId` leva o prefixo,
a versão e uma marca do conteúdo: mudou o catálogo, muda o id.

A validação tem cinco regras, e o código vai no começo da `message` do erro
`VALIDATION_FAILED` da especificação:

| Código | Quando |
|---|---|
| `fora_do_manifesto` | Componente, prop, ação ou função que o catálogo não tem |
| `fora_do_limite` | Texto longo, filhos demais, opção fora da lista, mais de uma ação principal |
| `acao_irreversivel` | Ação marcada como irreversível vinda do agente |
| `manifesto_errado` | `catalogId` de outro manifesto |
| `formato` | Mensagem fora do formato, falta de prop obrigatória ou do componente `root` |

## O loop do agente

O transporte é do app: o Molde não faz rede. O app manda o pedido e o
manifesto, recebe as mensagens, valida e, se falhar, devolve os erros ao
agente **uma vez**. Na segunda falha, mostra que não conseguiu montar a tela e
fica com o texto da resposta. Um toque vira ação estruturada, com nome e
contexto: a ação do app o app executa; a do agente vai para ele.

## A fronteira da regra 2.5.2

O app muda dados, nunca código.

- Nenhum código executável chega depois da revisão: sem JS, sem bytecode, sem
  componente definido de fora.
- O catálogo e o manifesto só mudam com uma versão nova do app, que passa pela
  revisão.
- O JSON do A2UI carrega só layout, dados e ligações. As expressões ficam nas
  funções da própria especificação (formatação, validação, lógica booleana); o
  pacote não registra função própria que rode lógica vinda de fora. A
  `openUrl` fica de fora dos básicos seguros.
- Um toque vira ação estruturada para o agente. No aparelho, nada roda além do
  que o componente já faz.

Modelo de nota para a revisão da Apple, em inglês:

> The assistant only composes UI from components compiled into this binary and
> reviewed with it. Messages carry layout, data and bindings, never executable
> code; unknown components are rejected before rendering.

## Cadeia de dependências

Nada de código vivo de outra pessoa:

- [`jrflga/a2ui-swift`](https://github.com/jrflga/a2ui-swift), tag
  `0.3.5-jrflga.2`, fork do A2UI-Swift (base `16476ba`, depois da v0.3.5);
- [`jrflga/swift-json-schema`](https://github.com/jrflga/swift-json-schema),
  tag `0.13.2-jrflga.2`, fork que o A2UI-Swift usa;
- `swift-collections` 1.2.1 e `swift-syntax` 604.0.0, da Apple e do
  swiftlang, em versão exata. O swift-collections fica na 1.2.1 porque as
  seguintes exigem Swift 6.2, e o pacote compila também no Xcode 16.

Toda dependência entra com `exact:`, e o `Package.resolved` vai no Git.
Atualizar a partir do original é um passo revisado: puxar, ler o diff e marcar
a versão. O `FORK.md` de cada fork explica como.

## O comando do Mac

```bash
git clone https://github.com/jrflga/molde && cd molde
swift build -c release --product molde
.build/release/molde validar mensagens.json --manifesto manifesto.json
```

O arquivo de mensagens é uma lista JSON ou uma mensagem por linha (JSONL).
Válido, sai com 0. Com erro, imprime um `VALIDATION_FAILED` por linha e sai
com 1. Serve para avaliar um agente fora do app.

## Licença

MIT. Os exemplos em `Tests/MoldeTests/Exemplos` são da especificação A2UI, sob
Apache 2.0.

import Foundation
import MoldeContrato

// molde validar <mensagens.json|.jsonl> --manifesto <manifesto.json>
let argumentos = CommandLine.arguments
guard argumentos.count == 5, argumentos[1] == "validar", argumentos[3] == "--manifesto" else {
    FileHandle.standardError.write(Data("uso: molde validar <mensagens.json|.jsonl> --manifesto <manifesto.json>\n".utf8))
    exit(2)
}
do {
    let manifesto = try Manifesto(json: JSON(dados: Data(contentsOf: URL(fileURLWithPath: argumentos[4]))))
    let texto = try String(contentsOfFile: argumentos[2], encoding: .utf8)
    let mensagens: [JSON]
    if case .lista(let lista)? = try? JSON(dados: Data(texto.utf8)) {
        mensagens = lista
    } else {
        mensagens = try texto.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { try JSON(dados: Data($0.utf8)) }
    }
    let erros = Validador(manifesto: manifesto).validar(mensagens)
    if erros.isEmpty { print("válido: \(mensagens.count) mensagens"); exit(0) }
    for erro in erros { print(String(decoding: try erro.paraOAgente.dados(), as: UTF8.self)) }
    exit(1)
} catch {
    FileHandle.standardError.write(Data("molde: \(error)\n".utf8))
    exit(2)
}

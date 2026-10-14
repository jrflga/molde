import Foundation

/// O JSON das mensagens e do manifesto, sem depender de ninguém: o
/// `MoldeContrato` roda no iPhone e no Mac.
public enum JSON: Hashable, Sendable, Codable {
    case texto(String)
    case numero(Double)
    case booleano(Bool)
    case nulo
    case lista([JSON])
    case objeto([String: JSON])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .nulo }
        else if let v = try? c.decode(Bool.self) { self = .booleano(v) }
        else if let v = try? c.decode(Double.self) { self = .numero(v) }
        else if let v = try? c.decode(String.self) { self = .texto(v) }
        else if let v = try? c.decode([JSON].self) { self = .lista(v) }
        else { self = .objeto(try c.decode([String: JSON].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .texto(let v): try c.encode(v)
        case .numero(let v): try c.encode(v)
        case .booleano(let v): try c.encode(v)
        case .nulo: try c.encodeNil()
        case .lista(let v): try c.encode(v)
        case .objeto(let v): try c.encode(v)
        }
    }

    public init(dados: Data) throws { self = try JSONDecoder().decode(JSON.self, from: dados) }

    /// Chaves em ordem: o hash do manifesto não pode mudar de uma execução
    /// para outra.
    public func dados() throws -> Data {
        let codificador = JSONEncoder()
        codificador.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try codificador.encode(self)
    }

    public var comoTexto: String? { if case .texto(let v) = self { v } else { nil } }
    public var comoNumero: Double? { if case .numero(let v) = self { v } else { nil } }
    public var comoLista: [JSON]? { if case .lista(let v) = self { v } else { nil } }
    public var comoObjeto: [String: JSON]? { if case .objeto(let v) = self { v } else { nil } }
    public subscript(_ chave: String) -> JSON? { comoObjeto?[chave] }
}

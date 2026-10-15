#!/usr/bin/env swift
// Molde: esferográfica azul sobre papel creme. Uma forma com cavidades no
// formato de componentes (um cartão, um ícone, uma pílula); a pílula sai da
// forma. A caneta é a do logo do caixa-preta.
// Sem dependências. Uso: xcrun swift ferramentas/gerar-logo.swift docs/logo.png
// Sementes fixas: o resultado se repete.
import AppKit
import CoreGraphics

let destino = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/logo.png")
let papel = CGColor(srgbRed: 0.973, green: 0.949, blue: 0.894, alpha: 1)
struct Sorteio {
    var estado: UInt64 = 20261014
    mutating func entre(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        estado &+= 0x9E3779B97F4A7C15
        var z = estado
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return a + (b-a) * CGFloat(z >> 11) / CGFloat(UInt64(1) << 53)
    }
}
func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x:x,y:y) }

// A forma vista de cima, em perspectiva baixa: x corre da quina esquerda para
// a da frente, y vai para o fundo, z desce. Um único mapa para tudo, para as
// cavidades e a peça ficarem no mesmo plano.
let quina = p(196,600)
let eixoX = p(440.0/440, 70.0/440)      // 440 de largura
let eixoY = p(172.0/210, -122.0/210)    // 210 de fundo
func tela(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat = 0) -> CGPoint {
    p(quina.x + x*eixoX.x + y*eixoY.x, quina.y + x*eixoX.y + y*eixoY.y + z)
}
func noPlano(_ pontos: [CGPoint], z: CGFloat = 0, deslocar: CGPoint = .zero) -> [CGPoint] {
    pontos.map { let q = tela($0.x, $0.y, z); return p(q.x+deslocar.x, q.y+deslocar.y) }
}
func retanguloRedondo(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat, raio r: CGFloat) -> [CGPoint] {
    var pts: [CGPoint] = []
    let cantos = [(x1-r, y0+r, -CGFloat.pi/2), (x1-r, y1-r, 0), (x0+r, y1-r, CGFloat.pi/2), (x0+r, y0+r, CGFloat.pi)]
    for (cx, cy, inicio) in cantos {
        for k in 0...10 {
            let ang = inicio + CGFloat(k)/10 * .pi/2
            pts.append(p(cx + r*cos(ang), cy + r*sin(ang)))
        }
    }
    return pts + [pts[0]]
}
func circulo(_ cx: CGFloat, _ cy: CGFloat, raio r: CGFloat) -> [CGPoint] {
    (0...56).map { let a = CGFloat($0)/56 * 2 * .pi; return p(cx + r*cos(a), cy + r*sin(a)) }
}
func girar(_ pontos: [CGPoint], _ angulo: CGFloat) -> [CGPoint] {
    let cx = pontos.map(\.x).reduce(0,+)/CGFloat(pontos.count), cy = pontos.map(\.y).reduce(0,+)/CGFloat(pontos.count)
    return pontos.map { p(cx + ($0.x-cx)*cos(angulo) - ($0.y-cy)*sin(angulo), cy + ($0.x-cx)*sin(angulo) + ($0.y-cy)*cos(angulo)) }
}

func desenhar(lado: Int) -> Data {
    var rng = Sorteio()
    let ctx = CGContext(data:nil, width:lado, height:lado, bitsPerComponent:8,
        bytesPerRow:0, space:CGColorSpace(name:CGColorSpace.sRGB)!,
        bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.translateBy(x:0,y:CGFloat(lado))
    ctx.scaleBy(x:CGFloat(lado)/1024,y:CGFloat(-lado)/1024)
    ctx.setFillColor(papel)
    ctx.fill(CGRect(x:0,y:0,width:1024,height:1024))
    ctx.translateBy(x:512,y:512)
    ctx.scaleBy(x:1.22,y:1.22)
    ctx.translateBy(x:-505,y:-548)

    // A linha vira uma fita preenchida: largura e desvio variam devagar, sem
    // bolinhas nas emendas. O tremido é pequeno, sem ruído artificial.
    func caneta(_ pontos: [CGPoint], largura: CGFloat = 6.4,
                tremido: CGFloat = 2.4, alfa: CGFloat = 0.86) {
        let f1 = rng.entre(0,2 * .pi), f2 = rng.entre(0,2 * .pi)
        let desloc = rng.entre(-0.8,0.8)
        var linha: [CGPoint] = []
        var dist: CGFloat = 0
        for (a,b) in zip(pontos,pontos.dropFirst()) {
            let dx = b.x-a.x, dy = b.y-a.y, len = max(0.001,hypot(dx,dy))
            let n = max(1,Int(len/3))
            for i in (linha.isEmpty ? 0 : 1)...n {
                let t = CGFloat(i)/CGFloat(n), s = dist + t*len
                let w = tremido * (0.65*sin(s/39+f1)+0.25*sin(s/13+f2)) + desloc
                linha.append(p(a.x+dx*t-dy/len*w,a.y+dy*t+dx/len*w))
            }
            dist += len
        }
        guard linha.count > 1 else { return }
        var esq:[CGPoint] = [], dir:[CGPoint] = []
        for (i,pt) in linha.enumerated() {
            let a = linha[max(0,i-1)], b = linha[min(linha.count-1,i+1)]
            let dx = b.x-a.x, dy = b.y-a.y, len = max(0.001,hypot(dx,dy))
            let t = CGFloat(i)/CGFloat(linha.count-1)
            let ponta = min(1,min(t,1-t)*dist/9)
            let w = largura/2 * (0.8+0.2*sin(t*11+f1)) * (0.6+0.4*ponta)
            esq.append(p(pt.x-dy/len*w,pt.y+dx/len*w))
            dir.append(p(pt.x+dy/len*w,pt.y-dx/len*w))
        }
        ctx.setFillColor(CGColor(srgbRed:0.105,green:0.205,blue:0.57,alpha:alfa))
        ctx.addLines(between:esq+dir.reversed())
        ctx.closePath(); ctx.fillPath()
    }
    func caminho(_ pontos: [CGPoint]) { ctx.addLines(between:pontos); ctx.closePath() }
    func cobrir(_ pontos: [CGPoint]) { ctx.setFillColor(papel); caminho(pontos); ctx.fillPath() }
    /// Recorta `dentro` menos `fora` e desenha ali.
    func recortado(dentro: [CGPoint], fora: [CGPoint]? = nil, _ desenho: () -> Void) {
        ctx.saveGState()
        caminho(dentro); ctx.clip()
        if let fora {
            ctx.addRect(CGRect(x:-2000,y:-2000,width:6000,height:6000)); caminho(fora)
            ctx.clip(using:.evenOdd)
        }
        desenho()
        ctx.restoreGState()
    }
    /// Riscos paralelos de tinta, inclinados, cobrindo uma faixa da tela.
    func hachura(de x0: CGFloat, ate x1: CGFloat, y0: CGFloat, y1: CGFloat, inclinacao: CGFloat,
                 passo: ClosedRange<CGFloat>, largura: ClosedRange<CGFloat>, alfa: CGFloat) {
        var x = x0
        while x < x1 {
            caneta([p(x+rng.entre(-2,2), y0+rng.entre(-6,6)), p(x+inclinacao+rng.entre(-4,4), y1+rng.entre(-6,6))],
                   largura:rng.entre(largura.lowerBound,largura.upperBound), tremido:1.4, alfa:alfa)
            x += rng.entre(passo.lowerBound, passo.upperBound)
        }
    }

    // A forma: tampo (a b c d), espessura h, face da frente e face da direita.
    let h: CGFloat = 76
    let a = tela(0,0), b = tela(0,210), c = tela(440,210), d = tela(440,0)
    let a1 = tela(0,0,h), d1 = tela(440,0,h), c1 = tela(440,210,h)

    // A face da direita fica escura, só de riscos de tinta, como no caixa-preta.
    recortado(dentro:[d,c,c1,d1]) {
        hachura(de:d.x-130, ate:c.x+40, y0:c.y-30, y1:d1.y+40, inclinacao:-110,
                passo:4.6...7.4, largura:2.2...3.6, alfa:0.78)
    }

    // As cavidades: a borda, a parede do fundo na sombra e a linha do fundo.
    let fundo: CGFloat = 30
    // A emenda do contorno vai para o fundo da cavidade, onde não aparece, e
    // o traço passa um pouco do começo para não deixar falha.
    func comEmendaNoFundo(_ forma: [CGPoint]) -> [CGPoint] {
        let aberta = Array(forma.dropLast())
        let i = aberta.indices.max { aberta[$0].y < aberta[$1].y }!
        let girada = Array(aberta[i...] + aberta[..<i])
        return girada + girada.prefix(4)
    }
    func cavidade(_ forma: [CGPoint]) {
        let borda = noPlano(forma), baixo = noPlano(forma, z:fundo)
        recortado(dentro:borda, fora:baixo) {
            let xs = borda.map(\.x), ys = borda.map(\.y)
            hachura(de:xs.min()!-30, ate:xs.max()!+10, y0:ys.min()!-6, y1:ys.max()!+6, inclinacao:-22,
                    passo:5.0...8.0, largura:1.6...2.6, alfa:0.6)
        }
        recortado(dentro:borda) { caneta(noPlano(comEmendaNoFundo(forma), z:fundo), largura:2.4, tremido:1.2, alfa:0.6) }
        caneta(noPlano(comEmendaNoFundo(forma)), largura:4.4, tremido:1.6, alfa:0.88)
    }
    let cartao = retanguloRedondo(28, 30, 196, 182, raio:20)
    let icone = circulo(268, 62, raio:30)
    let pilula = retanguloRedondo(236, 120, 410, 174, raio:27)
    cavidade(cartao)
    cavidade(icone)
    cavidade(pilula)
    // No fundo do cartão, as marcas da tela que ele molda: duas linhas.
    caneta(noPlano([p(62,140),p(150,140)], z:fundo-4), largura:3.0, tremido:0.8, alfa:0.55)
    caneta(noPlano([p(62,112),p(124,112)], z:fundo-4), largura:2.6, tremido:0.8, alfa:0.5)

    // O contorno da forma, levantando a caneta entre as arestas.
    caneta([a,b,c], largura:5.6)
    caneta([c,d,a], largura:6.8)
    caneta([a,a1,d1], largura:7.0)
    caneta([d,d1,c1,c], largura:7.0)
    // Poucos repasses leves e incompletos.
    caneta([tela(6,4),tela(4,150)], largura:1.8, tremido:2.0, alfa:0.42)
    caneta([tela(20,0,h+3),tela(260,0,h+4)], largura:1.8, tremido:1.6, alfa:0.4)

    // A pílula que saiu: com espessura, um pouco girada, acima da cavidade.
    let subida = p(26,-178)
    let peca = girar(pilula, -0.12)
    let espessura = fundo
    let topo = noPlano(peca, deslocar:subida)
    let base = noPlano(peca, z:espessura, deslocar:subida)
    // Riscos de movimento entre a peça e a cavidade.
    for (i, x) in [612.0, 650.0, 688.0].enumerated() {
        let y = 452 + CGFloat(i)*6
        caneta([p(x,y),p(x-4,y+34)], largura:2.2, tremido:0.8, alfa:0.5)
    }
    for z in stride(from:0, through:espessura, by:2) { cobrir(noPlano(peca, z:z, deslocar:subida)) }
    recortado(dentro:base, fora:topo) {
        let xs = base.map(\.x), ys = base.map(\.y)
        hachura(de:xs.min()!-30, ate:xs.max()!+10, y0:ys.min()!, y1:ys.max()!+4, inclinacao:-14,
                passo:6.0...9.0, largura:1.4...2.2, alfa:0.48)
    }
    recortado(dentro:base, fora:topo) { caneta(base, largura:5.2, tremido:1.4, alfa:0.86) }
    // As laterais da peça: onde o topo é mais à esquerda e mais à direita.
    let esquerda = topo.min { $0.x < $1.x }!, direita = topo.max { $0.x < $1.x }!
    caneta([esquerda, p(esquerda.x, esquerda.y+espessura)], largura:5.0, tremido:0.6, alfa:0.86)
    caneta([direita, p(direita.x, direita.y+espessura)], largura:5.0, tremido:0.6, alfa:0.86)
    caneta(noPlano(comEmendaNoFundo(peca), deslocar:subida), largura:5.6, tremido:1.6, alfa:0.9)

    return NSBitmapImageRep(cgImage:ctx.makeImage()!).representation(using:.png,properties:[:])!
}

// Desenha em 4× e reduz: as hachuras viram densidade de tinta, sem serrilhado.
func reduzir(_ data: Data, lado: Int) -> Data {
    let src = NSBitmapImageRep(data:data)!.cgImage!
    let ctx = CGContext(data:nil,width:lado,height:lado,bitsPerComponent:8,bytesPerRow:0,
        space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(src,in:CGRect(x:0,y:0,width:lado,height:lado))
    return NSBitmapImageRep(cgImage:ctx.makeImage()!).representation(using:.png,properties:[:])!
}
try reduzir(desenhar(lado:4096), lado:1024).write(to:destino)
print("Gerado \(destino.path)")

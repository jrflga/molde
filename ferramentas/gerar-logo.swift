#!/usr/bin/env swift
// Molde: esferográfica azul sobre papel creme. Um molde aberto com uma tela
// saindo de dentro. A caneta é a do caixa-preta, num esboço mais solto.
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
    ctx.scaleBy(x:1.2,y:1.2)
    ctx.translateBy(x:-512,y:-530)

    // A linha vira uma fita preenchida: largura e desvio variam devagar, sem
    // bolinhas nas emendas.
    func caneta(_ pontos: [CGPoint], largura: CGFloat = 6.8,
                tremido: CGFloat = 3.3, alfa: CGFloat = 0.84) {
        let f1 = rng.entre(0,2 * .pi), f2 = rng.entre(0,2 * .pi)
        let desloc = rng.entre(-1.0,1.0)
        var linha: [CGPoint] = []
        var dist: CGFloat = 0
        for (a,b) in zip(pontos,pontos.dropFirst()) {
            let dx = b.x-a.x, dy = b.y-a.y, len = max(0.001,hypot(dx,dy))
            let n = max(2,Int(len/3))
            for i in (linha.isEmpty ? 0 : 1)...n {
                let t = CGFloat(i)/CGFloat(n), s = dist + t*len
                let w = tremido * (0.65*sin(s/39+f1)+0.25*sin(s/13+f2)) + desloc
                linha.append(p(a.x+dx*t-dy/len*w,a.y+dy*t+dx/len*w))
            }
            dist += len
        }
        var esq:[CGPoint] = [], dir:[CGPoint] = []
        for (i,pt) in linha.enumerated() {
            let a = linha[max(0,i-1)], b = linha[min(linha.count-1,i+1)]
            let dx = b.x-a.x, dy = b.y-a.y, len = max(0.001,hypot(dx,dy))
            let t = CGFloat(i)/CGFloat(linha.count-1)
            let ponta = min(1,min(t,1-t)*dist/9)
            let w = largura/2 * (0.78+0.22*sin(t*13+f1)) * (0.6+0.4*ponta)
            esq.append(p(pt.x-dy/len*w,pt.y+dx/len*w))
            dir.append(p(pt.x+dy/len*w,pt.y-dx/len*w))
        }
        ctx.setFillColor(CGColor(srgbRed:0.105,green:0.205,blue:0.57,alpha:alfa))
        ctx.addLines(between:esq+dir.reversed())
        ctx.closePath(); ctx.fillPath()
    }
    func cobrir(_ pontos: [CGPoint]) {
        ctx.setFillColor(papel)
        ctx.addLines(between:pontos); ctx.closePath(); ctx.fillPath()
    }
    func hachurar(dentro poligono: [CGPoint], _ riscos: () -> Void) {
        ctx.saveGState()
        ctx.addLines(between:poligono); ctx.closePath(); ctx.clip()
        riscos()
        ctx.restoreGState()
    }
    // Esboço rápido: um traço firme e fino, e um segundo passe solto ao lado,
    // que às vezes passa um pouco da ponta.
    func esboco(_ pontos: [CGPoint], largura: CGFloat = 4.8) {
        caneta(pontos, largura: largura, tremido: 2.6, alfa: 0.88)
        let dx = rng.entre(-5,5), dy = rng.entre(-4,4)
        var solto = pontos.map { p($0.x+dx+rng.entre(-2,2), $0.y+dy+rng.entre(-2,2)) }
        let passa = rng.entre(0.0,0.06)
        if solto.count > 1 {
            let a = solto[0], b = solto[1]
            solto[0] = p(a.x-(b.x-a.x)*passa, a.y-(b.y-a.y)*passa)
        }
        caneta(solto, largura: largura*0.4, tremido: 3.6, alfa: 0.4)
    }
    // Cantos arredondados, para a tela parecer tela.
    func arredondar(_ cantos: [CGPoint], raio: CGFloat) -> [CGPoint] {
        var saida: [CGPoint] = []
        for i in cantos.indices {
            let ant = cantos[(i+cantos.count-1) % cantos.count], c = cantos[i], prox = cantos[(i+1) % cantos.count]
            func rumo(_ para: CGPoint) -> CGPoint {
                let l = hypot(para.x-c.x, para.y-c.y); return p((para.x-c.x)/l, (para.y-c.y)/l)
            }
            let u = rumo(ant), v = rumo(prox)
            let p0 = p(c.x+u.x*raio, c.y+u.y*raio), p2 = p(c.x+v.x*raio, c.y+v.y*raio)
            for k in 0...6 {
                let t = CGFloat(k)/6
                saida.append(p((1-t)*(1-t)*p0.x + 2*(1-t)*t*c.x + t*t*p2.x,
                               (1-t)*(1-t)*p0.y + 2*(1-t)*t*c.y + t*t*p2.y))
            }
        }
        return saida + [saida[0]]
    }

    // O molde: borda de fora (a b c d), borda de dentro (a2 b2 c2 d2) e a
    // profundidade (e f g), na perspectiva baixa do caixa-preta.
    let a = p(227,600), b = p(374,515), c = p(795,560), d = p(650,650)
    let e = p(647,790), f = p(231,735), g = p(791,700)
    let a2 = p(268,600), b2 = p(381,535), c2 = p(752,567), d2 = p(642,632)

    // 1. A parede de dentro, no fundo, fica na sombra: riscos curtos e leves.
    hachurar(dentro:[a2,b2,c2,d2]) {
        var t: CGFloat = 0
        while t < 1 {
            let x = 381 + (752-381)*t
            let topo = 535 + (567-535)*t
            caneta([p(x+rng.entre(-3,3),topo-6),p(x-18+rng.entre(-6,6),topo+54+rng.entre(-12,12))],
                   largura:rng.entre(1.4,2.2),tremido:1.6,alfa:0.42)
            t += rng.entre(0.014,0.026)
        }
    }

    // As bordas do fundo ficam atrás da tela.
    esboco([a,b,c])
    caneta([a2,b2,c2],largura:2.6,tremido:2.2,alfa:0.62)

    // 2. A tela que sai do molde, de cantos redondos: por cima da parede do fundo.
    let tela = arredondar([p(446,250),p(618,262),p(590,690),p(414,680)], raio:26)
    cobrir(tela)
    esboco(tela, largura:5.0)
    // O que a tela mostra: duas linhas de texto e um botão em pílula.
    caneta([p(480,320),p(586,327)],largura:4.2,tremido:1.4,alfa:0.78)
    caneta([p(478,362),p(550,366)],largura:3.8,tremido:1.2,alfa:0.66)
    esboco(arredondar([p(478,420),p(574,426),p(573,452),p(477,446)], raio:12), largura:3.4)

    // 3. As paredes da frente cobrem a parte da tela que ainda está dentro.
    cobrir([a,d,d2,a2])
    cobrir([a,d,e,f])
    cobrir([d,c,g,e])
    cobrir([d,c,c2,d2])

    // 4. A face da direita fica escura em hachura cruzada.
    hachurar(dentro:[p(654,652),p(790,566),p(786,698),p(651,786)]) {
        var x: CGFloat = 625
        while x < 960 {
            caneta([p(x+rng.entre(-3,3),540+rng.entre(-20,20)),p(x-120+rng.entre(-14,14),820+rng.entre(-18,18))],
                   largura:rng.entre(1.6,2.6),tremido:2.4,alfa:0.62)
            x += rng.entre(7.0,11.0)
        }
        var y: CGFloat = 640
        while y < 860 {
            caneta([p(636+rng.entre(-10,10),y),p(808,y-104+rng.entre(-16,16))],
                   largura:rng.entre(1.3,2.0),tremido:1.8,alfa:0.46)
            y += rng.entre(11,18)
        }
    }

    // 5. O contorno, levantando a caneta entre as arestas.
    esboco([c,d,a], largura:5.2)
    caneta([c2,d2,a2],largura:3.2,tremido:2.0,alfa:0.72)
    esboco([a,f,e], largura:5.4)
    esboco([d,e,g,c], largura:5.4)

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

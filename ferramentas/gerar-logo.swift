#!/usr/bin/env swift
// Molde: esferográfica azul sobre papel creme. Um molde aberto com uma tela
// saindo de dentro. A caneta é a mesma do logo do caixa-preta.
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

    // O molde: borda de fora (a b c d), borda de dentro (a2 b2 c2 d2) e a
    // profundidade (e f g), na perspectiva baixa do caixa-preta.
    let a = p(227,600), b = p(374,515), c = p(795,560), d = p(650,650)
    let e = p(647,790), f = p(231,735), g = p(791,700)
    let a2 = p(268,600), b2 = p(381,535), c2 = p(752,567), d2 = p(642,632)

    // 1. A parede de dentro, no fundo, fica na sombra: riscos curtos.
    hachurar(dentro:[a2,b2,c2,d2]) {
        var t: CGFloat = 0
        while t < 1 {
            let x = 381 + (752-381)*t
            let topo = 535 + (567-535)*t
            caneta([p(x+rng.entre(-3,3),topo-6),p(x-18+rng.entre(-6,6),topo+58+rng.entre(-10,10))],
                   largura:rng.entre(1.8,2.8),tremido:1.6,alfa:0.5)
            t += rng.entre(0.012,0.022)
        }
    }

    // As bordas do fundo ficam atrás da tela.
    caneta([a,b,c],largura:6.4)
    caneta([a2,b2,c2],largura:3.6,tremido:2.2,alfa:0.7)
    caneta([p(233,598),p(366,514),p(460,524)],largura:2.0,tremido:2.1,alfa:0.5)

    // 2. A tela que sai do molde: por cima da parede do fundo.
    let tl = p(446,250), tr = p(618,262), br = p(590,690), bl = p(414,680)
    cobrir([tl,tr,br,bl])
    caneta([p(452,252),p(612,262)],largura:6.6)
    caneta([p(620,268),p(594,668)],largura:7.0)
    caneta([p(440,258),p(416,660)],largura:7.2)
    // O que a tela mostra: duas linhas de texto e um botão.
    caneta([p(478,318),p(588,325)],largura:5.4,tremido:1.4,alfa:0.8)
    caneta([p(476,364),p(552,368)],largura:5.0,tremido:1.2,alfa:0.72)
    caneta([p(478,432),p(570,438)],largura:13,tremido:1.0,alfa:0.86)

    // 3. As paredes da frente cobrem a parte da tela que ainda está dentro.
    cobrir([a,d,d2,a2])
    cobrir([a,d,e,f])
    cobrir([d,c,g,e])
    cobrir([d,c,c2,d2])

    // 4. A face da direita fica escura, só de riscos de tinta.
    hachurar(dentro:[p(654,652),p(790,566),p(786,698),p(651,786)]) {
        var x: CGFloat = 625
        while x < 960 {
            caneta([p(x+rng.entre(-3,3),540+rng.entre(-20,20)),p(x-120+rng.entre(-14,14),820+rng.entre(-18,18))],
                   largura:rng.entre(2.3,3.8),tremido:2.4,alfa:0.76)
            x += rng.entre(5.0,8.2)
        }
    }

    // 5. O contorno, levantando a caneta entre as arestas.
    caneta([c,d,a],largura:7.2)
    caneta([c2,d2,a2],largura:4.4,tremido:2.0,alfa:0.78)
    caneta([a,f,e],largura:7.4)
    caneta([d,e,g,c],largura:7.4)
    // Poucos repasses leves e incompletos.
    caneta([p(238,740),p(420,764),p(570,780)],largura:1.9,tremido:1.8,alfa:0.45)
    caneta([p(456,256),p(560,262)],largura:1.8,tremido:2.4,alfa:0.42)
    caneta([p(229,630),p(231,700)],largura:1.5,tremido:2.6,alfa:0.42)

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

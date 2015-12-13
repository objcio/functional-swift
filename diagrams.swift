import Cocoa

extension NSGraphicsContext {
    var cgContext: CGContextRef {
        let opaqueContext = COpaquePointer(self.graphicsPort)
        return Unmanaged<CGContextRef>.fromOpaque(opaqueContext)
            .takeUnretainedValue()
    }
}

extension SequenceType where Generator.Element == CGFloat {
    func normalize() -> [CGFloat] {
        let maxVal = self.reduce(0) { max($0, $1) }
        return self.map { $0 / maxVal }
    }
}


extension CGRect {
    func split(ratio: CGFloat, edge: CGRectEdge) -> (CGRect, CGRect) {
        let length = edge.isHorizontal ? width : height
        return divide(length * ratio, fromEdge: edge)
    }
}

extension CGRectEdge {
    var isHorizontal: Bool {
        return self == .MaxXEdge || self == .MinXEdge;
    }
}


func *(l: CGFloat, r: CGSize) -> CGSize {
    return CGSize(width: l * r.width, height: l * r.height)
}
func /(l: CGSize, r: CGSize) -> CGSize {
    return CGSize(width: l.width / r.width, height: l.height / r.height)
}
func *(l: CGSize, r: CGSize) -> CGSize {
    return CGSize(width: l.width * r.width, height: l.height * r.height)
}
func -(l: CGSize, r: CGSize) -> CGSize {
    return CGSize(width: l.width - r.width, height: l.height - r.height)
}
func -(l: CGPoint, r: CGPoint) -> CGPoint {
    return CGPoint(x: l.x - r.x, y: l.y - r.y)
}

extension CGSize {
    var point: CGPoint {
        return CGPoint(x: self.width, y: self.height)
    }
}

extension CGVector {
    var point: CGPoint { return CGPoint(x: dx, y: dy) }
    var size: CGSize { return CGSize(width: dx, height: dy) }
}


enum Primitive {
    case Ellipse
    case Rectangle
    case Text(String)
}

indirect enum Diagram {
    case Prim(CGSize, Primitive)
    case Beside(Diagram, Diagram)
    case Below(Diagram, Diagram)
    case Attributed(Attribute, Diagram)
    case Align(CGVector, Diagram)
}

enum Attribute {
    case FillColor(NSColor)
}

extension Diagram {
    var size: CGSize {
        switch self {
        case .Prim(let size, _):
            return size
        case .Attributed(_, let x):
            return x.size
        case .Beside(let l, let r):
            let sizeL = l.size
            let sizeR = r.size
            return CGSizeMake(sizeL.width + sizeR.width,
                max(sizeL.height, sizeR.height))
        case .Below(let l, let r):
            return CGSizeMake(max(l.size.width, r.size.width),
                l.size.height + r.size.height)
        case .Align(_, let r):
            return r.size
        }
    }
}


extension CGSize {
    func fit(vector: CGVector, _ rect: CGRect) -> CGRect {
        let scaleSize = rect.size / self
        let scale = min(scaleSize.width, scaleSize.height)
        let size = scale * self
        let space = vector.size * (size - rect.size)
        return CGRect(origin: rect.origin - space.point, size: size)
    }

}


extension CGContextRef {
    func draw(bounds: CGRect, _ diagram: Diagram) {
        switch diagram {
        case .Prim(let size, .Ellipse):
            let frame = size.fit(CGVector(dx: 0.5, dy: 0.5), bounds)
            CGContextFillEllipseInRect(self, frame)
            // <</drawEllipse>>
            // <<drawRectangle>>
        case .Prim(let size, .Rectangle):
            let frame = size.fit(CGVector(dx: 0.5, dy: 0.5), bounds)
            CGContextFillRect(self, frame)
            // <</drawRectangle>>
            // <<drawText>>
        case .Prim(let size, .Text(let text)):
            let frame = size.fit(CGVector(dx: 0.5, dy: 0.5), bounds)
            let font = NSFont.systemFontOfSize(12)
            let attributes = [NSFontAttributeName: font]
            let attributedText = NSAttributedString(string: text, attributes: attributes)
            attributedText.drawInRect(frame)
            // <</drawText>>
            // <<drawFill>>
        case .Attributed(.FillColor(let color), let d):
            CGContextSaveGState(self)
            color.set()
            draw(bounds, d)
            CGContextRestoreGState(self)
            // <</drawFill>>
            // <<drawBeside>>
        case .Beside(let left, let right):
            let (lFrame, rFrame) = bounds.split(
                left.size.width/diagram.size.width, edge: .MinXEdge)
            draw(lFrame, left)
            draw(rFrame, right)
            // <</drawBeside>>
            // <<drawBelow>>
        case .Below(let top, let bottom):
            let (lFrame, rFrame) = bounds.split(
                bottom.size.height/diagram.size.height, edge: .MinYEdge)
            draw(lFrame, bottom)
            draw(rFrame, top)
            // <</drawBelow>>
            // <<drawAlign>>
        case .Align(let vec, let diagram):
            let frame = diagram.size.fit(vec, bounds)
            draw(frame, diagram)
        }
    }
}


class Draw: NSView {
    let diagram: Diagram

    init(frame frameRect: NSRect, diagram: Diagram) {
        self.diagram = diagram
        super.init(frame:frameRect)
    }

    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }

    override func drawRect(dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.currentContext() else { return }
        context.cgContext.draw(self.bounds, diagram)
    }
}


extension Diagram {
    func pdf(width: CGFloat) -> NSData {
        let height = width * (size.height / size.width)
        let v = Draw(frame: NSMakeRect(0, 0, width, height), diagram: self)
        return v.dataWithPDFInsideRect(v.bounds)
    }
}


func rect(width width: CGFloat, height: CGFloat) -> Diagram {
    return .Prim(CGSizeMake(width, height), .Rectangle)
}

func circle(diameter diameter: CGFloat) -> Diagram {
    return .Prim(CGSizeMake(diameter, diameter), .Ellipse)
}

func text(theText: String, width: CGFloat, height: CGFloat) -> Diagram {
    return .Prim(CGSizeMake(width, height), .Text(theText))
}

func square(side side: CGFloat) -> Diagram {
    return rect(width: side, height: side)
}

infix operator ||| { associativity left }
func ||| (l: Diagram, r: Diagram) -> Diagram {
    return Diagram.Beside(l, r)
}

infix operator --- { associativity left }
func --- (l: Diagram, r: Diagram) -> Diagram {
    return Diagram.Below(l, r)
}

extension Diagram {
    func fill(color: NSColor) -> Diagram {
        return .Attributed(.FillColor(color), self)
    }

    func alignTop() -> Diagram {
        return .Align(CGVector(dx: 0.5, dy: 1), self)
    }

    func alignBottom() -> Diagram {
        return .Align(CGVector(dx: 0.5, dy: 0), self)
    }
}

let empty: Diagram = rect(width: 0, height: 0)

func hcat(diagrams: [Diagram]) -> Diagram {
    return diagrams.reduce(empty, combine: |||)
}



let blueSquare = square(side: 1).fill(.blueColor())
let redSquare = square(side: 2).fill(.redColor())
let greenCircle = circle(diameter: 1).fill(.greenColor())
let example1 = blueSquare ||| redSquare ||| greenCircle


let cyanCircle = circle(diameter: 1).fill(.cyanColor())
let example2 = blueSquare ||| cyanCircle ||| redSquare ||| greenCircle


func barGraph(input: [(String, Double)]) -> Diagram {
    let values: [CGFloat] = input.map { CGFloat($0.1) }
    let nValues = values.normalize()
    let bars = hcat(nValues.map { (x: CGFloat) -> Diagram in
        return rect(width: 1, height: 3 * x) .fill(.blackColor()).alignBottom()
        })
    let labels = hcat(input.map { x in
        return text(x.0, width: 1, height: 0.3).alignTop()
        })
    return bars --- labels
}

let cities = [
    "Shanghai": 14.01,
    "Istanbul": 13.3,
    "Moscow": 10.56,
    "New York": 8.33,
    "Berlin": 3.43
]

let example3 = barGraph(Array(cities))


CGSize(width: 1, height: 1).fit(
    CGVector(dx: 0.5, dy: 0.5), CGRect(x: 0, y: 0, width: 200, height: 100))

CGSize(width: 1, height: 1).fit(
    CGVector(dx: 0, dy: 0.5), CGRect(x: 0, y: 0, width: 200, height: 100))



// *********************************************
// This code generates example PDFs for the book
// *********************************************

func writepdf(name: String, _ diagram: Diagram) {
    guard Process.arguments.count > 1 else { fatalError("Need a base directory") }
    let baseURL = NSURL(fileURLWithPath: Process.arguments[1])
    let url = baseURL.URLByAppendingPathComponent("artwork/generated").URLByAppendingPathComponent(name + ".pdf")
    let data = diagram.pdf(300)
    data.writeToURL(url, atomically: true)
}

writepdf("example1", example1)
writepdf("example2", example2)

writepdf("example3", example3)

writepdf("example4", blueSquare ||| redSquare)
writepdf("example5", .Align(CGVector(dx: 0.5, dy: 1), blueSquare) ||| redSquare)

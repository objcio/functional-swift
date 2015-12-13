import Foundation

let numberOfIterations = 10

func check<X: Arbitrary, Y: Arbitrary>(message: String, _ property: (X, Y) -> Bool) -> () {
    let arbitraryTuple = { (X.arbitrary(), Y.arbitrary()) }
    let smaller: (X, Y) -> (X, Y)? = { (x, y) in
        guard let newX = x.smaller(), let newY = y.smaller() else { return nil }
        return (newX, newY)
    }
    let instance = ArbitraryInstance(arbitrary: arbitraryTuple, smaller: smaller)
    checkHelper(instance, property, message)
}

extension CGSize {
    func smaller() -> CGSize? {
        return nil
    }
}

extension CGFloat: Arbitrary {
    func smaller() -> CGFloat? {
        return nil
    }

    static func arbitrary() -> CGFloat {
        let random: CGFloat = CGFloat(arc4random())
        let maxUint = CGFloat(UInt32.max)
        return 10000 * ((random - maxUint/2) / maxUint)
    }
}

extension Character {
    func smaller() -> Character? { return nil }
}

func plusIsCommutative(x: Int, y: Int) -> Bool {
    return x + y == y + x
}

func minusIsCommutative(x: Int, y: Int) -> Bool {
    return x - y == y - x
}

extension Int: Arbitrary {
    static func arbitrary() -> Int {
        return Int(arc4random())
    }
}

extension Character: Arbitrary {
    static func arbitrary() -> Character {
        return Character(UnicodeScalar(Int.random(from: 65, to: 90)))
    }
}

func tabulate<A>(times: Int, transform: Int -> A) -> [A] {
    return (0..<times).map(transform)
}

extension Int {
    static func random(from from: Int, to: Int) -> Int {
        return from + (Int(arc4random()) % (to - from))
    }
}

extension String: Arbitrary {
    static func arbitrary() -> String {
        let randomLength = Int.random(from: 0, to: 40)
        let randomCharacters = tabulate(randomLength) { _ in
            Character.arbitrary()
        }
        return String(randomCharacters)
    }
}

func check1<A: Arbitrary>(message: String, _ property: A -> Bool) -> () {
    for _ in 0..<numberOfIterations {
        let value = A.arbitrary()
        guard property(value) else {
            print("\"\(message)\" doesn't hold: \(value)")
            return
        }
    }
    print("\"\(message)\" passed \(numberOfIterations) tests.")
}

extension CGSize {
    var area: CGFloat {
        return width * height
    }
}

extension CGSize: Arbitrary {
    static func arbitrary() -> CGSize {
        return CGSize(width: CGFloat.arbitrary(),
            height: CGFloat.arbitrary())
    }
}

protocol Smaller {
    func smaller() -> Self?
}

extension Int: Smaller {
    func smaller() -> Int? {
        return self == 0 ? nil : self / 2
    }
}

extension String: Smaller {
    func smaller() -> String? {
        return isEmpty ? nil : String(characters.dropFirst())
    }
}

protocol Arbitrary: Smaller {
    static func arbitrary() -> Self
}

func iterateWhile<A>(condition: A -> Bool, initial: A, next: A -> A?) -> A {
    if let x = next(initial) where condition(x) {
        return iterateWhile(condition, initial: x, next: next)
    }
    return initial
}

func check2<A: Arbitrary>(message: String, _ property: A -> Bool) -> () {
    for _ in 0..<numberOfIterations {
        let value = A.arbitrary()
        guard property(value) else {
            let smallerValue = iterateWhile({ !property($0) }, initial: value) {
                $0.smaller()
            }
            print("\"\(message)\" doesn't hold: \(smallerValue)")
            return
        }
    }
    print("\"\(message)\" passed \(numberOfIterations) tests.")
}

func qsort(var array: [Int]) -> [Int] {
    if array.isEmpty { return [] }
    let pivot = array.removeAtIndex(0)
    let lesser = array.filter { $0 < pivot }
    let greater = array.filter { $0 >= pivot }
    return qsort(lesser) + [pivot] + qsort(greater)
}

extension Array: Smaller {
    func smaller() -> [Element]? {
        guard !isEmpty else { return nil }
        return Array(dropFirst())
    }
}

extension Array where Element: Arbitrary {
    static func arbitrary() -> [Element] {
        let randomLength = Int(arc4random() % 50)
        return tabulate(randomLength) { _ in Element.arbitrary() }
    }
}

struct ArbitraryInstance<T> {
    let arbitrary: () -> T
    let smaller: T -> T?
}

func checkHelper<A>(arbitraryInstance: ArbitraryInstance<A>,
    _ property: A -> Bool, _ message: String) -> ()
{
    for _ in 0..<numberOfIterations {
        let value = arbitraryInstance.arbitrary()
        guard property(value) else {
            let smallerValue = iterateWhile({ !property($0) },
                initial: value, next: arbitraryInstance.smaller)
            print("\"\(message)\" doesn't hold: \(smallerValue)")
            return
        }
    }
    print("\"\(message)\" passed \(numberOfIterations) tests.")
}

func check<X: Arbitrary>(message: String, property: X -> Bool) -> () {
    let instance = ArbitraryInstance(arbitrary: X.arbitrary,
        smaller: { $0.smaller() })
    checkHelper(instance, property, message)
}

func check<X: Arbitrary>(message: String, _ property: [X] -> Bool) -> () {
    let instance = ArbitraryInstance(arbitrary: Array.arbitrary,
        smaller: { (x: [X]) in x.smaller() })
    checkHelper(instance, property, message)
}

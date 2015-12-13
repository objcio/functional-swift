//: # Prelude

func processInt(x: Int) -> Int { return x }


//: # Map, Filter, Reduce
//: ## Introducing Generics

func incrementArray(xs: [Int]) -> [Int] {
    var result: [Int] = []
    for x in xs {
        result.append(x + 1)
    }
    return result
}


func doubleArray1(xs: [Int]) -> [Int] {
    var result: [Int] = []
    for x in xs {
        result.append(x * 2)
    }
    return result
}


func computeIntArray(xs: [Int], transform: Int -> Int) -> [Int] {
    var result: [Int] = []
    for x in xs {
        result.append(transform(x))
    }
    return result
}


func doubleArray2(xs: [Int]) -> [Int] {
    return computeIntArray(xs) { x in x * 2 }
}


func genericComputeArray1<T>(xs: [Int], transform: Int -> T) -> [T] {
    var result: [T] = []
    for x in xs {
        result.append(transform(x))
    }
    return result
}


func map<Element, T>(xs: [Element], transform: Element -> T) -> [T] {
    var result: [T] = []
    for x in xs {
        result.append(transform(x))
    }
    return result
}


func genericComputeArray2<T>(xs: [Int], transform: Int -> T) -> [T] {
    return map(xs, transform: transform)
}


func genericComputeArray<T>(xs: [Int], transform: Int -> T) -> [T] {
    return xs.map(transform)
}

//: ### Top-Level Functions vs. Extensions
//: ## Filter

let exampleFiles = ["README.md", "HelloWorld.swift", "FlappyBird.swift"]


func getSwiftFiles(files: [String]) -> [String] {
    var result: [String] = []
    for file in files {
        if file.hasSuffix(".swift") {
            result.append(file)
        }
    }
    return result
}


getSwiftFiles(exampleFiles)


func getSwiftFiles2(files: [String]) -> [String] {
    return files.filter { file in file.hasSuffix(".swift") }
}

//: ## Reduce

func sum(xs: [Int]) -> Int {
    var result: Int = 0
    for x in xs {
        result += x
    }
    return result
}


sum([1, 2, 3, 4])


func product(xs: [Int]) -> Int {
    var result: Int = 1
    for x in xs {
        result = x * result
    }
    return result
}


func concatenate(xs: [String]) -> String {
    var result: String = ""
    for x in xs {
        result += x
    }
    return result
}


func prettyPrintArray(xs: [String]) -> String {
    var result: String = "Entries in the array xs:\n"
    for x in xs {
        result = "  " + result + x + "\n"
    }
    return result
}


func sumUsingReduce(xs: [Int]) -> Int {
    return xs.reduce(0) { result, x in result + x }
}


func productUsingReduce(xs: [Int]) -> Int {
    return xs.reduce(1, combine: *)
}

func concatUsingReduce(xs: [String]) -> String {
    return xs.reduce("", combine: +)
}


func flatten<T>(xss: [[T]]) -> [T] {
    var result: [T] = []
    for xs in xss {
        result += xs
    }
    return result
}


func flattenUsingReduce<T>(xss: [[T]]) -> [T] {
    return xss.reduce([]) { result, xs in result + xs }
}


extension Array {
    func mapUsingReduce<T>(transform: Element -> T) -> [T] {
        return reduce([]) { result, x in
            return result + [transform(x)]
        }
    }

    func filterUsingReduce(includeElement: Element -> Bool) -> [Element] {
        return reduce([]) { result, x in
            return includeElement(x) ? result + [x] : result
        }
    }
}

//: ## Putting It All Together

struct City {
    let name: String
    let population: Int
}


let paris = City(name: "Paris", population: 2241)
let madrid = City(name: "Madrid", population: 3165)
let amsterdam = City(name: "Amsterdam", population: 827)
let berlin = City(name: "Berlin", population: 3562)

let cities = [paris, madrid, amsterdam, berlin]


extension City {
    func cityByScalingPopulation() -> City {
        return City(name: name, population: population * 1000)
    }
}


let result___ =
cities.filter { $0.population > 1000 }
    .map { $0.cityByScalingPopulation() }
    .reduce("City: Population") { result, c in
        return result + "\n" + "\(c.name): \(c.population)"
    }

//: ## Generics vs. the `Any` Type

func noOp<T>(x: T) -> T {
    return x
}


func noOpAny(x: Any) -> Any {
    return x
}


func noOpAnyWrong(x: Any) -> Any {
    return 0
}


infix operator >>> { associativity left }
func >>> <A, B, C>(f: A -> B, g: B -> C) -> A -> C {
    return { x in g(f(x)) }
}


func curry<A, B, C>(f: (A, B) -> C) -> A -> B -> C {
    return { x in { y in f(x, y) } }
}

//: ## Notes
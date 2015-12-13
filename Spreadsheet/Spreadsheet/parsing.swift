import Foundation

func curry<A, B, C>(f: (A, B) -> C) -> A -> B -> C {
    return { x in { y in f(x, y) } }
}

func curry<A, B, C, D>(f: (A, B, C) -> D) -> A -> B -> C  -> D{
    return { x in { y in { z in f(x, y, z) } } }
}

func flip<A, B, C>(f: (B, A) -> C) -> (A, B) -> C {
    return { (x, y) in f(y, x) }
}

extension CollectionType
    where Generator.Element == SubSequence.Generator.Element
{
    var decompose: (head: Generator.Element, tail: [Generator.Element])? {
        guard let head = first else { return nil }
        return (head, Array(dropFirst()))
    }
}

func one<T>(x: T?) -> AnyGenerator<T> {
    return anyGenerator(GeneratorOfOne(x))
}

protocol Smaller {
    func smaller() -> AnyGenerator<Self>
}

extension Int: Smaller {
    func smaller() -> AnyGenerator<Int> {
        let result: Int? = self < 0 ? nil : self.predecessor()
        return one(result)
    }
}

func one<A>(x: A) -> AnySequence<A> {
    return AnySequence(GeneratorOfOne(x))
}


class CountdownGenerator: GeneratorType {
    var element: Int
    
    init<T>(array: [T]) {
        self.element = array.count - 1
    }
    
    func next() -> Int? {
        return self.element < 0 ? nil : element--
    }
}

let xs = ["A", "B", "C"]

class PowerGenerator: GeneratorType {
    var power: NSDecimalNumber = 1
    let two: NSDecimalNumber = 2
    
    func next() -> NSDecimalNumber? {
        power = power.decimalNumberByMultiplyingBy(two)
        return power
    }
}

extension PowerGenerator {
    func findPower(predicate: NSDecimalNumber -> Bool) -> NSDecimalNumber {
        while let x = next() {
            if predicate(x) {
                return x
            }
        }
        return 0
    }
}

class FileLinesGenerator: GeneratorType {
    typealias Element = String
    
    var lines: [String] = []
    
    init(filename: String) throws {
        let contents: String = try String(contentsOfFile: filename)
        let newLine = NSCharacterSet.newlineCharacterSet()
        lines = contents .componentsSeparatedByCharactersInSet(newLine)
    }
    
    func next() -> Element? {
        guard !lines.isEmpty else { return nil }
        let nextLine = lines.removeAtIndex(0)
        return nextLine
    }
}

extension GeneratorType {
    mutating func find(predicate: Element -> Bool) -> Element? {
        while let x = self.next() {
            if predicate(x) {
                return x
            }
        }
        return nil
    }
}

class LimitGenerator<G: GeneratorType>: GeneratorType {
    var limit = 0
    var generator: G
    
    init(limit: Int, generator: G) {
        self.limit = limit
        self.generator = generator
    }
    
    func next() -> G.Element? {
        guard limit >= 0 else { return nil }
        limit--
        return generator.next()
    }
}

extension Int {
    func countDown() -> AnyGenerator<Int> {
        var i = self
        return anyGenerator { i < 0 ? nil : i-- }
    }
}

func +<G: GeneratorType, H: GeneratorType where G.Element == H.Element>
    (var first: G, var second: H) -> AnyGenerator<G.Element>
{
    return anyGenerator { first.next() ?? second.next() }
}

struct ReverseSequence<T>: SequenceType {
    var array: [T]
    
    init(array: [T]) {
        self.array = array
    }
    
    func generate() -> CountdownGenerator {
        return CountdownGenerator(array: array)
    }
}

let reverseSequence = ReverseSequence(array: xs)
let reverseGenerator = reverseSequence.generate()

indirect enum BinarySearchTree<Element: Comparable> {
    case Leaf
    case Node(BinarySearchTree<Element>, Element, BinarySearchTree<Element>)
}

func context1() {
    // <<generatorOneExamples>>
    let three: [Int] = Array(GeneratorOfOne(3))
    let empty: [Int] = Array(GeneratorOfOne(nil))
    // <</generatorOneExamples>>
    (three, empty)
}

extension BinarySearchTree {
    var inOrder: AnyGenerator<Element> {
        switch self {
        case .Leaf:
            return anyGenerator { return nil }
        case .Node(let left, let x, let right):
            return left.inOrder + one(x) + right.inOrder
        }
    }
}

extension Array {
    func generateSmallerByOne() -> AnyGenerator<[Element]> {
        var i = 0
        return anyGenerator {
            guard i < self.count else { return nil }
            var result = self
            result.removeAtIndex(i)
            i++
            return result
        }
    }
}

extension Array {
    func smaller1() -> AnyGenerator<[Element]> {
        guard let (head, tail) = self.decompose else { return one(nil) }
        return one(tail) + Array<[Element]>(tail.smaller1()).map { smallerTail in
            [head] + smallerTail
            }.generate()
    }
}

extension GeneratorType {
    mutating func map<B>(transform: Element -> B) -> AnyGenerator<B> {
        return anyGenerator {
            self.next().map(transform)
        }
    }
}

func +<A>(l: AnySequence<A>, r: AnySequence<A>) -> AnySequence<A> {
    return AnySequence { l.generate() + r.generate() }
}

extension Array where Element: Smaller {
    func smaller() -> AnyGenerator<[Element]> {
        guard let (head, tail) = self.decompose else { return one(nil) }
        let gen1 = one(tail).generate()
        let gen2 = Array<[Element]>(tail.smaller()).map { xs in
            [head] + xs
            }.generate()
        let gen3 = Array<Element>(head.smaller()).map { x in
            [x] + tail
            }.generate()
        return gen1 + gen2 + gen3
    }
}

struct JoinedGenerator<Element>: GeneratorType {
    var generator: AnyGenerator<AnyGenerator<Element>>
    var current: AnyGenerator<Element>?
    
    init<G: GeneratorType where G.Element: GeneratorType,
        G.Element.Element == Element>(var _ g: G)
    {
        generator = g.map(anyGenerator)
        current = generator.next()
    }
    
    mutating func next() -> Element? {
        guard let c = current else { return nil }
        if let x = c.next() {
            return x
        } else {
            current = generator.next()
            return next()
        }
    }
}

extension SequenceType where Generator.Element: SequenceType {
    typealias NestedElement = Generator.Element.Generator.Element
    
    func join() -> AnySequence<NestedElement> {
        return AnySequence { () -> JoinedGenerator<NestedElement> in
            var generator = self.generate()
            return JoinedGenerator(generator.map { $0.generate() })
        }
    }
}

extension AnySequence {
    func flatMap<T, Seq: SequenceType where Seq.Generator.Element == T>
        (f: Element -> Seq) -> AnySequence<T>
    {
        return AnySequence<Seq>(self.map(f)).join()
    }
}

func context5() {
    // <<generateSmallerByOneExample>>
    [1, 2, 3].generateSmallerByOne()
    // <</generateSmallerByOneExample>>
}



/// ============================================================================
/// Code for the parser combinator chapter
/// ============================================================================

func none<T>() -> AnySequence<T> {
    return AnySequence(anyGenerator { nil } )
}

func fail<Token, Result>() -> Parser<Token, Result> {
    return Parser { _ in none() }
}

extension AnyGenerator {
    func map<B>(transform: Element -> B) -> AnyGenerator<B> {
        return anyGenerator {
            self.next().map(transform)
        }
    }
}

func prepend<A>(l: A)(r: [A]) -> [A] {
    return [l] + r
}

extension String {
    var slice: ArraySlice<Character> {
        return ArraySlice(self.characters)
    }
}

extension ArraySlice {
    var head: Element? {
        return isEmpty ? nil : self[0]
    }
    
    var tail: ArraySlice<Element> {
        guard !isEmpty else { return self }
        return self[(self.startIndex+1)..<self.endIndex]
    }
    
    var decompose: (head: Element, tail: ArraySlice<Element>)? {
        return isEmpty ? nil
            : (self[self.startIndex], self.tail)
    }
}

extension NSCharacterSet {
    func member(character: Character) -> Bool {
        let unichar = (String(character) as NSString).characterAtIndex(0)
        return characterIsMember(unichar)
    }
}

func eof<A>() -> Parser<A, ()> {
    return Parser { stream in
        if (stream.isEmpty) {
            return one(((), stream))
        }
        return none()
    }
}

func testParser<A>(parser: Parser<Character, A>, _ input: String) -> String {
    var result: [String] = []
    for (x, s) in parser.p(input.slice) {
        result += ["Success, found \(x), remainder: \(Array(s))"]
    }
    return result.isEmpty ? "Parsing failed." : result.joinWithSeparator("\n")
}

struct Parser<Token, Result> {
    let p: ArraySlice<Token> -> AnySequence<(Result, ArraySlice<Token>)>
}

func parseA() -> Parser<Character, Character> {
    let a: Character = "a"
    return Parser { x in
        guard let (head, tail) = x.decompose where head == a else {
            return none()
        }
        return one((a, tail))
    }
}

func parseCharacter(character: Character) -> Parser<Character, Character> {
    return Parser { x in
        guard let (head, tail) = x.decompose where head == character else {
            return none()
        }
        return one((character, tail))
    }
}

func satisfy<Token>(condition: Token -> Bool) -> Parser<Token, Token> {
    return Parser { x in
        guard let (head, tail) = x.decompose where condition(head) else {
            return none()
        }
        return one((head, tail))
    }
}

func token<Token: Equatable>(t: Token) -> Parser<Token, Token> {
    return satisfy { $0 == t }
}

infix operator <|> { associativity right precedence 130 }
func <|> <Token, A>(l: Parser<Token, A>, r: Parser<Token, A>)
    -> Parser<Token, A>
{
    return Parser { l.p($0) + r.p($0) }
}

let a: Character = "a"
let b: Character = "b"

func sequence<Token, A, B>(l: Parser<Token, A>, _ r: Parser<Token, B>)
    -> Parser<Token, (A, B)>
{
    return Parser { input in
        let leftResults = l.p(input)
        return leftResults.flatMap {
            (a, leftRest) -> [((A, B), ArraySlice<Token>)] in
            let rightResults = r.p(leftRest)
            return rightResults.map { b, rightRest in
                ((a, b), rightRest)
            }
        }
    }
}

let x: Character = "x"
let y: Character = "y"

let z: Character = "z"

func integerParser<Token>() -> Parser<Token, Character -> Int> {
    return Parser { input in
        return one(({ x in Int(String(x))! }, input))
    }
}

func combinator<Token, A, B>(l: Parser<Token, A -> B>, _ r: Parser<Token, A>)
    -> Parser<Token, B>
{
    typealias Result = (B, ArraySlice<Token>)
    typealias Results = [Result]
    return Parser { input in
        let leftResults = l.p(input)
        return leftResults.flatMap { f, leftRemainder -> Results in
            let rightResults = r.p(leftRemainder)
            return rightResults.map { x, rightRemainder -> Result in
                (f(x), rightRemainder)
            }
        }
    }
}

let three: Character = "3"

func pure<Token, A>(value: A) -> Parser<Token, A> {
    return Parser { one((value, $0)) }
}

func toInteger2(c1: Character)(c2: Character) -> Int {
    let combined = String(c1) + String(c2)
    return Int(combined)!
}

infix operator <*> { associativity left precedence 150 }
func <*><Token, A, B>(l: Parser<Token, A -> B>, r: Parser<Token, A>)
    -> Parser<Token, B>
{
    typealias Result = (B, ArraySlice<Token>)
    typealias Results = [Result]
    return Parser { input in
        let leftResults = l.p(input)
        return leftResults.flatMap { (f, leftRemainder) -> Results in
            let rightResults = r.p(leftRemainder)
            return rightResults.map { (x, y) -> Result in (f(x), y) }
        }
    }
}

let aOrB = token(a) <|> token(b)

func characterFromSet(set: NSCharacterSet) -> Parser<Character, Character> {
    return satisfy(set.member)
}

let decimals = NSCharacterSet.decimalDigitCharacterSet()
let decimalDigit = characterFromSet(decimals)

func lazy<Token, A>(f: () -> Parser<Token, A>) -> Parser<Token, A> {
    return Parser { f().p($0) }
}

func zeroOrMore<Token, A>(p: Parser<Token, A>) -> Parser<Token, [A]> {
    return (pure(prepend) <*> p <*> lazy { zeroOrMore(p) } ) <|> pure([])
}

func oneOrMore<Token, A>(p: Parser<Token, A>) -> Parser<Token, [A]> {
    return pure(prepend) <*> p <*> zeroOrMore(p)
}

let number = pure { Int(String($0))! } <*> oneOrMore(decimalDigit)

infix operator </> { precedence 170 }
func </> <Token, A, B>(l: A -> B, r: Parser<Token, A>) -> Parser<Token, B> {
    return pure(l) <*> r
}

let plus: Character = "+"
func add(x: Int)(_: Character)(y: Int) -> Int {
    return x + y
}
let parseAddition = add </> number <*> token(plus) <*> number

infix operator <*  { associativity left precedence 150 }
func <* <Token, A, B>(p: Parser<Token, A>, q: Parser<Token, B>)
    -> Parser<Token, A>
{
    return { x in { _ in x } } </> p <*> q
}

infix operator  *> { associativity left precedence 150 }
func *> <Token, A, B>(p: Parser<Token, A>, q: Parser<Token, B>)
    -> Parser<Token, B>
{
    return { _ in { y in y } } </> p <*> q
}

typealias Calculator = Parser<Character, Int>

func operator1(character: Character, _ evaluate: (Int, Int) -> Int,
    _ operand: Calculator) -> Calculator
{
    let withOperator = curry { evaluate($0, $1) } </> operand
        <* token(character) <*> operand
    return withOperator <|> operand
}

typealias Op = (Character, (Int, Int) -> Int)
let operatorTable: [Op] = [("*", *), ("/", /), ("+", +), ("-", -)]

infix operator </  { precedence 170 }
func </ <Token, A, B>(l: A, r: Parser<Token, B>) -> Parser<Token, A> {
    return pure(l) <* r
}

func optionallyFollowed<A>(l: Parser<Character, A>,
    _ r: Parser<Character, A -> A>) -> Parser<Character, A>
{
    let apply: A -> (A -> A) -> A = { x in { f in f(x) } }
    return apply </> l <*> (r <|> pure { $0 })
}

func op(character: Character, _ evaluate: (Int, Int) -> Int,
    _ operand: Calculator) -> Calculator
{
    let withOperator = curry(flip(evaluate)) </ token(character) <*> operand
    return optionallyFollowed(operand, withOperator)
}

func parse<A>(parser: Parser<Character, A>, _ input: String) -> A? {
    for (result, _) in (parser <* eof()).p(input.slice) {
        return result
    }
    return nil
}

func parse<A, B>(parser: Parser<A, B>, _ input: [A]) -> B? {
    for (result, _) in (parser <* eof()).p(input[0..<input.count]) {
        return result
    }
    return nil
}

enum Token: Equatable {
    case Number(Int)
    case Operator(String)
    case Reference(String, Int)
    case Punctuation(String)
    case FunctionName(String)
}

func op(opString: String) -> Parser<Token, String> {
    return const(opString) </> token(Token.Operator(opString))
}

func ==(lhs: Token, rhs: Token) -> Bool {
    switch (lhs, rhs) {
    case (.Number(let x), .Number(let y)):
        return x == y
    case (.Operator(let x), .Operator(let y)):
        return x == y
    case (.Reference(let row, let column),
        .Reference(let row1, let column1)):
        return row == row1 && column == column1
    case (.Punctuation(let x), .Punctuation(let y)):
        return x == y
    case (.FunctionName (let x), .FunctionName(let y)):
        return x == y
    default:
        return false
    }
}

func const<A, B>(x: A) -> (y: B) -> A {
    return { _ in x }
}

func tokens<A: Equatable>(input: [A]) -> Parser<A, [A]> {
    guard let (head, tail) = input.decompose else { return pure([]) }
    return prepend </> token(head) <*> tokens(tail)
}

func string(string: String) -> Parser<Character, String> {
    return const(string) </> tokens(Array(string.characters))
}

func oneOf<Token, A>(parsers: [Parser<Token, A>]) -> Parser<Token, A> {
    return parsers.reduce(fail(), combine: <|>)
}

let pDigit = oneOf(Array(0...9).map { const($0) </> string("\($0)") })

func toNaturalNumber(digits: [Int]) -> Int {
    return digits.reduce(0) { $0 * 10 + $1 }
}

let naturalNumber = toNaturalNumber </> oneOrMore(pDigit)

let tNumber = { Token.Number($0) } </> naturalNumber

let operatorParsers = ["*", "/", "+", "-", ":"].map { string($0) }
let tOperator = { Token.Operator($0) } </> oneOf (operatorParsers)

let capitalSet = NSCharacterSet.uppercaseLetterCharacterSet()
let capital = characterFromSet(capitalSet)

let tReference = curry { Token.Reference(String($0), $1) }
    </> capital <*> naturalNumber

let punctuationParsers = ["(", ")"].map { string($0) }
let tPunctuation = { Token.Punctuation($0) } </> oneOf(punctuationParsers)

let tName = { Token.FunctionName(String($0)) } </> oneOrMore(capital)

let whitespaceSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()
let whitespace = characterFromSet(whitespaceSet)

func ignoreLeadingWhitespace<A>(p: Parser<Character, A>)
    -> Parser<Character, A>
{
    return zeroOrMore(whitespace) *> p
}

func tokenize() -> Parser<Character, [Token]> {
    let tokenParsers = [tNumber, tOperator, tReference, tPunctuation, tName]
    return zeroOrMore(ignoreLeadingWhitespace(oneOf(tokenParsers)))
}

indirect enum Expression {
    case Number(Int)
    case Reference(String, Int)
    case BinaryExpression(String, Expression, Expression)
    case FunctionCall(String, Expression)
}

typealias ExpressionParser = Parser<Token, Expression>

//var expression: () -> ExpressionParser = { fail() }

func optionalTransform<A, T>(f: T -> A?) -> Parser<T, A> {
    return { f($0)! } </> satisfy { f($0) != nil }
}

let pNumber: ExpressionParser = optionalTransform {
    guard case let .Number(number) = $0 else { return nil }
    return Expression.Number(number)
}

let pReference: ExpressionParser = optionalTransform {
    guard case let .Reference(column, row) = $0 else { return nil }
    return Expression.Reference(column, row)
}

let pNumberOrReference = pNumber <|> pReference

let pFunctionName: Parser<Token, String> = optionalTransform {
    guard case let .FunctionName(name) = $0 else { return nil }
    return name
}

func makeList(l: Expression, _ r: Expression) -> Expression {
    return Expression.BinaryExpression(":", l, r)
}

let pList: ExpressionParser = curry(makeList)
    </> pReference <* op(":") <*> pReference

func parenthesized<A>(p: Parser<Token, A>) -> Parser<Token, A> {
    return token(Token.Punctuation("(")) *> p <* token(Token.Punctuation(")"))
}

func makeFunctionCall(name: String, _ arg: Expression) -> Expression {
    return Expression.FunctionCall(name, arg)
}

let pFunctionCall = curry(makeFunctionCall)
    </> pFunctionName <*> parenthesized(pList)

let pParenthesizedExpression = parenthesized(lazy { expression() })
let pPrimitive = pNumberOrReference <|> pFunctionCall
    <|> pParenthesizedExpression

let pMultiplier = curry { ($0, $1) } </> (op("*") <|> op("/")) <*> pPrimitive

func combineOperands(first: Expression, _ rest: [(String, Expression)])
    -> Expression
{
    return rest.reduce(first) { result, pair in
        let (op, exp) = pair
        return Expression.BinaryExpression(op, result, exp)
    }
}


let pProduct = curry(combineOperands) </> pPrimitive <*> zeroOrMore(pMultiplier)

let pSummand = curry { ($0, $1) } </> (op("-") <|> op("+")) <*> pProduct
let pSum = curry(combineOperands) </> pProduct <*> zeroOrMore(pSummand)

func parseExpression(input: String) -> Expression? {
    return parse(tokenize(), input).flatMap { parse(expression(), $0) }
}

enum Result {
    case IntResult(Int)
    case StringResult(String)
    case ListResult([Result])
    case EvaluationError(String)
}

typealias IntegerOperator = (Int, Int) -> Int

func lift(f: IntegerOperator) -> ((Result, Result) -> Result) {
    return { l, r in
        guard case let (.IntResult(x), .IntResult(y)) = (l, r) else {
            return .EvaluationError("Couldn't evaluate \(l, r)")
        }
        return .IntResult(f(x, y))
    }
}

func op(f: IntegerOperator) -> IntegerOperator {
    return f
}

let integerOperators: [String: IntegerOperator] = [
    "+": op(+),
    "/": op(/),
    "*": op(*),
    "-": op(-)
]

func evaluateIntegerOperator(op: String, _ l: Expression, _ r: Expression,
    _ evaluate: Expression? -> Result) -> Result?
{
    return integerOperators[op].map {
        lift($0)(evaluate(l), evaluate(r))
    }
}

func evaluateListOperator(op: String, _ l: Expression, _ r: Expression,
    _ evaluate: Expression? -> Result) -> Result?
{
    switch (op, l, r) {
    case (":", .Reference("A", let row1), .Reference("A", let row2))
        where row1 <= row2:
        return Result.ListResult(Array(row1...row2).map {
            evaluate(Expression.Reference("A", $0))
            })
    default:
        return nil
    }
}

func evaluateBinary(op: String, _ l: Expression, _ r: Expression,
    _ evaluate: Expression? -> Result) -> Result
{
    return evaluateIntegerOperator(op, l, r, evaluate)
        ?? evaluateListOperator(op, l, r, evaluate)
        ?? .EvaluationError("Couldn't find operator \(op)")
}

func evaluateFunction(functionName: String, _ parameter: Result) -> Result {
    switch (functionName, parameter) {
    case ("SUM", .ListResult(let list)):
        return list.reduce(Result.IntResult(0), combine: lift(+))
    case ("MIN", .ListResult(let list)):
        return list.reduce(Result.IntResult(Int.max),
            combine: lift { min($0, $1) })
    default:
        return .EvaluationError("Couldn't evaluate function")
    }
}

func evaluateExpression(context: [Expression?]) -> Expression? -> Result {
    return { (e: Expression?) in
        e.map { expression in
            let recurse = evaluateExpression(context)
            switch (expression) {
            case let .Number(x):
                return Result.IntResult(x)
            case let .Reference("A", idx):
                return recurse(context[idx])
            case let .BinaryExpression(s, l, r):
                return evaluateBinary(s, l, r, recurse)
            case let .FunctionCall(f, p):
                return evaluateFunction(f, recurse(p))
            default:
                return .EvaluationError("Couldn't evaluate expression")
            }
            } ?? .EvaluationError("Couldn't parse expression")
    }
}

func evaluateExpressions(expressions: [Expression?]) -> [Result] {
    return expressions.map(evaluateExpression(expressions))
}

//expression = { pSum }


func expression() -> ExpressionParser {
    return pSum
}

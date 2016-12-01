indirect enum Expression {
    case int(Int)
    case reference(String, Int)
    case infix(Expression, String, Expression)
    case function(String, Expression)
}


func combineOperands(first: Expression, _ rest: [(String, Expression)]) -> Expression {
    return rest.reduce(first) { result, pair in
        return Expression.infix(result, pair.0, pair.1)
    }
}

extension Expression {
    static var intParser: Parser<Expression> {
        return { .int($0) } <^> integer
    }
    
    static var referenceParser: Parser<Expression> {
        return curry({ .reference(String($0), $1) }) <^> capitalLetter <*> integer
    }
    
    static var functionParser: Parser<Expression> {
        let name = { String($0) } <^> capitalLetter.many1
        let argument = curry({ Expression.infix($0, String($1), $2) }) <^> referenceParser <*> string(":") <*> referenceParser
        return curry({ .function($0, $1) }) <^> name <*> argument.parenthesized
    }
    
    static var primitiveParser: Parser<Expression> {
        return intParser <|> referenceParser <|> functionParser <|> lazy(parser).parenthesized
    }
    
    static var productParser: Parser<Expression> {
        let multiplier = curry({ ($0, $1) }) <^> (string("*") <|> string("/")) <*> primitiveParser
        return curry(combineOperands) <^> primitiveParser <*> multiplier.many
    }
    
    static var sumParser: Parser<Expression> {
        let summand = curry({ ($0, $1) }) <^> (string("+") <|> string("-")) <*> productParser
        return curry(combineOperands) <^> productParser <*> summand.many
    }
    
    static var parser = sumParser
}



enum Result {
    case int(Int)
    case list([Result])
    case error(String)
}


extension Expression {
    func evaluate(context: [Expression?]) -> Result {
        switch (self) {
        case let .int(x):
            return .int(x)
        case let .reference("A", row):
            return context[row]?.evaluate(context: context)
                ?? .error("Invalid reference \(self)")
        case .function:
            return self.evaluateFunction(context: context)
                ?? .error("Invalid function call \(self)")
        case let .infix(l, op, r):
            return self.evaluateArithmetic(context: context)
                ?? self.evaluateList(context: context)
                ?? .error("Invalid operator \(op) for operands \(l, r)")
        default:
            return .error("Couldn't evaluate expression \(self)")
        }
    }
}

extension Expression {
    func evaluateArithmetic(context: [Expression?]) -> Result? {
        guard case let .infix(l, op, r) = self else { return nil }
        let x = l.evaluate(context: context)
        let y = r.evaluate(context: context)
        switch (op) {
        case "+": return lift(+)(x, y)
        case "-": return lift(-)(x, y)
        case "*": return lift(*)(x, y)
        case "/": return lift(/)(x, y)
        default: return nil
        }
    }
    
    func evaluateList(context: [Expression?]) -> Result? {
        guard
            case let .infix(l, op, r) = self,
            op == ":",
            case let .reference("A", row1) = l,
            case let .reference("A", row2) = r
            else { return nil }
        return .list((row1...row2).map { Expression.reference("A", $0).evaluate(context: context) })
    }
    
    func evaluateFunction(context: [Expression?]) -> Result? {
        guard
            case let .function(name, parameter) = self,
            case let .list(list) = parameter.evaluate(context: context)
            else { return nil }
        switch name {
        case "SUM":
            return list.reduce(.int(0), lift(+))
        case "MIN":
            return list.reduce(.int(Int.max), lift { min($0, $1) })
        default:
            return .error("Unknown function \(name)")
        }
    }
}

func lift(_ op: @escaping (Int, Int) -> Int) -> ((Result, Result) -> Result) {
    return { lhs, rhs in
        guard case let (.int(x), .int(y)) = (lhs, rhs) else {
            return .error("Invalid operands \(lhs, rhs) for integer operator")
        }
        return .int(op(x, y))
    }
}


func evaluate(expressions: [Expression?]) -> [Result] {
    return expressions.map { $0?.evaluate(context: expressions) ?? .error("Invalid expression \($0)") }
}





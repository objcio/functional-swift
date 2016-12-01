import Foundation


struct Parser<A> {
    typealias Stream = String.CharacterView
    let parse: (Stream) -> (A, Stream)?
}

extension Parser {
    func run(_ string: String) -> (A, String)? {
        guard let (result, remainder) = parse(string.characters) else { return nil }
        return (result, String(remainder))
    }
    
    var many: Parser<[A]> {
        return Parser<[A]> { input in
            var result: [A] = []
            var remainder = input
            while let (element, newRemainder) = self.parse(remainder) {
                result.append(element)
                remainder = newRemainder
            }
            return (result, remainder)
        }
    }
    
    func map<T>(_ transform: @escaping (A) -> T) -> Parser<T> {
        return Parser<T> { input in
            guard let (result, remainder) = self.parse(input) else { return nil }
            return (transform(result), remainder)
        }
    }
    
    func followed<B>(by other: Parser<B>) -> Parser<(A, B)> {
        return Parser<(A, B)> { input in
            guard let (result1, remainder1) = self.parse(input) else { return nil }
            guard let (result2, remainder2) = other.parse(remainder1) else { return nil }
            return ((result1, result2), remainder2)
        }
    }
    
    func or(_ other: Parser<A>) -> Parser<A> {
        return Parser<A> { input in
            return self.parse(input) ?? other.parse(input)
        }
    }
    
    var many1: Parser<[A]> {
        return curry({ [$0] + $1 }) <^> self <*> self.many
    }
    
    var optional: Parser<A?> {
        return Parser<A?> { input in
            guard let (result, remainder) = self.parse(input) else { return (nil, input) }
            return (result, remainder)
        }
    }
    
    var parenthesized: Parser<A> {
        return string("(") *> self <* string(")")
    }
}



precedencegroup SequencePrecedence {
    associativity: left
    higherThan: AdditionPrecedence
}

infix operator <^>: SequencePrecedence
func <^><A, B>(lhs: @escaping (A) -> B, rhs: Parser<A>) -> Parser<B> {
    return rhs.map(lhs)
}

infix operator <*>: SequencePrecedence
func <*><A, B>(lhs: Parser<(A) -> B>, rhs: Parser<A>) -> Parser<B> {
    return lhs.followed(by: rhs).map { f, x in f(x) }
}

infix operator *>: SequencePrecedence
func *><A, B>(lhs: Parser<A>, rhs: Parser<B>) -> Parser<B> {
    return curry({ $1 }) <^> lhs <*> rhs
}

infix operator <*: SequencePrecedence
func <*<A, B>(lhs: Parser<A>, rhs: Parser<B>) -> Parser<A> {
    return curry({ x, _ in x }) <^> lhs <*> rhs
}

infix operator <|>: SequencePrecedence
func <|><A>(lhs: Parser<A>, rhs: Parser<A>) -> Parser<A> {
    return lhs.or(rhs)
}



func character(condition: @escaping (Character) -> Bool) -> Parser<Character> {
    return Parser { input in
        guard let char = input.first, condition(char) else { return nil }
        return (char, input.dropFirst())
    }
}

func string(_ string: String) -> Parser<String> {
    return Parser<String> { input in
        var remainder = input
        for c in string.characters {
            let parser = character { $0 == c }
            guard let (_, newRemainder) = parser.parse(remainder) else { return nil }
            remainder = newRemainder
        }
        return (string, remainder)
    }
}

func lazy<A>(_ parser: @autoclosure @escaping () -> Parser<A>) -> Parser<A> {
    return Parser<A> { parser().parse($0) }
}


let digit = character { CharacterSet.decimalDigits.contains($0) }
let integer = digit.many1.map { Int(String($0))! }
let capitalLetter = character { CharacterSet.uppercaseLetters.contains($0) }




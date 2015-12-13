//: # The Value of Immutability
//: ## Variables and References

var x: Int = 1
let y: Int = 2

//: ## Value Types vs. Reference Types

struct PointStruct {
    var x: Int
    var y: Int
}


var structPoint = PointStruct(x: 1, y: 2)
var sameStructPoint = structPoint
sameStructPoint.x = 3


class PointClass {
    var x: Int
    var y: Int

    init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}


var classPoint = PointClass(x: 1, y: 2)
var sameClassPoint = classPoint
sameClassPoint.x = 3


func setStructToOrigin(var point: PointStruct) -> PointStruct {
    point.x = 0
    point.y = 0
    return point
}


var structOrigin: PointStruct = setStructToOrigin(structPoint)


func setClassToOrigin(point: PointClass) -> PointClass {
    point.x = 0
    point.y = 0
    return point
}


var classOrigin = setClassToOrigin(classPoint)

//: ### Structs and Classes: Mutable or Not?

let immutablePoint = PointStruct(x: 0, y: 0)


var mutablePoint = PointStruct(x: 1, y: 1)
mutablePoint.x = 3;


struct ImmutablePointStruct {
    let x: Int
    let y: Int
}

var immutablePoint2 = ImmutablePointStruct(x: 1, y: 1)


immutablePoint2 = ImmutablePointStruct(x: 2, y: 2)

//: ### Objective-C
//: ## Discussion

func sum(xs: [Int]) -> Int {
    var result = 0
    for x in xs {
        result += x
    }
    return result
}


func qsort(var array: [Int]) -> [Int] {
    if array.isEmpty { return [] }
    let pivot = array.removeAtIndex(0)
    let lesser = array.filter { $0 < pivot }
    let greater = array.filter { $0 >= pivot }
    return qsort(lesser) + [pivot] + qsort(greater)
}

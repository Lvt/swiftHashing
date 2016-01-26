/*

The core of the OS X hashing function is

result(-1) := 0
result(n)  := result(n-1) * 257 + c(n)

(It is actually a bit more complicated, but this simplification is sufficiant
for collision on strings of the same length)

This can be rewritten as
result(n) := result(n-1) * 256 + result(n-1) + c(n)

Note that 256 aligns well with byte boundaries.

Resolving the recursion reveals a nice formular for various strings

s() -> 0
s(c0) -> c0
s(c0,c1) -> c0 * 256 + c0 + c1
s(c0,c1,c2) -> c0 * (256^2) + 2 * c0 * 256 + c0 + c1 * 256 + c1
[...]

The factors for each element are actually binomial coefficients.

    1
   1 1
  1 2 1
 1 3 3 1
1 4 6 4 1 

Rewriting this as a more traditional matrix:

1 1 1 1 1     c0     (result byte4)
4 3 2 1 0     c1     (result byte3)
6 3 1 0 0  x  c2  =  (result byte2)
4 1 0 0 0     c3     (result byte1)
1 0 0 0 0     c4     (result byte0)

This matrix is limited to 8 rows due to the output size. Meaning it will be heavily
underconstraint for inputs of >8 chars.

We thus construct the 12x8 matrix as our workhorse

  1   1   1   1   1   1   1   1   1   1   1   1      % 256*256*256*256*256*256*256*256
 11  10   9   8   7   6   5   4   3   2   1   0      % 256*256*256*256*256*256*256
 55  45  36  28  21  15  10   6   3   1   0   0      % 256*256*256*256*256*256
165 120  84  56  35  20  10   4   1   0   0   0      % 256*256*256*256*256
330 210 126  70  35  15   5   1   0   0   0   0      % 256*256*256*256
462 252 126  56  21   6   1   0   0   0   0   0      % 256*256*256
462 210  84  28   7   1   0   0   0   0   0   0      % 256*256
330 120  36   8   1   0   0   0   0   0   0   0      % 256

The mod groups are a result of the byte shifting. The highest byte is
<result byte 0> * (256)^7 % 256^8 meaning it is equivilent to
<result byte 0> % 256. This extra condition should be irrelevant for all
but the highest bytes.

If two vectors v1 and v2 have the same result r then both will produce the same
hash. We simply start with a random text generating a random hash and search
for collisions by picking all combinations of input that can produce the same
hash. Note that there might be more hashes than found by this algorithm.

*/

#if os(Linux)
    import Glibc
    import SwiftShims
#else
    import Darwin
#endif

extension String {

  subscript (i: Int) -> Character {
    return self[self.startIndex.advancedBy(i)]
  }

}

func cs_arc4random_uniform(upperBound: UInt32) -> UInt32 {  
    #if os(Linux)
        return _swift_stdlib_arc4random_uniform(upperBound)
    #else
        return arc4random_uniform(upperBound)
    #endif
}

func <=(lhs: [UInt64], rhs: [UInt64]) -> Bool {
  for i in 0..<min(lhs.count,rhs.count) {
    if (lhs[i] > rhs[i]) { return false }
  }
  return lhs.count <= rhs.count
}

let alphabet = "!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
let matrix = [
  [1,1,1,1,1,1,1,1,1,1,1,1],
  [11,10,9,8,7,6,5,4,3,2,1,0],
  [55,45,36,28,21,15,10,6,3,1,0,0],
  [165,120,84,56,35,20,10,4,1,0,0,0],
  [330,210,126,70,35,15,5,1,0,0,0,0],
  [462,252,126,56,21,6,1,0,0,0,0,0],
  [462,210,84,28,7,1,0,0,0,0,0,0],
  [330,120,36,8,1,0,0,0,0,0,0,0]
]

func mmr(row : Int, values : [UInt64]) -> UInt64 {
  var result = UInt64(0)
  for col in 0..<(min(values.count,matrix[row].count)) {
    result = result + UInt64(matrix[row][col]) * values[col]
  }
  return result
}

func mm(values : [UInt64]) -> [UInt64] {
  var result = [UInt64](count: matrix.count, repeatedValue: 0)
  for i in 0..<matrix.count {
    result[i] = mmr(i, values: values)
  }
  return result
}

var referenceInput = ""
for i in 0..<12 {
  referenceInput = referenceInput + String(alphabet[Int(cs_arc4random_uniform(UInt32(alphabet.characters.count)))])
}
print("Trying to collide: " + referenceInput)
let referenceVector = referenceInput.unicodeScalars.map({ UInt64($0.value) })
let result = mm(referenceVector)

print(result)

var best = ""

func search(prefix : String) {
  if (prefix.characters.count > best.characters.count) {
    best = prefix
    print(prefix)
  }
  for c in alphabet.characters {
    let s = prefix + String(c)
    let v = s.unicodeScalars.map({ UInt64($0.value) })
    let m = mm(v)
    if (m <= result) {
      switch (s.characters.count) {
        case 12: if (m[0] == result[0]) { print("-> " + s) }
        case 11: if (m[1] == result[1]) { search(s) }
        case 10: if (m[2] == result[2]) { search(s) }
        case  9: if (m[3] == result[3]) { search(s) }
        case  8: if (m[4] == result[4]) { search(s) }
        case  7: if (m[5] == result[5]) { search(s) }
        case  6: if (m[6] == result[6]) { search(s) }
        case  5: if (m[7] == result[7]) { search(s) }
        default: search(s)
      }
    }
  }
}

search("")

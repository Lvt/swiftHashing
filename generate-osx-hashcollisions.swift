/*

The core of the OS X hashing function is

result(-1) := 0
result(n)  := result(n-1) * 257 + c(n)

(
 They are adding the string length and some other irrelevant things to the
 hash but a collision of two equally long strings under this method will
 be a collision under the ObjC method found at
 https://opensource.apple.com/source/CF/CF-1153.18/CFString.c
)

Note that the method is additive.
hash("ab") = hash("a\0") + hash("\0b")

Also note that the last 6 chars can not produce an overflow.

We can thus compute a map of hash -> suffix pairs.
The algorithm works with 3 char strings at a time, filling a 12 char string.

The last 3 chars must have a hash value that fills the gap towards the result hash.
Chars 0..(n-6) must form a hash that is within the bounds of [resultHash-maxHash6,resultHash-minHash6].
Chars 0..(n-3) must form a hash that is within the bounds of [resultHash-maxHash3,resultHash-minHash3].

Constructing a 12 char strings works like this
- pick a tripple
- pick another tripple
-> compute the prefix hash := hash1 * 257^9 + hash2 * 257^6
-> check if the prefix hash is in [resultHash-maxHash6,resultHash-minHash6]
- pick another tripple
- compute the hash := hash1 * 257^9 + hash2 * 257^6 + hash3 * 257^3
-> check if the hash is in [resultHash-maxHash3,resultHash-minHash3]
- compute the delta resultHash - hash
- find a suffix by delta
-> if there is a suffix by delte output the concat of all 4 tripples

Easy, right?
Runtime is not so awesome, but it will dump many collisions and should finish
within days if you'd like to exhaust one run.
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
  func objcHash () -> UInt64 {
    var result = UInt64(0)
    for c in unicodeScalars {
      result = result &* UInt64(257) &+ UInt64(c.value & 0xff)
    }
    return result
  }
}

func cs_arc4random_uniform(upperBound: UInt32) -> UInt32 {  
    #if os(Linux)
        return _swift_stdlib_arc4random_uniform(upperBound)
    #else
        return arc4random_uniform(upperBound)
    #endif
}

func hash(data : [UInt8]) -> UInt64 {
  var result = UInt64(0)
  for c in data {
    result = result &* UInt64(257) &+ UInt64(c)
  }
  return result
}

let len = 12
let suffixLen = 3
let alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
// let alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
// let alphabet = "0123456789"
let refAlphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

print("Build suffix map")
var suffixMap = [UInt64: String]()
var maxHash = UInt64(0)
var minHash = UInt64(0xffffffffffffff)
func buildSuffixMap(prefix : String) {
  let l = prefix.unicodeScalars.count + 1
  for c in alphabet.unicodeScalars {
    let s = prefix + String(c)
    if (l == suffixLen) {
      let h = s.objcHash()
      maxHash = max(maxHash, h)
      minHash = min(minHash, h)
      suffixMap[h] = s
    } else {
      if (l <= suffixLen - 2) { print(s, terminator: " ") }
      buildSuffixMap(s)
    }
  }
}
buildSuffixMap("")
print("")
let qmaxHash = maxHash * UInt64(257 * 257 * 257) + maxHash
let qminHash = minHash * UInt64(257 * 257 * 257) + minHash
print(String(suffixMap.count) + " " + String(minHash) + ".." + String(maxHash) + " " + String(qminHash) + ".." + String(qmaxHash))

var referenceInput = ""
for i in 0..<len {
  referenceInput = referenceInput + String(refAlphabet[Int(cs_arc4random_uniform(UInt32(refAlphabet.characters.count)))])
}
var rh = referenceInput.objcHash()
while (rh < qmaxHash) {
  referenceInput = ""
  for i in 0..<len {
    referenceInput = referenceInput + String(refAlphabet[Int(cs_arc4random_uniform(UInt32(refAlphabet.characters.count)))])
  }
  rh = referenceInput.objcHash()
}

let p1lo = rh - qmaxHash
let p1hi = rh - qminHash
let p2lo = rh - maxHash
let p2hi = rh - minHash
print("P1 in [" + String(p1lo) + "," + String(p1hi)  + "]")
print("P2 in [" + String(p2lo) + "," + String(p2hi)  + "]")
print("")
print("Collide: " + referenceInput + " -> " + String(rh))
print("")

let f2 = UInt64(257 * 257 * 257)
let f1 = UInt64(257 * 257 * 257) &* UInt64(257 * 257 * 257)
let f0 = UInt64(257 * 257 * 257) &* UInt64(257 * 257 * 257) &* UInt64(257 * 257 * 257)

var t = 0
for (k0,v0) in suffixMap {
  t = t + 1
  if (t % 1000 == 0) {
    let p = Double(t * 100000 / suffixMap.count) / 100000.0 * 100.0
    print(String(t) + "/" + String(suffixMap.count) + " :: " + String(p) + "%")
  }

  let h0 = k0 &* f0
  for (k1,v1) in suffixMap {
    let h1 = h0 &+ k1 &* f1
    if (h1 > p1hi || h1 < p1lo) { continue }
    for (k2,v2) in suffixMap {
      let h2 = h1 &+ k2 &* f2
      if (h2 > p2hi || h2 < p2lo) { continue }
      let missing = rh &- h2
      if let v3 = suffixMap[missing] {
        let s = v0 + v1 + v2 + v3
        print(s + " -> " + String(s.objcHash()))
      }
    }
  }
}


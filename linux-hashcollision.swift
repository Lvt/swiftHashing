/*
Linux uses the 'new' swift hash implementation. This has problems with \0 bytes.
*/

var d = [String : Int]()
var s = "a"

for i in 1..<10000 {
 s = s + "b"
 d[s] = 1
}

print(d.count)

d = [String : Int]()
s = "a"
for i in 1..<10000 {
 s = s + "\0"
 d[s] = 1
}

print(d.count)

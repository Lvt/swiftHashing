/*
This shows slowing down because of hash collisions
*/

let a = "0123456789abcdef"
let a32 = a+a


let iterations = 1000
var fast = [String : Int]()

print("Start fast iteration")
for i in (iterations..<(iterations * 10)) {
        fast[String(i) + a32 + a32 + String(i) + a32] = i
}
print("Finished Fast Iteration")

var slow = [String : Int]()
 
print("Start slow iteration")
for i in (iterations..<(iterations * 10)) {
         fast[a32 + String(i) + a32 + String(i) + a32] = i
 }     
print("Finished slow iteration")  

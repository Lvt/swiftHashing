/*
This generates crashing and wrong binary code on:

Apple Swift version 2.1.1 (swiftlang-700.1.101.15 clang-700.1.81)
Target: x86_64-apple-darwin15.2.0


*/

print("a".hashValue + "a\0".hashValue)

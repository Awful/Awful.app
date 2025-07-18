import Foundation
let url = URL(string: "https://x.com/RobertSkvarla/status/1945553417671172188?t=ftiCsXG2MDJoh4bZ1pZl8w&s=19")\!
print("pathComponents:", url.pathComponents)
print("count:", url.pathComponents.count)
for (i, component) in url.pathComponents.enumerated() {
    print("[\(i)]: \(component)")
}
let id = url.pathComponents[3]
print("id:", id)
print("all digits:", id.unicodeScalars.allSatisfy(CharacterSet.decimalDigits.contains))

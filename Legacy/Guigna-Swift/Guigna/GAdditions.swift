import Foundation
import WebKit

protocol GAppDelegate {
    var defaults: NSUserDefaultsController! { get set }
    func log(text: String)
    // var allPackages: [GPackage] { get set } // to avoid in Swift since it returns a copy
    func addItem(item: GItem) // to add an inactive package without requiring a copy of allPackages
    func removeItem(item: GItem) // TODO
    func removeItems(excludeElement: GItem -> Bool) // to remove inactive packages from allPackages in Swift
    var shellColumns: Int { get }
}

extension Array {
    
    func join(_ separator: String = " ") -> String {
        // return separator.join(self) // doesn't compile anymore with B6
        return self._bridgeToObjectiveC().componentsJoinedByString(separator)

    }
    
}


extension String {
    
    var length: Int {
        get {
            return countElements(self)
        }
    }
    
    func index(string: String) -> Int {
        if let range = self.rangeOfString(string) {
            return distance(startIndex, range.startIndex)
        } else {
            return NSNotFound
        }
    }
    
    func rindex(string: String) -> Int {
        if let range = self.rangeOfString(string, options: .BackwardsSearch) {
            return distance(startIndex, range.startIndex)
        } else {
            return NSNotFound
        }
    }
    
    func contains(string: String) -> Bool {
        if let range = self.rangeOfString(string) {
            return true
        } else {
            return false
        }
    }
    
    subscript(index: Int) -> Character {
        return self[advance(startIndex, index)]
    }
    
    subscript(range: Range<Int>) -> String {
        let rangeStartIndex = advance(startIndex, range.startIndex)
            return self[rangeStartIndex..<advance(rangeStartIndex, range.endIndex - range.startIndex)]
    }
    
    func substring(location: Int, _ length: Int) -> String {
        let locationIndex = advance(startIndex, location)
        return self[locationIndex..<advance(locationIndex, length)]
    }
    
    func substringFromIndex(index: Int) -> String {
        return self[advance(startIndex, index)..<endIndex]
    }
    
    func substringToIndex(index: Int) -> String {
        return self[startIndex..<advance(startIndex, index)]
    }
    
    func split(_ delimiter: String = " ") -> [String] {
        return self.componentsSeparatedByString(delimiter)
    }
    
}


extension NSXMLNode {
    
    func nodesForXPath(xpath: String) -> [NSXMLNode] { // FIXME: doesn't work with GAgent childnodes
        return self.nodesForXPath(xpath, error: nil) as [NSXMLNode]
    }
    
    subscript(xpath: String) -> [NSXMLNode] {
        get {
            return self.nodesForXPath(xpath)
        }
    }
    
    func attribute(name: String) -> String! {
        if let attribute = (self as NSXMLElement).attributeForName(name) {
            return attribute.stringValue!
        } else {
            return nil
        }
    }
    
    var href: String {
        get {
            return (self as NSXMLElement).attributeForName("href")!.stringValue!
        }
    }
}


extension NSUserDefaultsController {
    subscript(key: String) -> NSObject! {
        get {
            if let value = self.values.valueForKey(key) as NSObject! {
                return value
            } else {
                return nil
            }
        }
        set(newValue) {
            self.values.setValue(newValue, forKey: key)
        }
    }
}


extension WebView {
    
    override public func swipeWithEvent(event: NSEvent) {
        let x = event.deltaX
        if x < 0 && self.canGoForward {
            self.goForward()
        } else if x > 0 && self.canGoBack {
            self.goBack()
        }
    }
    
    override public func magnifyWithEvent(event: NSEvent) {
        var multiplier: CFloat = self.textSizeMultiplier * CFloat(event.magnification + 1.0)
        self.textSizeMultiplier = multiplier
    }
    
}

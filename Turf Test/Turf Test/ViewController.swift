import UIKit
import JavaScriptCore

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let js = JSContext(virtualMachine: JSVirtualMachine())

        let polygonsJSON = NSString(contentsOfFile:
            NSBundle.mainBundle().pathForResource("polygons", ofType: "geojson")!,
            encoding: NSUTF8StringEncoding,
            error: nil)
        js.setObject(polygonsJSON, forKeyedSubscript: "polygonsJSON")
        js.evaluateScript("var polygons = JSON.parse(polygonsJSON)")

        let utilJS = NSString(contentsOfFile:
            NSBundle.mainBundle().pathForResource("javascript.util.min", ofType: "js")!,
            encoding: NSUTF8StringEncoding,
            error: nil) as! String
        js.evaluateScript(utilJS)

        let turfJS = NSString(contentsOfFile:
            NSBundle.mainBundle().pathForResource("turf.min", ofType: "js")!,
            encoding: NSUTF8StringEncoding,
            error: nil) as! String
        js.evaluateScript(turfJS)

        NSLog("%@", js.evaluateScript("turf.area(polygons)"))
    }

}

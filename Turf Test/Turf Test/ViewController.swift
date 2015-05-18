import UIKit
import MapboxGL
import JavaScriptCore

class ViewController: UIViewController, MGLMapViewDelegate {

    var map: MGLMapView!
    var js: JSContext!
    var slider: UISlider!
    var overlay: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        MGLAccountManager.setMapboxMetricsEnabledSettingShownInApp(true)
        MGLAccountManager.setAccessToken("pk.eyJ1IjoianVzdGluIiwiYSI6IlpDbUJLSUEifQ.4mG8vhelFMju6HpIY-Hi5A")
        map = MGLMapView(frame: view.bounds)
        map.autoresizingMask = .FlexibleWidth | .FlexibleHeight
        map.centerCoordinate = CLLocationCoordinate2D(latitude: 45.52, longitude: -122.681944)
        map.zoomLevel = 13
        map.delegate = self
        view.addSubview(map)

        slider = UISlider(frame: CGRect(x: 20, y: 20, width: map.bounds.size.width - 40, height: 40))
        slider.minimumValue = 100
        slider.maximumValue = 3000
        slider.value = 500
        slider.addTarget(self, action: "updateRadius", forControlEvents: .ValueChanged)
        view.addSubview(slider)

        overlay = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        overlay.center = CGPoint(x: view.bounds.size.width / 2, y: view.bounds.size.height / 2)
        overlay.backgroundColor = UIColor.redColor().colorWithAlphaComponent(0.25)
        overlay.layer.borderColor = UIColor.redColor().colorWithAlphaComponent(0.5).CGColor
        overlay.layer.borderWidth = 3
        overlay.userInteractionEnabled = false
        view.addSubview(overlay)

        js = JSContext(virtualMachine: JSVirtualMachine())

        js.exceptionHandler = { context, value in
            NSLog("Exception: %@", value)
        }

        let starbucksJSON = NSString(contentsOfFile:
            NSBundle.mainBundle().pathForResource("starbucks", ofType: "geojson")!,
            encoding: NSUTF8StringEncoding,
            error: nil)
        js.setObject(starbucksJSON, forKeyedSubscript: "starbucksJSON")
        js.evaluateScript("var starbucks = JSON.parse(starbucksJSON)")

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

        updateRadius()
    }

    func updateRadius() {
        let metersPerPixel = map.metersPerPixelAtLatitude(map.centerCoordinate.latitude)

        overlay.bounds = CGRect(x: 0, y: 0, width: Double(slider.value) * 2 / metersPerPixel,
            height: Double(slider.value) * 2 / metersPerPixel)
        overlay.layer.cornerRadius = overlay.bounds.size.width / 2

        updateShops()
    }

    func updateShops() {
        var coordinates = JSValue(newArrayInContext: js)
        coordinates.setObject(map.centerCoordinate.longitude, atIndexedSubscript: 0)
        coordinates.setObject(map.centerCoordinate.latitude,  atIndexedSubscript: 1)
        let pointFunction = js.objectForKeyedSubscript("turf").objectForKeyedSubscript("point")
        let point = pointFunction.callWithArguments([coordinates])
        js.setObject(point, forKeyedSubscript: "point")

        js.setObject(slider.value, forKeyedSubscript: "radius")

        js.evaluateScript("var within = turf.featurecollection(starbucks.features.filter(function(shop){if (turf.distance(shop, point, 'kilometers') <= radius / 1000) return true;}))")

        let currentAnnotations: [Annotation] = { [unowned self] in
            if self.map.annotations != nil {
                return self.map.annotations as! [Annotation]
            }
            return []
            }()

        var annotationsToKeep = [Annotation]()
        var annotationsToAdd = [Annotation]()

        for i in 0..<js.evaluateScript("within.features.length").toInt32() {
            js.setObject(NSNumber(int: i), forKeyedSubscript: "i")
            let shop = js.evaluateScript("within.features[i]")
            let id = shop.objectForKeyedSubscript("properties").objectForKeyedSubscript("phone").toString()

            let annotation = currentAnnotations.filter({ ($0.id as! String) == id }).first

            if (annotation != nil) {
                annotationsToKeep.append(annotation!)
            } else {
                let lon = shop.objectForKeyedSubscript("geometry").objectForKeyedSubscript("coordinates").objectAtIndexedSubscript(0).toDouble()
                let lat = shop.objectForKeyedSubscript("geometry").objectForKeyedSubscript("coordinates").objectAtIndexedSubscript(1).toDouble()
                let title = shop.objectForKeyedSubscript("properties").objectForKeyedSubscript("street").toString()
                var newAnnotation = Annotation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    title: title)
                newAnnotation.id = id
                annotationsToAdd.append(newAnnotation)
            }
        }

        if currentAnnotations.count > 0 {
            map.removeAnnotations(currentAnnotations.filter({ find(annotationsToKeep, $0) == nil }))
        }

        map.addAnnotations(annotationsToAdd)
    }

    func mapView(mapView: MGLMapView!, regionDidChangeAnimated animated: Bool) {
        updateRadius()
    }

    func mapView(mapView: MGLMapView!, annotationCanShowCallout annotation: MGLAnnotation!) -> Bool {
        return true
    }

}

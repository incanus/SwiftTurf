import Foundation
import MapboxGL
import CoreLocation

class Annotation: NSObject, MGLAnnotation {

    var coordinate: CLLocationCoordinate2D
    var title: String?
    var id: AnyObject?

    init(coordinate: CLLocationCoordinate2D, title: String? = nil) {
        self.coordinate = coordinate
        self.title = title
    }

}

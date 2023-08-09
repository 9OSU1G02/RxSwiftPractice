

import Foundation
import MapKit
import RxCocoa
import RxSwift

extension MKMapView: HasDelegate {}

class RxMapViewDelegateProxy: DelegateProxy<MKMapView, MKMapViewDelegate>, DelegateProxyType, MKMapViewDelegate {
    private(set) weak var mapView: MKMapView?

    public init(mapView: ParentObject) {
        self.mapView = mapView
        super.init(parentObject: mapView, delegateProxy: RxMapViewDelegateProxy.self)
    }

    static func registerKnownImplementations() {
        register { parentObject in
            RxMapViewDelegateProxy(mapView: parentObject)
        }
    }
}

public extension Reactive where Base: MKMapView {
    var delegate: DelegateProxy<MKMapView, MKMapViewDelegate> {
        RxMapViewDelegateProxy.proxy(for: base)
    }

    func setDelegate(_ delegate: MKMapViewDelegate) -> Disposable {
        RxMapViewDelegateProxy.installForwardDelegate(delegate, retainDelegate: false, onProxyForObject: base)
    }

    var overlay: Binder<MKOverlay> {
        Binder(base) { mapView, overlay in
            mapView.removeOverlays(mapView.overlays)
            mapView.addOverlay(overlay)
        }
    }

    var regionDidChangeAnimated: ControlEvent<Bool> {
        let source = delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapView(_:regionDidChangeAnimated:)))
            .map { parameters in
                print("---> regionDidChangeAnimated", delegate)
                return (parameters[1] as? Bool) ?? false
            }
        return ControlEvent(events: source)
    }
}

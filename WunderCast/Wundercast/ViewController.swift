

import CoreLocation
import MapKit
import RxCocoa
import RxSwift
import UIKit

class ViewController: UIViewController {
    @IBOutlet private var mapView: MKMapView!
    @IBOutlet private var mapButton: UIButton!
    @IBOutlet private var geoLocationButton: UIButton!
    @IBOutlet private var activityIndicator: UIActivityIndicatorView!
    @IBOutlet private var searchCityName: UITextField!
    @IBOutlet private var tempLabel: UILabel!
    @IBOutlet private var humidityLabel: UILabel!
    @IBOutlet private var iconLabel: UILabel!
    @IBOutlet private var cityNameLabel: UILabel!
    private let bag = DisposeBag()
    private let locationManager = CLLocationManager()
    private var cache = [String: ApiController.Weather]()
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        style()
        let maxAttempts = 4
        let retryHandler: (Observable<Error>) -> Observable<Int> = { e in
            e.enumerated().flatMap { attempt, error -> Observable<Int> in
                if attempt >= maxAttempts - 1 {
                    return Observable.error(error)
                } else if let casted = error as? ApiController.ApiError, casted == .invalidKey {
                    return ApiController.shared.apiKey
                        .filter { !$0.isEmpty }
                        .map { _ in 1 }
                } else if (error as NSError).code == -1009 {
                    return RxReachability.shared.status
                        .filter { $0 == .online }
                        .map { _ in 1 }
                }
                print("== retrying after \(attempt + 1) seconds ==")
                return Observable<Int>.timer(.seconds(attempt + 1),
                                             scheduler: MainScheduler.instance)
                    .take(1)
            }
        }
        let searchInput = searchCityName.rx
            .controlEvent(.editingDidEndOnExit)
            .map { self.searchCityName.text ?? "" }
            .filter { !$0.isEmpty }

        let mapInput = mapView.rx.regionDidChangeAnimated
            .skip(1)
            .map { _ in
                CLLocation(latitude: self.mapView.centerCoordinate.latitude,
                           longitude: self.mapView.centerCoordinate.longitude)
            }

        let geoInput = geoLocationButton.rx.tap
            .flatMapLatest { _ in self.locationManager.rx.getCurrentLocation() }

        let geoSearch = Observable.merge(geoInput, mapInput)
            .flatMapLatest { location in
                ApiController.shared
                    .currentWeather(at: location.coordinate)
                    .catchAndReturn(.empty)
            }

        let textSearch = searchInput.flatMap { city in
            ApiController.shared
                .currentWeather(for: city)
                .do(onNext: { [weak self] data in
                    self?.cache[city] = data
                }, onError: { error in
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        showError(error: error)
                    }
                })
                .retry(when: retryHandler)
                .catch { _ in
                    Observable.just(self.cache[city] ?? .empty)
                }
        }

        let search = Observable
            .merge(geoSearch, textSearch)
            .asDriver(onErrorJustReturn: .empty)

        let running = Observable.merge(
            searchInput.map { _ in true },
            geoInput.map { _ in true },
            mapInput.map { _ in true },
            search.map { _ in false }.asObservable()
        )
        .startWith(true)
        .asDriver(onErrorJustReturn: false)

        running
            .skip(1)
            .drive(activityIndicator.rx.isAnimating)
            .disposed(by: bag)

        running
            .drive(tempLabel.rx.isHidden)
            .disposed(by: bag)

        running
            .drive(iconLabel.rx.isHidden)
            .disposed(by: bag)

        running
            .drive(humidityLabel.rx.isHidden)
            .disposed(by: bag)

        running
            .drive(cityNameLabel.rx.isHidden)
            .disposed(by: bag)

        search.map { "\($0.temperature)° C" }
            .drive(tempLabel.rx.text)
            .disposed(by: bag)

        search.map(\.icon)
            .drive(iconLabel.rx.text)
            .disposed(by: bag)

        search.map { "\($0.humidity)%" }
            .drive(humidityLabel.rx.text)
            .disposed(by: bag)

        search.map(\.cityName)
            .drive(cityNameLabel.rx.text)
            .disposed(by: bag)

        mapButton.rx.tap
            .subscribe(onNext: {
                self.mapView.isHidden.toggle()
            })
            .disposed(by: bag)

        mapView.rx
            .setDelegate(self)
            .disposed(by: bag)

        search
            .map { $0.overlay() }
            .drive(mapView.rx.overlay)
            .disposed(by: bag)

        _ = RxReachability.shared.startMonitor("openweathermap.org")
    }

    private func showError(error e: Error) {
        guard let e = e as? ApiController.ApiError else {
            InfoView.showIn(viewController: self, message: "An error occurred")
            return
        }

        switch e {
        case .cityNotFound:
            InfoView.showIn(viewController: self, message: "City Name is invalid")
        case .serverFailure:
            InfoView.showIn(viewController: self, message: "Server error")
        case .invalidKey:
            InfoView.showIn(viewController: self, message: "Key is invalid")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        Appearance.applyBottomLine(to: searchCityName)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Style

    private func style() {
        view.backgroundColor = UIColor.aztec
        searchCityName.attributedPlaceholder = NSAttributedString(string: "City's Name",
                                                                  attributes: [.foregroundColor: UIColor.textGrey])
        searchCityName.textColor = UIColor.ufoGreen
        tempLabel.textColor = UIColor.cream
        humidityLabel.textColor = UIColor.cream
        iconLabel.textColor = UIColor.cream
        cityNameLabel.textColor = UIColor.cream
    }
}

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView,
                 rendererFor overlay: MKOverlay) -> MKOverlayRenderer
    {
        guard let overlay = overlay as? ApiController.Weather.Overlay else {
            return MKOverlayRenderer()
        }

        return ApiController.Weather.OverlayView(overlay: overlay,
                                                 overlayIcon: overlay.icon)
    }
}

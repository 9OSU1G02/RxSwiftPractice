

import RxCocoa
import RxSwift
import UIKit

class ViewController: UIViewController {
    @IBOutlet private var searchCityName: UITextField!
    @IBOutlet private var tempLabel: UILabel!
    @IBOutlet private var humidityLabel: UILabel!
    @IBOutlet private var iconLabel: UILabel!
    @IBOutlet private var cityNameLabel: UILabel!
    @IBOutlet private var tempSwitch: UISwitch!
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        ApiController.shared.currentWeather(for: "Hanoi")
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { data in
                self.tempLabel.text = "\(data.temperature)° C"
                self.iconLabel.text = data.icon
                self.humidityLabel.text = "\(data.humidity)%"
                self.cityNameLabel.text = data.cityName
            })
            .disposed(by: disposeBag)

        let textSearch = searchCityName.rx.controlEvent(.editingDidEndOnExit).asObservable()
        let temperature = tempSwitch.rx.controlEvent(.valueChanged).asObservable()
        let search = Observable.merge(textSearch, temperature)
            .map { self.searchCityName.text ?? "" }
            .filter { !$0.isEmpty }
            .flatMap {
                ApiController.shared.currentWeather(for: $0)
            }.asDriver(onErrorJustReturn: .empty)

        search.map { w in
            if self.tempSwitch.isOn {
                return "\(Int(Double(w.temperature) * 1.8 + 32))° F"
            } else {
                return "\(w.temperature)° C"
            }
        }
        .drive(tempLabel.rx.text)
        .disposed(by: disposeBag)

        search.map(\.icon)
            .drive(iconLabel.rx.text)
            .disposed(by: disposeBag)
        search.map { "\($0.humidity)%" }
            .drive(humidityLabel.rx.text)
            .disposed(by: disposeBag)
        search.map(\.cityName)
            .drive(cityNameLabel.rx.text)
            .disposed(by: disposeBag)
        style()
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

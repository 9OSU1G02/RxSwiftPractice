

import RxRelay
import RxSwift
import UIKit

class MainViewController: UIViewController {
  private let bag = DisposeBag()
  private let images = BehaviorRelay<[UIImage]>(value: [])
  @IBOutlet var imagePreview: UIImageView!
  @IBOutlet var buttonClear: UIButton!
  @IBOutlet var buttonSave: UIButton!
  @IBOutlet var itemAdd: UIBarButtonItem!
  private var imageCache = [Int]()

  override func viewDidLoad() {
    super.viewDidLoad()
    let imagesShare = images.share()
    imagesShare.throttle(.milliseconds(500), scheduler: MainScheduler.instance).subscribe(onNext: { [weak imagePreview] photos in
      guard let preview = imagePreview else { return }
      preview.image = photos.collage(size: preview.frame.size)
    }).disposed(by: bag)

    imagesShare.subscribe(onNext: { [weak self] photos in
      self?.updateUI(photos: photos)
    }).disposed(by: bag)
  }

  @IBAction func actionClear() {
    images.accept([])
    imageCache = []
  }

  @IBAction func actionSave() {
    guard let image = imagePreview.image else { return }
    PhotoWriter.save(image)
      .subscribe { [weak self] id in
        self?.showMessage("Saved with id: \(id)")
        self?.actionClear()
      } onFailure: { [weak self] error in
        self?.showMessage("Error", description: error.localizedDescription)
      }
      .disposed(by: bag)
  }

  @IBAction func actionAdd() {
    let photosViewController = storyboard!.instantiateViewController(withIdentifier: "PhotosViewController") as! PhotosViewController
    navigationController!.pushViewController(photosViewController, animated: true)
    let newPhotos = photosViewController.selectedPhotos.share()
    newPhotos
      .take(while: { [weak self] _ in
        let count = self?.images.value.count ?? 0
        return count < 6
      })
      .filter { $0.size.width > $0.size.height }
      .filter { [weak self] in
        let len = $0.pngData()?.count ?? 0
        guard self?.imageCache.contains(len) == false else {
          return false
        }
        self?.imageCache.append(len)
        return true
      }
      .subscribe { [weak self] image in
        guard let self else { return }
        images.accept(images.value + [image])
      } onDisposed: {
        print("Completed photo selection")
      }.disposed(by: bag)

    newPhotos.ignoreElements()
      .subscribe(onCompleted: { [weak self] in
        self?.updateNavigationIcon()
      }).disposed(by: bag)
  }

  private func updateNavigationIcon() {
    let icon = imagePreview.image?
      .scaled(CGSize(width: 22, height: 22))
      .withRenderingMode(.alwaysOriginal)

    navigationItem.leftBarButtonItem = UIBarButtonItem(image: icon,
                                                       style: .done, target: nil, action: nil)
  }

  func showMessage(_ title: String, description: String? = nil) {
    alert(title: title, text: description).subscribe().disposed(by: bag)
  }

  private func updateUI(photos: [UIImage]) {
    buttonSave.isEnabled = photos.count > 0 && photos.count % 2 == 0
    buttonClear.isEnabled = photos.count > 0
    itemAdd.isEnabled = photos.count < 6
    title = photos.count > 0 ? "\(photos.count) photos" : "Collage"
  }
}

extension UIViewController {
  func alert(title: String, text: String? = nil) -> Completable {
    return Completable.create { [weak self] completable in
      let alert = UIAlertController(title: title, message: text, preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "Close", style: .default, handler: { _ in
        completable(.completed)
      }))
      self?.present(alert, animated: true)
      return Disposables.create {
        self?.dismiss(animated: true)
      }
    }
  }
}

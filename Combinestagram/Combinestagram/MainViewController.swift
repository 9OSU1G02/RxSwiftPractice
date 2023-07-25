

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

  override func viewDidLoad() {
    super.viewDidLoad()
    images.subscribe(onNext: { [weak imagePreview] photos in
      guard let preview = imagePreview else { return }
      preview.image = photos.collage(size: preview.frame.size)
    }).disposed(by: bag)

    images.subscribe(onNext: { [weak self] photos in
      self?.updateUI(photos: photos)
    }).disposed(by: bag)
  }

  @IBAction func actionClear() {
    images.accept([])
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
    photosViewController.selectedPhotos.subscribe { [weak self] image in
      guard let self else { return }
      images.accept(images.value + [image])
    } onDisposed: {
      print("Completed photo selection")
    }.disposed(by: bag)
  }

  func showMessage(_ title: String, description: String? = nil) {
    showMessageCompletable(title, description: description).subscribe().disposed(by: bag)
  }

  private func updateUI(photos: [UIImage]) {
    buttonSave.isEnabled = photos.count > 0 && photos.count % 2 == 0
    buttonClear.isEnabled = photos.count > 0
    itemAdd.isEnabled = photos.count < 6
    title = photos.count > 0 ? "\(photos.count) photos" : "Collage"
  }
}

extension UIViewController {
  func showMessageCompletable(_ title: String, description: String? = nil) -> Completable {
    return Completable.create { [weak self] completable in
      let alert = UIAlertController(title: title, message: description, preferredStyle: .alert)
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

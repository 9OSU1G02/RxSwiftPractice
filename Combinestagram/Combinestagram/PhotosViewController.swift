

import Photos
import RxSwift
import UIKit

class PhotosViewController: UICollectionViewController {
  // MARK: public properties

  // MARK: private properties

  private let bag = DisposeBag()
  private let selectedPhotosSubject = PublishSubject<UIImage>()
  var selectedPhotos: Observable<UIImage> {
    return selectedPhotosSubject.asObservable()
  }

  private lazy var photos = PhotosViewController.loadPhotos()
  private lazy var imageManager = PHCachingImageManager()

  private lazy var thumbnailSize: CGSize = {
    let cellSize = (self.collectionViewLayout as! UICollectionViewFlowLayout).itemSize
    return CGSize(width: cellSize.width * UIScreen.main.scale,
                  height: cellSize.height * UIScreen.main.scale)
  }()

  static func loadPhotos() -> PHFetchResult<PHAsset> {
    let allPhotosOptions = PHFetchOptions()
    allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    return PHAsset.fetchAssets(with: allPhotosOptions)
  }

  // MARK: View Controller

  override func viewDidLoad() {
    super.viewDidLoad()
    let authorized = PHPhotoLibrary.authorized.share()
    authorized
      .skip(while: { !$0 })
      .take(1)
      .subscribe(onNext: { [weak self] _ in
        self?.photos = PhotosViewController.loadPhotos()
        DispatchQueue.main.async {
          self?.collectionView.reloadData()
        }
      }).disposed(by: bag)

    authorized
      .skip(1)
      .takeLast(1)
      .filter { !$0 }
      .subscribe(onNext: { [weak self] _ in
        DispatchQueue.main.async {
          self?.errorMessage()
        }
      }).disposed(by: bag)
  }

  private func errorMessage() {
    alert(title: "No access to Camera Roll", text: "You can grant access to Combinestagram from the Settings app")
      .asObservable()
      .take(for: .seconds(5), scheduler: MainScheduler.instance)
      .subscribe(onCompleted: {[weak self] in
        self?.dismiss(animated: true)
        self?.navigationController?.popViewController(animated: true)
      })
      .disposed(by: bag)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    selectedPhotosSubject.onCompleted()
  }

  // MARK: UICollectionView

  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return photos.count
  }

  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let asset = photos.object(at: indexPath.item)
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! PhotoCell

    cell.representedAssetIdentifier = asset.localIdentifier
    imageManager.requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: nil, resultHandler: { image, _ in
      if cell.representedAssetIdentifier == asset.localIdentifier {
        cell.imageView.image = image
      }
    })

    return cell
  }

  override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let asset = photos.object(at: indexPath.item)

    if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
      cell.flash()
    }

    imageManager.requestImage(for: asset, targetSize: view.frame.size, contentMode: .aspectFill, options: nil, resultHandler: { [weak self] image, info in
      guard let image = image, let info = info else { return }
      if let isThumbnail = info[PHImageResultIsDegradedKey as NSString] as? Bool, !isThumbnail {
        self?.selectedPhotosSubject.onNext(image)
      }
    })
  }
}

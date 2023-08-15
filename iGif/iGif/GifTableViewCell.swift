

import Gifu
import RxSwift
import UIKit

class GifTableViewCell: UITableViewCell {
    @IBOutlet private var gifImageView: UIImageView!
    @IBOutlet private var activityIndicator: UIActivityIndicatorView!
  
    var disposable = SingleAssignmentDisposable()
  
    override func prepareForReuse() {
        super.prepareForReuse()
        gifImageView.prepareForReuse()
        gifImageView.image = nil
        disposable.dispose()
        disposable = SingleAssignmentDisposable()
    }
  
    func downloadAndDisplay(gif url: URL) {
        let request = URLRequest(url: url)
        let s = URLSession.shared.rx.data(request: request)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] imageData in
                guard let self else { return }
                gifImageView.animate(withGIFData: imageData)
                activityIndicator.stopAnimating()
            })
        disposable.setDisposable(s)
        activityIndicator.startAnimating()
    }
}

extension UIImageView: GIFAnimatable {
    private enum AssociatedKeys {
        static var AnimatorKey = "gifu.animator.key"
    }
  
    override open func display(_ layer: CALayer) {
        updateImageIfNeeded()
    }
  
    public var animator: Animator? {
        get {
            guard let animator = objc_getAssociatedObject(self, &AssociatedKeys.AnimatorKey) as? Animator else {
                let animator = Animator(withDelegate: self)
                self.animator = animator
                return animator
            }
      
            return animator
        }
    
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.AnimatorKey, newValue as Animator?, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

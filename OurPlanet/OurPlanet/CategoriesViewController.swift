

import RxCocoa
import RxSwift
import UIKit

class CategoriesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  @IBOutlet var tableView: UITableView!
  let download = DownloadView()
  var activityIndicator: UIActivityIndicatorView!
  let categories = BehaviorRelay<[EOCategory]>(value: [])
  let disposeBag = DisposeBag()
  override func viewDidLoad() {
    super.viewDidLoad()
    activityIndicator = UIActivityIndicatorView()
    activityIndicator.color = .black
    navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activityIndicator)
    activityIndicator.startAnimating()
    view.addSubview(download)
    view.layoutIfNeeded()
    categories
      .asObservable()
      .subscribe(onNext: { [weak self] _ in
        DispatchQueue.main.async {
          self?.tableView?.reloadData()
        }
      })
      .disposed(by: disposeBag)
    startDownload()
  }

  func startDownload() {
    let eoCategories = EONET.categories
    let downloadedEvents = eoCategories
      .flatMap { categories in
        Observable.from(categories.map { category in
          EONET.events(forLast: 360, category: category)
        })
      }
      .merge(maxConcurrent: 2)

    let updatedCategories = eoCategories.flatMap { categories in
      downloadedEvents.scan(categories) { updated, events in
        updated.map { category in
          let eventsForCategory = EONET.filteredEvents(events: events, forCategory: category)
          if !eventsForCategory.isEmpty {
            var cat = category
            cat.events = cat.events + eventsForCategory
            return cat
          }
          return category
        }
      }
    }
    .do(onCompleted: { [weak self] in
      DispatchQueue.main.async {
        self?.activityIndicator.stopAnimating()
        self?.download.isHidden = true
      }
    })

    download.progress.progress = 0.0
    download.label.text = "Download: 0%"
    eoCategories.flatMap { categories in
      updatedCategories.scan(0) { count, _ in
        print("count + 1")
        return count + 1
      }
      .startWith(0)
      .map { ($0, categories.count) }
    }
    .subscribe(onNext: { tuple in
      DispatchQueue.main.async { [weak self] in
        let progress = Float(tuple.0) / Float(tuple.1)
        self?.download.progress.progress = progress
        let percent = Int(progress * 100.0)
        self?.download.label.text = "Download: \(percent)%"
        print("Download: \(percent)%")
      }
    })
    .disposed(by: disposeBag)

    eoCategories
      .concat(updatedCategories)
      .bind(to: categories)
      .disposed(by: disposeBag)
  }

  // MARK: UITableViewDataSource

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return categories.value.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "categoryCell")!
    let category = categories.value[indexPath.row]
    cell.textLabel?.text = "\(category.name) (\(category.events.count))"
    cell.accessoryType = (category.events.count > 0) ? .disclosureIndicator : .none
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let category = categories.value[indexPath.row]
    tableView.deselectRow(at: indexPath, animated: true)

    guard !category.events.isEmpty else { return }

    let eventsController = storyboard!.instantiateViewController(withIdentifier: "events") as! EventsViewController
    eventsController.title = category.name
    eventsController.events.accept(category.events)
    navigationController!.pushViewController(eventsController, animated: true)
  }
}

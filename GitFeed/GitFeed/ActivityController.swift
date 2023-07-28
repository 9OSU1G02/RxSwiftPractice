

import Kingfisher
import RxCocoa
import RxSwift
import UIKit

func cachedFileURL(_ fileName: String) -> URL {
  return FileManager.default
    .urls(for: .cachesDirectory, in: .allDomainsMask)
    .first!
    .appendingPathComponent(fileName)
}

class ActivityController: UITableViewController {
  private let repo = "ReactiveX/RxSwift"
  private let eventsFileURL = cachedFileURL("events.json")
  private let events = BehaviorRelay<[Event]>(value: [])
  private let bag = DisposeBag()
  private let modifiedFileURL = cachedFileURL("modified.txt")
  private let lastModified = BehaviorRelay<String?>(value: nil)
  override func viewDidLoad() {
    super.viewDidLoad()
    title = repo

    self.refreshControl = UIRefreshControl()
    let refreshControl = self.refreshControl!

    refreshControl.backgroundColor = UIColor(white: 0.98, alpha: 1.0)
    refreshControl.tintColor = UIColor.darkGray
    refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
    refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
    let decoder = JSONDecoder()
    if let eventsData = try? Data(contentsOf: eventsFileURL), let persistendEvents = try? decoder.decode([Event].self, from: eventsData) {
      events.accept(persistendEvents)
    }
    if let lasModifiedString = try? String(contentsOf: modifiedFileURL, encoding: .utf8) {
      lastModified.accept(lasModifiedString)
    }
    refresh()
  }

  @objc func refresh() {
    DispatchQueue.global(qos: .default).async { [weak self] in
      guard let self = self else { return }
      self.fetchEvents(repo: self.repo)
    }
  }

  func fetchEvents(repo: String) {
    let response = Observable.from(["https://api.github.com/search/repositories?q=language:swift&per_page=5"])
      .map { URLRequest(url: .init(string: $0)!) }
      .flatMap { URLSession.shared.rx.json(request: $0) }
      .flatMap { response -> Observable<String> in
        guard let response = response as? [String: Any],
              let items = response["items"] as? [[String: Any]] else {
          return Observable.empty()
        }
        return Observable.from(items.map { $0["full_name"] as! String })
      }
      .map {
        URL(string: "https://api.github.com/repos/\($0)/events?per_page=5")!
      }
      .map { [weak self] in
        var request = URLRequest(url: $0)
        if let modifiedHeader = self?.lastModified.value {
          request.addValue(modifiedHeader, forHTTPHeaderField: "Last-Modified")
        }
        return request
      }
      .flatMap { URLSession.shared.rx.response(request: $0) }
      .share(replay: 1)
    response.filter { 200 ..< 300 ~= $0.0.statusCode }
      .compactMap { try? JSONDecoder().decode([Event].self, from: $1) }
      .subscribe(onNext: { [weak self] in
        self?.processEvents($0)
      })
      .disposed(by: bag)
    response.filter { 200 ..< 400 ~= $0.0.statusCode }
      .flatMap { response, _ -> Observable<String> in
        guard let value = response.allHeaderFields["Last-Modified"] as? String else {
          return Observable.empty()
        }
        return Observable.just(value)
      }
      .subscribe(onNext: { [weak self] modifiedHeader in
        guard let self = self else { return }
        lastModified.accept(modifiedHeader)
        try? modifiedHeader.write(to: modifiedFileURL, atomically: true, encoding: .utf8)
      }).disposed(by: bag)
  }

  func processEvents(_ newEvents: [Event]) {
    var updatedEvents = newEvents + events.value
    if updatedEvents.count > 50 {
      updatedEvents = [Event](updatedEvents.prefix(upTo: 50))
    }
    events.accept(updatedEvents)
    DispatchQueue.main.async {
      self.tableView.reloadData()
      self.refreshControl?.endRefreshing()
    }
    let encoder = JSONEncoder()
    if let eventsData = try? encoder.encode(updatedEvents) {
      try? eventsData.write(to: eventsFileURL, options: .atomicWrite)
    }
  }

  // MARK: - Table Data Source

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return events.value.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let event = events.value[indexPath.row]

    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
    cell.textLabel?.text = event.actor.name
    cell.detailTextLabel?.text = event.repo.name + ", " + event.action.replacingOccurrences(of: "Event", with: "").lowercased()
    cell.imageView?.kf.setImage(with: event.actor.avatar, placeholder: UIImage(named: "blank-avatar"))
    return cell
  }
}

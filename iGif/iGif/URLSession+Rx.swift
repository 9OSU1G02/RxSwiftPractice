

import Foundation
import RxSwift

private var internalCache = [String: Data]()
extension ObservableType where Element == (HTTPURLResponse, Data) {
    func cache() -> Observable<Element> {
        return self.do(onNext: { response, data in
            guard let url = response.url?.absoluteString, 200 ..< 300 ~= response.statusCode else { return }
            internalCache[url] = data
        })
    }
}

public enum RxURLSessionError: Error {
    case unknown
    case invalidResponse(response: URLResponse)
    case requestFailed(response: HTTPURLResponse, data: Data?)
    case deserializationFailed
}

extension Reactive where Base: URLSession {
    func response(request: URLRequest) -> Observable<(HTTPURLResponse, Data)> {
        return Observable.create { observer in
            let task = self.base.dataTask(with: request) { data, response, error in
                guard let response, let data else {
                    observer.onError(error ?? RxURLSessionError.unknown)
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    observer.onError(RxURLSessionError.invalidResponse(response: response))
                    return
                }
                observer.onNext((httpResponse, data))
                observer.onCompleted()
            }
            task.resume()
            return Disposables.create { task.cancel() }
        }
    }

    func data(request: URLRequest) -> Observable<Data> {
        if let url = request.url?.absoluteString,
           let data = internalCache[url]
        {
            return Observable.just(data)
        }
        return response(request: request).cache()
            .map { response, data -> Data in
                guard 200 ..< 300 ~= response.statusCode else {
                    throw RxURLSessionError.requestFailed(response: response, data: data)
                }

                return data
            }
    }

    func string(request: URLRequest) -> Observable<String> {
        return data(request: request).map { String(data: $0, encoding: .utf8) ?? "" }
    }

    func json(request: URLRequest) -> Observable<Any> {
        return data(request: request).map { try JSONSerialization.jsonObject(with: $0) }
    }

    func decodable<D: Decodable>(request: URLRequest,
                                 type: D.Type) -> Observable<D>
    {
        return data(request: request).map { data in
            let decoder = JSONDecoder()
            return try decoder.decode(type, from: data)
        }
    }

    func image(request: URLRequest) -> Observable<UIImage> {
        return data(request: request).map { data in
            guard let image = UIImage(data: data) else {
                throw RxURLSessionError.deserializationFailed
            }
            return image
        }
    }
}

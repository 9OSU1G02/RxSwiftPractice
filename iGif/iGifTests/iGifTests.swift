

import XCTest
import RxSwift
import RxBlocking
import Nimble
import RxNimble
import OHHTTPStubs

@testable import iGif

class iGifTests: XCTestCase {
  let obj = ["array": ["foo", "bar"], "foo": "bar"] as [String: AnyHashable]
  let request = URLRequest(url: URL(string: "http://raywenderlich.com")!)
  let errorRequest = URLRequest(url: URL(string: "http://rw.com")!)
  
  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.
    stub(condition: isHost("raywenderlich.com")) { _ in
      return HTTPStubsResponse(jsonObject: self.obj, statusCode: 200, headers: nil)
    }
    stub(condition: isHost("rw.com")) { _ in
      return HTTPStubsResponse(error: RxURLSessionError.unknown)
    }
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
    HTTPStubs.removeAllStubs()
  }
}

extension BlockingObservable {
  func firstOrNil() -> Element? {
    do {
      return try first()
    } catch {
      return nil
    }
  }
}

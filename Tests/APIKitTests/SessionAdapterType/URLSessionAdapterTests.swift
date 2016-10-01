import Foundation
import XCTest
import Dispatch

@testable import APIKit

class URLSessionAdapterTests: XCTestCase {
    var adapter: URLSessionAdapter!
    var session: Session!

    override func setUp() {
        super.setUp()
        
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [HTTPStub.self]
        
        adapter = URLSessionAdapter(configuration: configuration)
        session = Session(adapter: adapter)
    }

    // MARK: - integration tests
    func testSuccess() {
        let dictionary = ["key": "value"]
        let data = try! JSONSerialization.data(withJSONObject: dictionary, options: [])
        HTTPStub.stubResult = .success(data)
        
        let expectation = self.expectation(description: "wait for response")
        let request = TestRequest()

        session.send(request) { response in
            switch response {
            case .success(let dictionary):
                XCTAssertEqual((dictionary as? [String: String])?["key"], "value")

            case .failure:
                XCTFail()
            }
            
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0, handler: nil)
        
        XCTAssert(session.requests.isEmpty)
        XCTAssert(adapter.taskProperties.isEmpty)
    }
    
    func testConnectionError() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        HTTPStub.stubResult = .failure(error)
        
        let expectation = self.expectation(description: "wait for response")
        let request = TestRequest()

        session.send(request) { response in
            switch response {
            case .success:
                XCTFail()
                
            case .failure(let error):
                switch error {
                case .connectionError(let error as NSError):
                    XCTAssertEqual(error.domain, NSURLErrorDomain)

                default:
                    XCTFail()
                }
            }

            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)

        XCTAssert(session.requests.isEmpty)
        XCTAssert(adapter.taskProperties.isEmpty)
    }

    func testCancel() {
        let data = "{}".data(using: .utf8)!
        HTTPStub.stubResult = .success(data)

        let expectation = self.expectation(description: "wait for response")
        let request = TestRequest()

        session.send(request) { result in
            print(result)
            guard case .failure(let error) = result,
                  case .connectionError(let connectionError as NSError) = error else {
                XCTFail()
                return
            }

            XCTAssertEqual(connectionError.code, NSURLErrorCancelled)

            expectation.fulfill()
        }

        DispatchQueue.main.async {
            self.session.cancelRequests(with: TestRequest.self)
        }

        waitForExpectations(timeout: 10.0, handler: nil)

        XCTAssert(session.requests.isEmpty)
        XCTAssert(adapter.taskProperties.isEmpty)
    }
}

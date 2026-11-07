import Foundation

func require(_ condition: Bool, _ message: String) {
    if !condition { fatalError(message) }
}
func field(_ text: String) -> Data {
    let bytes = Data(text.utf8)
    require(bytes.count < 128, "This fixture uses a one-byte length")
    return Data([0x0a, UInt8(bytes.count)]) + bytes
}
let inner = field("editorial-card") + field("UPSELL-BANNER premium offer")
let body = Data([0x0a, UInt8(inner.count)]) + inner
let url = URL(string: "https://spclient.wg.spotify.com/scrollsita/v1/home")!
let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [:])!
let transaction = USResponseTransaction(response: response)
require(USEeveeFeedModule.attach(to: transaction), "Register actual Eevee feed transformer")
require(!USEeveeFeedModule.attach(to: transaction), "Prevent duplicate feature registration")
require(transaction.append(body.prefix(5)), "Receive first chunk")
require(transaction.append(body.dropFirst(5)), "Receive second chunk")
let done = DispatchSemaphore(value: 0)
require(transaction.finish(error: nil, workQueue: .global(), deliveryQueue: DispatchQueue(label: "feed.delivery")) { output, error in
    require(error == nil, "Transformation succeeds")
    require(output.data.count < body.count, "Real Eevee algorithm removes promotional section")
    require(String(data: output.data, encoding: .utf8)?.contains("editorial-card") == true,
            "Editorial content remains present")
    require(output.response.value(forHTTPHeaderField: "Content-Length") == String(output.data.count),
            "Shared pipeline updates body metadata")
    done.signal()
}, "First completion is accepted")
require(done.wait(timeout: .now() + 5) == .success, "Integrated adapter completes")
print("Actual Eevee feed transformer + shared transaction integration test passed")

import Foundation
@testable import OTPBarCore

let publicTestSecret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"

func fixture(_ name: String) throws -> Data {
    let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
    return try Data(contentsOf: url)
}

func modifiedBackup(_ modify: (inout [String: Any]) -> Void) throws -> Data {
    var json = try JSONSerialization.jsonObject(with: fixture("plaintext-v4")) as! [String: Any]
    modify(&json)
    return try JSONSerialization.data(withJSONObject: json)
}

enum TestFailure: Error { case read, write }

final class MemoryStorage: VaultStorage {
    var data: Data?
    var failRead = false
    var failWrite = false
    var writes = 0
    func read() throws -> Data? {
        if failRead { throw TestFailure.read }
        return data
    }
    func write(_ data: Data) throws {
        if failWrite { throw TestFailure.write }
        self.data = data
        writes += 1
    }
}

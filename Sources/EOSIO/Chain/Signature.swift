/// EOSIO signature type.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import Foundation

/// Type representing a EOSIO signature.
public struct Signature: Equatable, Hashable {
    /// Private storage container that holds signature data.
    private enum StorageType: Equatable, Hashable {
        case k1(sig: Data, recovery: Int8)
        case unknown(name: String, data: Data)
    }

    /// Errors `Signature` can throw.
    public enum Error: Swift.Error {
        case parsingFailed(_ message: String)
        case invalidK1(_ message: String)
        case unknownSignatureType
    }

    /// The signature data.
    private let value: StorageType

    /// Create a new `Signature` from the private storage type.
    private init(value: StorageType) {
        self.value = value
    }

    public init(fromK1Data data: Data) throws {
        guard data.count == 65 else {
            throw Error.invalidK1("Expected 65 bytes, got \(data.count)")
        }
        self.value = .k1(sig: data.suffix(from: 1), recovery: Int8(data[0]) - 31)
    }

    public init(fromK1 sig: Data, recovery: Int8) {
        self.value = .k1(sig: sig, recovery: recovery)
    }

    public init(type: String, data: Data) throws {
        guard type.count == 2, type.uppercased() == type else {
            throw Error.parsingFailed("Invalid curve type")
        }
        self.value = .unknown(name: type, data: data)
    }

    public init(stringValue: String) throws {
        let parts = stringValue.split(separator: "_")
        guard parts.count == 3 else {
            throw Error.parsingFailed("Malformed signature string")
        }
        guard parts[0] == "SIG" else {
            throw Error.parsingFailed("Expected SIG prefix")
        }
        let checksumData = parts[1].data(using: .utf8) ?? Data(repeating: 0, count: 4)
        guard let data = Data(base58CheckEncoded: String(parts[2]), .ripemd160Extra(checksumData)) else {
            throw Error.parsingFailed("Unable to decode base58")
        }
        switch parts[1] {
        case "K1":
            try self.init(fromK1Data: data)
        default:
            try self.init(type: String(parts[1]), data: data)
        }
    }

    public func verify(_ hash: Checksum256, using key: PublicKey) -> Bool {
        switch self.value {
        case let .k1(sig, _):
            return Secp256k1.shared.verify(signature: sig, message: hash.bytes, publicKey: key.keyData)
        case .unknown:
            return false
        }
    }

    public func verify(_ data: Data, using key: PublicKey) -> Bool {
        return self.verify(Checksum256.hash(data), using: key)
    }

    public func recoverPublicKey(from hash: Checksum256) throws -> PublicKey {
        switch self.value {
        case let .k1(sig, recId):
            let recovered = try Secp256k1.shared.recover(
                message: hash.bytes, signature: sig, recoveryId: Int32(recId)
            )
            return try PublicKey(fromK1Data: recovered)
        case .unknown:
            throw Error.unknownSignatureType
        }
    }

    public func recoverPublicKey(from message: Data) throws -> PublicKey {
        return try self.recoverPublicKey(from: Checksum256.hash(message))
    }

    public var signatureType: String {
        switch self.value {
        case .k1:
            return "K1"
        case let .unknown(name, _):
            return name
        }
    }

    public var signatureData: Data {
        switch self.value {
        case let .k1(sig, recovery):
            return Data([UInt8(recovery) + 31]) + sig
        case let .unknown(_, data):
            return data
        }
    }

    public var stringValue: String {
        let type = self.signatureType
        let encoded = self.signatureData.base58CheckEncodedString(.ripemd160Extra(Data(type.utf8)))!
        return "SIG_\(type)_\(encoded)"
    }
}

// MARK: ABI Coding

extension Signature: ABICodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(stringValue: try container.decode(String.self))
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        let type = try decoder.decode(UInt8.self)
        let data = try decoder.decode(Data.self, byteCount: 65)
        if type == 0 {
            self = try Signature(fromK1Data: data)
        } else {
            switch type {
            case 1:
                self.value = .unknown(name: "R1", data: data)
            case 2:
                self.value = .unknown(name: "WA", data: data)
            default:
                self.value = .unknown(name: "XX", data: data)
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.stringValue)
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        let type: UInt8
        switch self.signatureType {
        case "K1":
            type = 0
        case "R1":
            type = 1
        case "WA":
            type = 2
        default:
            type = 255
        }
        try encoder.encode(type)
        try encoder.encode(contentsOf: self.signatureData)
    }
}

// MARK: Language extensions

extension Signature: LosslessStringConvertible {
    public init?(_ description: String) {
        guard let instance = try? Signature(stringValue: description) else {
            return nil
        }
        self = instance
    }

    public var description: String {
        return self.stringValue
    }
}

extension Signature: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        guard let instance = try? Signature(stringValue: value) else {
            fatalError("Invalid Signature literal")
        }
        self = instance
    }
}

import Foundation

public protocol VaultStorage {
    func read() throws -> Data?
    func write(_ data: Data) throws
}

public struct ImportResult: Equatable, Sendable {
    public let added: Int
    public let skipped: Int
}

public struct TokenVault {
    public private(set) var entries: [OTPEntry]
    private let storage: any VaultStorage

    public init(storage: any VaultStorage) throws {
        self.storage = storage
        // A failed read must never create an empty vault that can overwrite existing data.
        if let data = try storage.read() {
            do {
                let saved = try JSONDecoder().decode(SavedVault.self, from: data)
                guard saved.schemaVersion == 1, Set(saved.entries.map(\.id)).count == saved.entries.count else {
                    throw OTPError.invalidVault
                }
                for (index, entry) in saved.entries.enumerated() {
                    guard !saved.entries.prefix(index).contains(where: { $0.hasSameGenerator(as: entry) }) else {
                        throw OTPError.invalidVault
                    }
                }
                entries = saved.entries
            } catch {
                throw OTPError.invalidVault
            }
        } else {
            entries = []
        }
    }

    @discardableResult
    public mutating func importBackup(_ data: Data, password: String? = nil) throws -> ImportResult {
        let incoming = try TwoFASImporter.read(data, password: password)
        var next = entries
        var skipped = 0
        for entry in incoming {
            if next.contains(where: { $0.hasSameGenerator(as: entry) }) {
                skipped += 1
            } else {
                next.append(entry)
            }
        }
        let added = next.count - entries.count
        if added > 0 { try save(next) }
        return ImportResult(added: added, skipped: skipped)
    }

    public mutating func update(_ entry: OTPEntry) throws {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { throw OTPError.entryNotFound }
        guard !entries.contains(where: { $0.id != entry.id && $0.hasSameGenerator(as: entry) }) else {
            throw OTPError.duplicateEntry
        }
        var next = entries
        next[index] = entry
        try save(next)
    }

    public func code(for id: UUID, at date: Date = Date()) throws -> OTPCode {
        guard let entry = entries.first(where: { $0.id == id }) else { throw OTPError.entryNotFound }
        return try TOTP.generate(for: entry, at: date)
    }

    public mutating func remove(id: UUID) throws {
        guard entries.contains(where: { $0.id == id }) else { throw OTPError.entryNotFound }
        try save(entries.filter { $0.id != id })
    }

    private mutating func save(_ next: [OTPEntry]) throws {
        let data = try JSONEncoder().encode(SavedVault(schemaVersion: 1, entries: next))
        try storage.write(data)
        entries = next
    }

    private struct SavedVault: Codable {
        let schemaVersion: Int
        let entries: [OTPEntry]
    }
}

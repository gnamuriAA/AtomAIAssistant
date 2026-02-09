//
//  ChunkModels.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import Foundation

enum NoticeSeverity: String, Codable {
    case note
    case warning
    case error
}

struct Notice: Codable, Hashable {
    let severity: NoticeSeverity
    let title: String?
    let message: String
}

enum ChunkKind: String, Codable {
    case text
    case tableRow
    case notice
}

struct ParsedChunk: Codable, Hashable {
    let docName: String
    let page: Int
    let headerPath: [String]
    let kind: ChunkKind
    
    // Text content (for .text)
    let text: String?
    
    // Table content (for .tableRow)
    let tableName: String?
    let columns: [String]?
    let rowValues: [String: String]?
    
    let notice: Notice?

    init(
        docName: String,
        page: Int,
        headerPath: [String],
        kind: ChunkKind,
        text: String? = nil,
        tableName: String? = nil,
        columns: [String]? = nil,
        rowValues: [String: String]? = nil,
        notice: Notice? = nil
    ) {
        self.docName = docName
        self.page = page
        self.headerPath = headerPath
        self.kind = kind
        self.text = text
        self.tableName = tableName
        self.columns = columns
        self.rowValues = rowValues
        self.notice = notice
    }

    var formattedTableString: String? {
        guard kind == .tableRow, let rowValues else {
            return nil
        }

        let table = tableName ?? "Table"
        
        let rowString = rowValues
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key): \($0.value)" }
            .joined(separator: " ")

        return "\(table) - \(rowString)"
    }
}

struct HeadingPath {
    private(set) var levels: [String] = []
    
    mutating func set(level: Int, title: String) {
        if levels.count >= level {
            levels = Array(levels.prefix(level - 1))
        } else if levels.count < level - 1 {
            while levels.count < level - 1 { levels.append("Untitled") }
        }
        levels.append(title.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

enum chunkMetaCodec {
    static func encode(_ chunk: ParsedChunk) -> Data? {
        let meta = ChunkMeta(tableName: chunk.tableName, columns: chunk.columns, rowValues: chunk.rowValues, notice: chunk.notice)
        return try? JSONEncoder().encode(meta)
    }

    static func decode(_ data: Data) -> ChunkMeta? {
        return try? JSONDecoder().decode(ChunkMeta.self, from: data)
    }
}

struct ChunkMeta: Codable, Hashable {
    let tableName: String?
    let columns: [String]?
    let rowValues: [String: String]?
    let notice: Notice?
}

extension ParsedChunk {
    static func fromEmbed(_ c: EmbedChunk) -> ParsedChunk {
        let kind: ChunkKind
        switch c.kind {
        case .text, .digest: kind = .text
        case .table: kind = .tableRow
        case .notice: kind = .notice
        }
        
        var tableName: String? = nil
        var columns: [String]? = nil
        
        if c.kind == .table {
            tableName = c.meta["tableName"]
            if let cols = c.meta["columns"] {
                columns = cols.split(separator: "|").map { String($0) }
            }
        }
        
        var notice: Notice? = nil
        
        if c.kind == .notice {
            let sevSer = (c.meta["severity"] ?? "note")
            let sev = NoticeSeverity(rawValue: sevSer) ?? .note
            notice = Notice(severity: sev, title: nil, message: c.text)
        }

        return ParsedChunk(docName: c.docName, page: c.pageStart, headerPath: c.headerPath, kind: .text, text: c.text, tableName: tableName, columns: columns, rowValues: nil, notice: notice)
    }
}

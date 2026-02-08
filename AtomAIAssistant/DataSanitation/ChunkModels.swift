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

struct ChunkRecord: Codable, Hashable {
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
        page: Int,
        headerPath: [String],
        kind: ChunkKind,
        text: String? = nil,
        tableName: String? = nil,
        columns: [String]? = nil,
        rowValues: [String: String]? = nil,
        notice: Notice? = nil
    ) {
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

        let header = headerPath.joined(separator: "/")
        let table = tableName ?? "Table"
        
        let rowString = rowValues
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key): \($0.value)" }
            .joined(separator: " ")

        return "\(header) - \(table) - \(rowString)"
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

//
//  SemanticChunkingIndex.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 09/02/26.
//

import Foundation

enum EmbedChunkKind: String, Codable {
    case text      // aggregated prose
    case table     // table header + group of rows
    case notice    // one notice (warning/error/note)
    case digest    // optional per-section summary chunk (H2-ish)
}

struct EmbedChunk: Codable, Hashable, Identifiable {
    let id: String
    let docName: String
    let pageStart: Int
    let pageEnd: Int
    let headerPath: [String]
    let parentKey: String?          // stable grouping key (usually headerPath up to H2/H3)
    let kind: EmbedChunkKind
    let text: String
    let meta: [String: String]

    var tokenHintChars: Int { text.count }
}

// MARK: - Chunking config
struct ParsedChunkingConfig {
    /// Soft limit for chunk size (characters). Good default if you later embed with Azure/OpenAI models.
    var maxChars: Int = 1800

    /// When aggregating text, allow a small semantic overlap from previous chunk tail.
    var includeTailOverlap: Bool = true
    var tailChars: Int = 200

    /// Group table rows into table chunks. This is the most important part.
    var maxTableRowsPerChunk: Int = 25

    /// If a table chunk is still too large, reduce row count adaptively.
    var adaptiveTableSplit: Bool = true

    /// Create a digest chunk per parent section (helps recall). Optional.
    var createSectionDigest: Bool = true
    var digestMaxLines: Int = 10

    /// How many headers from headerPath should be used to form parentKey.
    /// - Example: 2 means H1+H2 (if available).
    var parentHeaderDepth: Int = 2
}

// MARK: - Chunker for your ParsedChunk stream
final class ParsedChunker {
    private let config: ParsedChunkingConfig

    init(config: ParsedChunkingConfig = .init()) {
        self.config = config
    }

    func makeEmbedChunks(from parsed: [ParsedChunk]) -> [EmbedChunk] {
        var out: [EmbedChunk] = []
        out.reserveCapacity(max(16, parsed.count / 2))

        // Buffers
        var textBuffer: [String] = []
        var textPages: (start: Int, end: Int)? = nil
        var textHeaderPath: [String] = []
        var lastTail: String = ""

        // Table buffering (group contiguous rows of same table within same headerPath)
        struct TableBuf {
            var docName: String
            var pageStart: Int
            var pageEnd: Int
            var headerPath: [String]
            var tableName: String
            var columns: [String]
            var rows: [[String: String]] // each rowValues dict
        }
        var tableBuf: TableBuf? = nil

        // Digest per parent section
        var digestLinesByParent: [String: [String]] = [:]

        func mkId(_ doc: String, _ kind: EmbedChunkKind, _ idx: Int) -> String {
            "\(doc)::\(kind.rawValue)::\(idx)::\(UUID().uuidString.lowercased())"
        }

        func parentKey(for headerPath: [String], docName: String) -> String? {
            guard !headerPath.isEmpty else { return nil }
            let depth = min(config.parentHeaderDepth, headerPath.count)
            let keyPath = headerPath.prefix(depth).joined(separator: " > ")
            return "\(docName)::\(keyPath)"
        }

        func contextPrefix(headerPath: [String], pageStart: Int, pageEnd: Int) -> String {
            let path = headerPath.joined(separator: " > ")
            var s = ""
            if !path.isEmpty {
                s += "Context: \(path)\n"
            }
            if pageStart == pageEnd {
                s += "Page: \(pageStart)\n\n"
            } else {
                s += "Pages: \(pageStart)-\(pageEnd)\n\n"
            }
            return s
        }

        func addDigestLine(parent: String?, _ line: String) {
            guard config.createSectionDigest else { return }
            guard let parent else { return }
            let cleaned = line
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return }
            digestLinesByParent[parent, default: []].append(cleaned)
        }

        func flushText(into outArr: inout [EmbedChunk]) {
            let body = textBuffer.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty, let pages = textPages else {
                textBuffer.removeAll(keepingCapacity: true)
                textPages = nil
                return
            }

            var finalBody = body
            if config.includeTailOverlap, !lastTail.isEmpty {
                let tail = String(lastTail.suffix(config.tailChars))
                // Put overlap after context line to avoid confusing the model
                finalBody = "Previous context: \(tail)\n\n" + finalBody
            }

            let prefix = contextPrefix(headerPath: textHeaderPath, pageStart: pages.start, pageEnd: pages.end)
            finalBody = prefix + finalBody

            let idx = outArr.count
            outArr.append(
                EmbedChunk(
                    id: mkId(parsed.first?.docName ?? "doc", .text, idx),
                    docName: parsed.first?.docName ?? "doc",
                    pageStart: pages.start,
                    pageEnd: pages.end,
                    headerPath: textHeaderPath,
                    parentKey: parentKey(for: textHeaderPath, docName: parsed.first?.docName ?? "doc"),
                    kind: .text,
                    text: finalBody,
                    meta: [
                        "sourceKind": "text",
                        "headerDepth": "\(textHeaderPath.count)"
                    ]
                )
            )

            lastTail = body.suffix(config.tailChars).description
            textBuffer.removeAll(keepingCapacity: true)
            textPages = nil
        }

        func flushTable(into outArr: inout [EmbedChunk]) {
            guard let tb = tableBuf, !tb.rows.isEmpty else { return }

            // Create chunks: header + N rows
            var i = 0
            let total = tb.rows.count

            while i < total {
                var rowsPer = config.maxTableRowsPerChunk
                var made = false

                while !made {
                    let end = min(total, i + rowsPer)
                    let slice = tb.rows[i..<end]

                    let headerLine = "Table: \(tb.tableName)\nColumns: " + tb.columns.joined(separator: " | ")
                    var rowsText = "Rows:\n"
                    for (offset, row) in slice.enumerated() {
                        // keep stable column order
                        let line = tb.columns.map { col in
                            let v = row[col] ?? row[col.lowercased()] ?? row[col.uppercased()] ?? ""
                            return "\(col): \(v)"
                        }.joined(separator: "  ")
                        rowsText += "\(i + offset + 1). \(line)\n"
                    }

                    var body = (headerLine + "\n" + rowsText).trimmingCharacters(in: .whitespacesAndNewlines)
                    let prefix = contextPrefix(headerPath: tb.headerPath, pageStart: tb.pageStart, pageEnd: tb.pageEnd)
                    body = prefix + body

                    if body.count <= config.maxChars || !config.adaptiveTableSplit || rowsPer == 1 {
                        let idx = outArr.count
                        outArr.append(
                            EmbedChunk(
                                id: mkId(tb.docName, .table, idx),
                                docName: tb.docName,
                                pageStart: tb.pageStart,
                                pageEnd: tb.pageEnd,
                                headerPath: tb.headerPath,
                                parentKey: parentKey(for: tb.headerPath, docName: tb.docName),
                                kind: .table,
                                text: body,
                                meta: [
                                    "sourceKind": "table",
                                    "tableName": tb.tableName,
                                    "rowStart": "\(i + 1)",
                                    "rowEnd": "\(end)",
                                    "totalRows": "\(total)",
                                    "columns": tb.columns.joined(separator: "|")
                                ]
                            )
                        )
                        i = end
                        made = true
                    } else {
                        // Reduce rowsPer
                        rowsPer = max(1, rowsPer / 2)
                    }
                }
            }

            tableBuf = nil
        }

        func flushAll(into outArr: inout [EmbedChunk]) {
            flushText(into: &outArr)
            flushTable(into: &outArr)
        }

        // MARK: - Main loop
        for pc in parsed {
            // Add to digest cheaply
            let pKey = parentKey(for: pc.headerPath, docName: pc.docName)

            switch pc.kind {
            case .notice:
                // flush buffers so notices remain isolated
                flushAll(into: &out)

                if let n = pc.notice {
                    let sev = n.severity.rawValue.uppercased()
                    let title = n.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let msg = n.message.trimmingCharacters(in: .whitespacesAndNewlines)

                    var body = "\(sev)"
                    if let title, !title.isEmpty { body += ": \(title)" }
                    body += "\n\n\(msg)"

                    let prefix = contextPrefix(headerPath: pc.headerPath, pageStart: pc.page, pageEnd: pc.page)
                    body = prefix + body

                    let idx = out.count
                    out.append(
                        EmbedChunk(
                            id: mkId(pc.docName, .notice, idx),
                            docName: pc.docName,
                            pageStart: pc.page,
                            pageEnd: pc.page,
                            headerPath: pc.headerPath,
                            parentKey: pKey,
                            kind: .notice,
                            text: body,
                            meta: [
                                "sourceKind": "notice",
                                "severity": n.severity.rawValue,
                                "hasTitle": "\(n.title != nil)"
                            ]
                        )
                    )

                    addDigestLine(parent: pKey, "\(n.severity.rawValue): \(title ?? "") \(msg.prefix(120))")
                }

            case .tableRow:
                // flush text buffer before grouping table
                flushText(into: &out)

                guard let tName = pc.tableName,
                      let cols = pc.columns,
                      let row = pc.rowValues else {
                    continue
                }

                addDigestLine(parent: pKey, "Table \(tName): \(row.values.joined(separator: " ").prefix(100))")

                // Start or continue a table buffer if it matches
                if let tb = tableBuf,
                   tb.docName == pc.docName,
                   tb.tableName == tName,
                   tb.headerPath == pc.headerPath {
                    // continue
                    tableBuf?.rows.append(row)
                    tableBuf?.pageEnd = max(tb.pageEnd, pc.page)

                    // if table buffer grows too large, flush
                    // (rough estimate: average row size 80 chars)
                    if (tableBuf?.rows.count ?? 0) >= config.maxTableRowsPerChunk * 2 {
                        flushTable(into: &out)
                    }
                } else {
                    // flush previous different table
                    flushTable(into: &out)
                    tableBuf = TableBuf(
                        docName: pc.docName,
                        pageStart: pc.page,
                        pageEnd: pc.page,
                        headerPath: pc.headerPath,
                        tableName: tName,
                        columns: cols,
                        rows: [row]
                    )
                }

            case .text:
                // flush table buffer before aggregating text
                flushTable(into: &out)

                guard let t = pc.text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else {
                    continue
                }

                addDigestLine(parent: pKey, t.count > 120 ? String(t.prefix(120)) + "…" : t)

                // If headerPath changed, commit existing text buffer (keeps chunks coherent by section)
                if !textBuffer.isEmpty && pc.headerPath != textHeaderPath {
                    flushText(into: &out)
                }

                // init pages/header for buffer
                if textPages == nil {
                    textPages = (start: pc.page, end: pc.page)
                    textHeaderPath = pc.headerPath
                } else {
                    textPages = (start: textPages!.start, end: max(textPages!.end, pc.page))
                }

                // Append and split if needed
                if textBuffer.isEmpty {
                    textBuffer.append(t)
                } else {
                    textBuffer.append(t)
                }

                // If too big, flush at paragraph boundary
                let approx = textBuffer.reduce(0) { $0 + $1.count + 2 }
                if approx > config.maxChars {
                    flushText(into: &out)
                }
            }
        }

        // Final flush
        flushAll(into: &out)

        // MARK: - Emit digests (optional)
        if config.createSectionDigest {
            // Create one digest chunk per parentKey in stable order (by key)
            let sortedKeys = digestLinesByParent.keys.sorted()
            for key in sortedKeys {
                let lines = digestLinesByParent[key] ?? []
                guard !lines.isEmpty else { continue }

                // We need headerPath + docName from key.
                // key format: "\(docName)::\(path...)"
                let parts = key.components(separatedBy: "::")
                let docName = parts.first ?? "doc"

                // Best-effort headerPath reconstruction from key (after docName::)
                let path = parts.dropFirst().joined(separator: "::")
                let headerPath = path.components(separatedBy: " > ").filter { !$0.isEmpty }

                let digestBody = lines.prefix(config.digestMaxLines).enumerated()
                    .map { "- \($0.element)" }
                    .joined(separator: "\n")

                var body = "Section Digest\n\n" + digestBody
                // page unknown here; use 0
                let prefix = "Context: \(headerPath.joined(separator: " > "))\n\n"
                body = prefix + body

                let idx = out.count
                out.append(
                    EmbedChunk(
                        id: mkId(docName, .digest, idx),
                        docName: docName,
                        pageStart: 0,
                        pageEnd: 0,
                        headerPath: headerPath,
                        parentKey: key,
                        kind: .digest,
                        text: body,
                        meta: [
                            "sourceKind": "digest",
                            "lineCount": "\(min(lines.count, config.digestMaxLines))"
                        ]
                    )
                )
            }
        }

        return out
    }
}

//
//  MarkdownToChunks.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import Foundation

final class MarkdownToChunks {
    static func generateChunks(from markdown: String) -> [ChunkRecord] {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var headingPath = HeadingPath()
        var out = [ChunkRecord]()
        
        var paragraphBuffer = [String]()
        var lastHeadingTitleForTableName: String?
        var currentPage = 1
        
        var insideFigure = false
        
        func flushParagraphBuffer() {
            let text = paragraphBuffer
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter({ !$0.isEmpty })
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else {
                paragraphBuffer.removeAll()
                return
            }

            out.append(ChunkRecord(page: currentPage, headerPath: headingPath.levels, kind: .text, text: text))

            paragraphBuffer.removeAll()
        }
        
        var i = 0
        while i < lines.count {
            let raw = lines[i]
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // figure block
            if line.lowercased().hasPrefix("<figure") {
                flushParagraphBuffer()
                insideFigure = true
                i += 1
                continue
            }
            if insideFigure {
                if line.lowercased().hasPrefix("</figure") { insideFigure = false }
                i += 1
                continue
            }
            
            // page markers
            if let pageNumber = parsePageNumberMarker(line) {
                flushParagraphBuffer()
                currentPage = pageNumber
                i += 1
                continue
            }

            // ignore other comments
            if line.hasPrefix("<!--") {
                i += 1
                continue
            }

            // blank line flush
            if line.isEmpty {
                flushParagraphBuffer()
                i += 1
                continue
            }

            // heading
            if let (level, title) = parseMarkdownHeading(line) {
                flushParagraphBuffer()
                headingPath.set(level: level, title: title)
                lastHeadingTitleForTableName = title
                i += 1
                continue
            }

            // HTML Table
            if line.hasPrefix("<table") {
                flushParagraphBuffer()

                let (tableBlock, nextIndex) = captureBlock(lines, startIndex: i, endTag: "</table")
                let tables = parseHTMLTables(from: tableBlock, defaultTableName: lastHeadingTitleForTableName)

                for table in tables {
                    for row in table.rows {
                        let rowDict = makeRowDict(columns: table.columns, rows: row)
                        out.append(ChunkRecord(page: currentPage, headerPath: headingPath.levels, kind: .tableRow, tableName: table.name, columns: table.columns, rowValues: rowDict))
                    }
                }
                lastHeadingTitleForTableName = nil
                i = nextIndex
                continue
            }

            // Warnings, Error, Notes
            if let notice = classifyNotice(in: line) {
                flushParagraphBuffer()
                out.append(ChunkRecord(page: currentPage, headerPath: headingPath.levels, kind: .notice, notice: notice))
                i += 1
                continue
            }
            
            // normal text
            if line.count <= 2 && (line == "L" || line == "₹") {
                i += 1
                continue
            }

            paragraphBuffer.append(line)
            i += 1
        }
        
        flushParagraphBuffer()
        return out
    }

    private static func parsePageNumberMarker(_ line: String) -> Int? {
        // <!-- PageNumber="Page 3" -->
        let pattern = #"PageNumber\s*=\s*"\s*Page\s*(\d+)\s*""#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }

        let ns = line as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = re.firstMatch(in: line, options: [], range: range) else { return nil}
        return Int(ns.substring(with: match.range(at: 1)))
    }

    private static func parseMarkdownHeading(_ line: String) -> (level: Int, title: String)? {
        guard line.hasPrefix("#") else {
            return nil
        }
        
        let hashes = line.prefix { $0 == "#"}
        let level = hashes.count
        let title = line.dropFirst(level).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return nil
        }
        return (level, title)
    }

    private static func captureBlock(_ lines: [String], startIndex: Int, endTag: String) -> (String, Int) {
        var collected = [String]()
        var i = startIndex
        while i < lines.count {
            collected.append(lines[i])
            if lines[i].lowercased().contains(endTag.lowercased()) {
                i += 1
                break
            }
            i += 1
        }
        return (collected.joined(separator: "\n"), i)
    }

    private static func parseHTMLTables(from block: String, defaultTableName: String?) -> [ParsedTable] {
        var results = [ParsedTable]()

        let tableRegex = try! NSRegularExpression(pattern: "(?is)<table[^>]*>.*?</table>")
        let trRegex = try! NSRegularExpression(pattern: "(?is)<tr[^>]*>.*?</tr>")
        let thRegex = try! NSRegularExpression(pattern: "(?is)<th[^>]*>(.*?)</th>")
        let tdRegex = try! NSRegularExpression(pattern: "(?is)<td[^>]*>(.*?)</td>")

        let nsBlock = block as NSString
        let tableMatches = tableRegex.matches(in: block, range: NSRange(location: 0, length: nsBlock.length))
        
        for tableMatch in tableMatches {
            let tableHTML = nsBlock.substring(with: tableMatch.range)
            let nsTable = tableHTML as NSString
            
            let trMatches = trRegex.matches(in: tableHTML, range: NSRange(location: 0, length: nsTable.length))
            
            var columns = [String]()
            var rows = [[String]]()

            for trMatch in trMatches {
                let trHTML = nsTable.substring(with: trMatch.range)
                let nsTr = trHTML as NSString
                
                let thMatches = thRegex.matches(in: trHTML, range: NSRange(location: 0, length: nsTr.length))
                
                if !thMatches.isEmpty {
                    columns = thMatches.map {  stripHTML(nsTr.substring(with: $0.range(at: 1))) }
                    continue
                }
                
                let tdMatches = tdRegex.matches(in: trHTML, range: NSRange(location: 0, length: nsTr.length))

                if !tdMatches.isEmpty {
                    var row = tdMatches.map { stripHTML(nsTr.substring(with: $0.range(at: 1))) }
                    
                    if  !columns.isEmpty {
                        if row.count < columns.count { row += Array(repeating: "", count: columns.count - row.count) }
                        if row.count > columns.count { row = Array(row.prefix(columns.count)) }
                    }
                    rows.append(row)
                }
            }

            if columns.isEmpty, let first = rows.first {
                columns = first.indices.map {  "Column\($0 + 1)" }
            }

            if !columns.isEmpty || !rows.isEmpty {
                results.append(ParsedTable(name: defaultTableName, columns: columns, rows: rows))
            }
        }
        
        return results
    }

    private struct ParsedTable {
        let name: String?
        let columns: [String]
        let rows: [[String]]
    }

    private static func stripHTML(_ text: String) -> String {
        var s = text
        s = s.replacingOccurrences(of: "&nbsp;", with: " ")
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func makeRowDict(columns: [String], rows: [String]) -> [String: String] {
        let n = min(columns.count, rows.count)
        var dict = [String: String]()
        for i in 0..<n {
            let key = columns[i].isEmpty ? "Column\(i+1)" : columns[i]
            dict[key] = rows[i]
        }
        return dict
    }

    private static func classifyNotice(in line: String) -> Notice? {
        let s = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        let prefixRules: [(pattern: String, severity: NoticeSeverity, title: String?)] = [
            (#"^(Error|ERR)\s*[:\-]\s*(.+)$"#, .error, "Error"),
            (#"^(WARNING|WARN|CAUTION)\s*[:\-]\s*(.+)$"#, .warning, "Warning"),
            (#"^(NOTE|IMPORTANT)\s*[:\-]\s*(.+)$"#, .note, "Note"),
            (#"^(REQUIRED ACTION)\s*[:\-]\s*(.+)$"#, .warning, "Required Action"),
            (#"^(DO NOT)\s*[:\-]\s*(.+)$"#, .warning, "Do Not"),
            (#"^(MUST)\s*[:\-]\s*(.+)$"#, .warning, "Must")
        ]
        for rule in prefixRules {
            if let match = regexFirstMatch(rule.pattern, in: s), match.groups.count >= 2 {
                let message = match.groups.last!.trimmingCharacters(in: .whitespacesAndNewlines)
                return Notice(severity: rule.severity, title: rule.title, message: message)
            }
        }
        return nil
    }
    
    private struct RegexMatch {
        let groups: [String]
    }

    private static func regexFirstMatch(_ pattern: String, in text: String) -> RegexMatch? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let m = re.firstMatch(in: text, range: range) else { return nil }
        var groups: [String] = []
        for i in 0..<m.numberOfRanges {
            let r = m.range(at: i)
            if r.location != NSNotFound {
                groups.append(ns.substring(with: r))
            } else {
                groups.append("")
            }
        }
        return RegexMatch(groups: groups)
    }
}

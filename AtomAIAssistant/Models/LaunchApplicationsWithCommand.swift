//
//  LaunchApplicationsWithCommand.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 27/02/26.
//

import Foundation

struct LaunchCommand {
    let appName: String
    let url: URL
    let message: String

    var updatedMessage: String {
        return "Successfully launched **\(appName.capitalized)** application"
    }
}

enum LaunchApplicationsWithCommand {
    private static var appsToLaunch: [String: (bundleId: String, paramKey: String)] {
        ["safe": ("aa-techops-safe", "AC="), "atom": ("com.aa.techopsmobility.atom", ""), "osp": ("aa-techops-osp", "ospappurl=https://osp.maverick.aa.com/usersafeoiladd/")]
    }
    static func parseLaunchCommand(_ input: String) -> LaunchCommand? {
        // (?i) -> case-insensitive
        // 1st capture: app name (quoted or unquoted)
        // 2nd capture: params rest (optional)
        let pattern = #"(?i)^\s*launch\s+(?:"([^"]+)"|([^\s]+(?:\s+[^\s]+)*?))\s*(?:\s+with\s+(.*))?\s*$"#
        // Explanation:
        // - ^\s*launch\s+      : starts with "launch"
        // - (?:"([^"]+)"|...)  : either "quoted app name" or multi-word unquoted
        // - (?:\s+with\s+(.*))?: optional "with <params...>" capturing the rest
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        
        guard let match = regex.firstMatch(in: input, options: [], range: range) else { return nil }
        
        func group(_ i: Int) -> String? {
            let r = match.range(at: i)
            guard r.location != NSNotFound, let rr = Range(r, in: input) else { return nil }
            return String(input[rr]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Either group 1 (quoted) or 2 (unquoted multi-word)
        let appName = group(1) ?? group(2)
        let params = group(3)
        
        guard let app = appName, !app.isEmpty, let string = appsToLaunch[app.lowercased()], let url = URL(string: "\(string.bundleId)://\((params?.isEmpty == nil) ? "" : (string.paramKey + params!))") else { return nil }
        var messageText = "Launching **\(app.capitalized)**"
        if let params {
            messageText += " with params: **\(params)**"
        }
        return LaunchCommand(appName: app, url: url, message: messageText)
    }
}

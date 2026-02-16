//
//  SourcePanelView.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 16/02/26.
//

import SwiftUI

struct SourcePanelView: View {
    let sources: [SourceReference]
    @Binding var isExpanded: Bool
    var openAction: ((SourceReference) -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Toggle button
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "book.closed.fill" : "book.fill")
                        .imageScale(.medium)
                    Text("\(isExpanded ? "Hide" : "View") Sources (\(sources.count))")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    Capsule().fill(isExpanded ? Color.red.opacity(0.15) : Color.blue.opacity(0.12))
                )
                .foregroundStyle(isExpanded ? .red : .blue)
            }
            .accessibilityLabel(isExpanded ? "Hide sources" : "View sources")
            
            // Content
            if isExpanded {
                Divider()
                    .overlay(Color.secondary.opacity(0.25))
                    .padding(.top, 4)
                
                HStack(spacing: 8) {
                    Image(systemName: "books.vertical")
                        .foregroundStyle(.secondary)
                    Text("SOURCES")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 4)
                
                VStack(spacing: 10) {
                    ForEach(sources, id: \.text) { source in
                        SourceRow(source: source, openAction: openAction)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial) // looks good in both light/dark
        )
    }
}

struct SourceRow: View {
    let source: SourceReference
    var openAction: ((SourceReference) -> Void)? = nil
    
    var body: some View {
        Button {
            openAction?(source)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "books.vertical.fill")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
                    .frame(width: 26)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        PdfChip()
                        Text(source.fileName)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    HStack(spacing: 6) {
                        if let page = source.page {
                            Text("Page \(page)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer(minLength: 8)
                ScorePill(score: source.score)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the source document")
    }
}

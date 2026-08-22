//  GlossaryRootView.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulExtensions
import AwfulTheming
import SwiftUI

/// The SAclopedia landing screen: jump to a random topic, or browse topics by first letter.
public struct GlossaryRootView: View {
    @Environment(\.theme) var theme

    /// Dismisses the whole SAclopedia modal (supplied by the hosting controller). Also injected into
    /// the environment as `\.glossaryExit` so pushed screens can exit without popping the stack.
    private let onExit: () -> Void

    private let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private let letterColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    public init(onExit: @escaping () -> Void) {
        self.onExit = onExit
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    NavigationLink {
                        GlossaryTopicView(source: .random)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "shuffle")
                            Text("Random Topic", bundle: .module)
                                .fontWeight(.medium)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundColor(theme[color: "listSecondaryTextColor"])
                        }
                        .foregroundColor(theme[color: "listTextColor"])
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(theme[color: "sheetBackgroundColor"]!)
                        .cornerRadius(12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("BROWSE BY LETTER", bundle: .module)
                            .font(.footnote)
                            .foregroundColor(theme[color: "listSecondaryTextColor"])

                        LazyVGrid(columns: letterColumns, spacing: 12) {
                            ForEach(letters, id: \.self) { letter in
                                NavigationLink {
                                    GlossaryLetterView(letter: letter)
                                } label: {
                                    Text(String(letter))
                                        .fontWeight(.semibold)
                                        .foregroundColor(theme[color: "tintColor"])
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(theme[color: "sheetBackgroundColor"]!)
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
            .background(theme[color: "backgroundColor"]!)
            .backport.fontDesign(theme.roundedFonts ? .rounded : nil)
            .navigationTitle(Text("SAclopedia", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onExit) { Text("Exit", bundle: .module) }
                        .liquidGlassBarButtonColor(theme[color: "navigationBarTextColor"])
                }
            }
            .background(NavigationConfigurator(theme: theme))
        }
        .navigationViewStyle(.stack)
        .liquidGlassNavigationTint(theme[color: "tintColor"])
        .environment(\.glossaryExit, onExit)
    }
}

// MARK: - Modal exit propagated to pushed screens

private struct GlossaryExitKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// Dismisses the entire SAclopedia modal. Unlike `\.dismiss`, this closes the modal even from a
    /// pushed screen (where `\.dismiss` would only pop the navigation stack).
    var glossaryExit: () -> Void {
        get { self[GlossaryExitKey.self] }
        set { self[GlossaryExitKey.self] = newValue }
    }
}

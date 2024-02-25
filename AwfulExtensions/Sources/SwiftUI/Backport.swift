//  Backport.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI

/// See ``View.backport`` for more info.
public struct Backport<Content> {
    public let content: Content
    public init(_ content: Content) { self.content = content }
}

public extension View {
    /**
     A namespace for polyfills or conditional uses of SwiftUI features that are unavailable on some supported operating systems.

     Applying view modifiers conditionally is annoying:

     ```swift
     var body: some View {
         let coolList = List { … }
         if #available(iOS 16, *) {
             coolList.scrollContentBackground(.hidden)
         } else {
             coolList
         }
     }
     ```

     Instead, consider extending `Backport`:

     ```swift
     extension Backport where Content: View {
         @ViewBuilder func scrollContentBackground(_ visibility: Visibility) -> some View {
             if #available(iOS 16, *) {
                 content.scrollContentBackground(.hidden)
             } else {
                 content
             }
         }
     }
     ```

     And now your use sites are nice and tidy:

     ```swift
     var body: some View {
         List { … }
             .backport.scrollContentBackground(.hidden)
     }
     ```

     Thanks to https://davedelong.com/blog/2021/10/09/simplifying-backwards-compatibility-in-swift/
     */
    var backport: Backport<Self> { Backport(self) }
}

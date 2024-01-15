//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI

// Adds a `bundle` parameter to initializers and methods that take a `LocalizedStringKey`.

public extension Button where Label == Text {
    /// Creates a button that generates its label from a localized string key.
    init(
        _ titleKey: LocalizedStringKey,
        bundle: Bundle,
        action: @escaping () -> Void
    ) {
        self.init(action: action, label: {
            Text(titleKey, bundle: bundle)
        })
    }
}

public extension NavigationLink where Label == Text, Destination: View {
    /// Creates a navigation link that presents a destination view, with a text label that the link generates from a localized string key.
    init(
        _ titleKey: LocalizedStringKey,
        bundle: Bundle,
        @ViewBuilder destination: () -> Destination
    ) {
        self.init(destination: destination, label: {
            Text(titleKey, bundle: bundle)
        })
    }
}

public extension Picker where Content: View, Label == Text, SelectionValue: Hashable {
    /// Creates a picker that generates its label from a localized string key.
    init(
        _ titleKey: LocalizedStringKey,
        bundle: Bundle,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) {
        self.init(selection: selection, content: content, label: {
            Text(titleKey, bundle: bundle)
        })
    }
}

public extension Section where Parent == Text, Content: View, Footer == EmptyView {
    init(
        _ titleKey: LocalizedStringKey,
        bundle: Bundle,
        @ViewBuilder content: () -> Content
    ) {
        self.init(content: content, header: {
            Text(titleKey, bundle: bundle)
        })
    }
}

public extension Stepper where Label == Text {
    /// Creates a stepper configured to increment or decrement a binding to a value using a step value you provide.
    init<V>(
        _ titleKey: LocalizedStringKey,
        bundle: Bundle,
        value: Binding<V>,
        in bounds: ClosedRange<V>,
        step: V.Stride = 1,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) where V : Strideable {
        self.init(value: value, step: step, label: {
            Text(titleKey, bundle: bundle)
        }, onEditingChanged: onEditingChanged)
    }
}

public extension Toggle where Label == Text {
    /// Creates a toggle that generates its label from a localized string key.
    init(
        _ titleKey: LocalizedStringKey,
        bundle: Bundle,
        isOn: Binding<Bool>
    ) {
        self.init(isOn: isOn, label: {
            Text(titleKey, bundle: bundle)
        })
    }
}

public extension View {
    /// Configures the view’s title for purposes of navigation.
    func navigationTitle(_ title: LocalizedStringKey, bundle: Bundle) -> some View {
        navigationTitle(Text(title, bundle: bundle))
    }
}

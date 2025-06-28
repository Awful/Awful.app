import AwfulCore
import SwiftUI

struct MainView: View {
    var body: some View {
        MainViewControllerRepresentable()
            .ignoresSafeArea()
    }
}

struct MainViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let stack = RootViewControllerStack(managedObjectContext: AppDelegate.instance.managedObjectContext)
        // We need to hold on to the stack, otherwise it gets deallocated.
        // A better solution might be a view model or some other lifecycle-managed object.
        // For now, we'll just leak it. This is not ideal.
        // TODO: Fix this leak.
        _ = Unmanaged.passRetained(stack)
        return stack.rootViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    }
} 
import AwfulCore
import Combine
import Foundation
import UIKit

class PostsViewModel: ObservableObject {
    @Published var currentPage: ThreadPage?
    @Published var numberOfPages: Int = 0
    @Published var isTopBarVisible: Bool = false
    
    weak var postsViewController: PostsPageViewController?
    
    private var cancellables = Set<AnyCancellable>()
    
    func setViewController(_ vc: PostsPageViewController) {
        self.postsViewController = vc
        
        // Immediately sync the current state from the view controller
        print("🔵 PostsViewModel.setViewController - initial sync: page=\(String(describing: vc.page)), numberOfPages=\(vc.numberOfPages)")
        self.currentPage = vc.page
        self.numberOfPages = vc.numberOfPages
        
        vc.pageInfoPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pageInfo in
                print("🔵 PostsViewModel received page update - page: \(String(describing: pageInfo.page)), numberOfPages: \(pageInfo.numberOfPages)")
                self?.currentPage = pageInfo.page
                self?.numberOfPages = pageInfo.numberOfPages
            }
            .store(in: &cancellables)

        vc.postsView.didScroll = { [weak self] scrollView in
            self?.scrollViewDidScroll(scrollView)
        }
    }

    private func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let vc = postsViewController, vc.hasFinishedInitialLoad else { return }

        let currentOffset = scrollView.contentOffset.y
        let scrollDiff = currentOffset - vc.previousScrollOffset

        if currentOffset <= 0 {
            if !isTopBarVisible {
                isTopBarVisible = true
            }
            vc.previousScrollOffset = currentOffset
            return
        }

        guard currentOffset < (scrollView.contentSize.height - scrollView.frame.size.height) else {
            vc.previousScrollOffset = currentOffset
            return
        }

        let shouldBeVisible = scrollDiff < -0.5
        if isTopBarVisible != shouldBeVisible {
            isTopBarVisible = shouldBeVisible
        }

        vc.previousScrollOffset = currentOffset
    }
    
    // MARK: - Actions
    
    func triggerSettings() {
        postsViewController?.triggerSettings()
    }
    
    func newReply() {
        postsViewController?.newReply()
    }
    
    func goToPreviousPage() {
        postsViewController?.goToPreviousPage()
    }
    
    func goToNextPage() {
        postsViewController?.goToNextPage()
    }
    
    func loadPage(_ page: ThreadPage) {
        postsViewController?.loadPage(page, updatingCache: true, updatingLastReadPost: true)
    }
    
    func goToLastPost() {
        postsViewController?.goToLastPost()
    }
    
    func triggerBookmark() {
        postsViewController?.triggerBookmark()
    }
    
    func triggerCopyLink() {
        postsViewController?.triggerCopyLink()
    }
    
    func triggerVote() {
        postsViewController?.triggerVote()
    }
    
    func triggerYourPosts() {
        postsViewController?.triggerYourPosts()
    }
    
    func goToParentForum() {
        postsViewController?.goToParentForum()
    }
    
    func scrollToBottom() {
        postsViewController?.scrollToBottom()
    }
} 
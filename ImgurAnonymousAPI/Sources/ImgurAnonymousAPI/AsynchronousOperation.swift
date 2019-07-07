// Public domain. https://github.com/nolanw/ImgurAnonymousAPI

import Foundation

/**
 An abstract class for all operations in this project.
 
 Subclasses must implement `execute()`. Implementations must be ready to run on any thread.
 
 Provides the following features:
 
 * Always runs asynchronously.
 * Has an associated result type.
 * Can conveniently locate dependent operations with a particular result type.
 * Error reporting via convenient `throw`.
 */
internal class AsynchronousOperation<T>: Foundation.Operation {
    private let queue = DispatchQueue(label: "com.nolanw.ImgurAnonymousAPI.async-operation-state")
    private(set) var result: Result<T>?
    private var _state: AsynchronousOperationState = .ready

    @objc private dynamic var state: AsynchronousOperationState {
        return queue.sync { _state }
    }

    final override var isReady: Bool {
        return super.isReady && state == .ready
    }

    final override var isExecuting: Bool {
        return state == .executing
    }

    final override var isFinished: Bool {
        return state == .finished
    }

    final override var isAsynchronous: Bool {
        return true
    }

    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        var keyPaths = super.keyPathsForValuesAffectingValue(forKey: key)
        switch key {
        case #keyPath(isExecuting), #keyPath(isFinished), #keyPath(isReady):
            keyPaths.insert(#keyPath(state))
        default:
            break
        }
        return keyPaths
    }

    override func start() {
        super.start()

        if isCancelled {
            return finish(.failure(CocoaError.error(.userCancelled)))
        }

        update(state: .executing, result: nil)
        do {
            try execute()
        } catch {
            finish(.failure(error))
        }
    }

    /// Subclasses must override this method and call `finish(_:)` when they're done.
    func execute() throws {
        fatalError("\(type(of: self)) must override \(#function)")
    }

    final func finish(_ result: Result<T>) {
        update(state: .finished, result: result)
    }

    private func update(state newState: AsynchronousOperationState, result newResult: Result<T>?) {
        willChangeValue(for: \.state)

        queue.sync {
            guard _state != .finished else { return }

            log(.debug, "operation \(self) is now \(newState) with result \(newResult as Any)")
            _state = newState
            if let newResult = newResult {
                result = newResult
            }
        }

        didChangeValue(for: \.state)
    }
}

extension AsynchronousOperation {
    
    /// Finds the first `AsynchronousOperation` among this operation's dependencies that resulted in a `T`. Throws an error if no such operation is found.
    func firstDependencyValue<T>(ofType resultType: T.Type) throws -> T {
        let candidates = dependencies.lazy
            .compactMap { $0 as? AsynchronousOperation<T> }

        for op in candidates.dropLast() {
            if let value = op.result?.value {
                return value
            }
        }

        guard let lastResult = candidates.last?.result else {
            throw MissingDependency(dependentResultValueType: T.self)
        }

        return try lastResult.unwrap()
    }

    struct MissingDependency: Error {
        let dependentResultValueType: Any.Type
    }
}

@objc private enum AsynchronousOperationState: Int, CustomStringConvertible {
    case ready, executing, finished

    var description: String {
        switch self {
        case .ready: return "ready"
        case .executing: return "executing"
        case .finished: return "finished"
        }
    }
}

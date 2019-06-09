// Public domain. https://github.com/nolanw/ImgurAnonymousAPI

import Foundation

internal struct MissingResponseData: LocalizedError {
    var errorDescription: String? {
        return "Invalid response"
    }

    var failureReason: String? {
        return "No Imgur response data"
    }
}

extension ImgurUploader {
    
    /// An error from the Imgur anonymous upload API.
    public struct APIError: LocalizedError {
        
        /// Sometimes Imgur provides just a plain string explaining the problem, and other times they include more info.
        public let error: Either<String, DetailedAPIError>

        public var errorDescription: String? {
            return "Imgur API Error"
        }

        public var failureReason: String? {
            switch error {
            case .left(let string):
                return string
            case .right(let detail):
                return "\(detail.message) (\(detail.type) code \(detail.code))"
            }
        }
    }

    public struct DetailedAPIError {
        public let code: Int
        public let message: String
        public let type: String
    }
}

extension ImgurUploader.APIError: Decodable {}
extension ImgurUploader.DetailedAPIError: Decodable {}

internal struct APIResponse<T: Decodable>: Decodable {
    let data: ImgurUploader.Either<T, ImgurUploader.APIError>
    let status: Int
    let success: Bool
}

extension ImgurUploader {
    public enum Either<T: Decodable, U: Decodable> {
        case left(T), right(U)
    }
}

extension ImgurUploader.Either: Decodable {
    public init(from decoder: Decoder) throws {
        do {
            self = .left(try T(from: decoder))
        } catch {
            self = .right(try U(from: decoder))
        }
    }
}

/// Runs a URLSessionTask and decodes the response data as JSON.
internal final class FetchURL<T: Decodable>: AsynchronousOperation<T> {
    private var task: URLSessionDataTask?

    init(urlSession: URLSession, request: URLRequest) {
        super.init()

        task = urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                return self.finish(.failure(error))
            }

            guard let data = data else {
                return self.finish(.failure(MissingResponseData()))
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970

            do {
                let response = try decoder.decode(APIResponse<T>.self, from: data)
                switch response.data {
                case .left(let value):
                    self.finish(.success(value))
                case .right(let error):
                    self.finish(.failure(error))
                }
            } catch {
                self.finish(.failure(error))
            }
        }
    }

    override func execute() throws {
        log(.debug, "starting \(self) with url \(task?.originalRequest?.url as Any)")
        task?.resume()
    }

    override func cancel() {
        task?.cancel()
        super.cancel()
    }
}

/// Sends a multipart/form-data upload request, then parses the response's body and headers.
internal final class UploadImageAsFormData: AsynchronousOperation<ImgurUploader.UploadResponse> {
    private let request: URLRequest
    private var task: URLSessionUploadTask?
    private let urlSession: URLSession

    private struct ResponseData: Decodable {
        let id: String
        let link: URL
    }

    init(urlSession: URLSession, request: URLRequest) {
        self.request = request
        self.urlSession = urlSession
    }

    override func execute() throws {
        let formDataFile = try firstDependencyValue(ofType: FormDataFile.self)

        var request = self.request
        request.setValue("multipart/form-data; boundary=\(formDataFile.boundary)", forHTTPHeaderField: "Content-Type")
        if let byteSize = (try? formDataFile.url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
            request.setValue("\(byteSize)", forHTTPHeaderField: "Content-Length")
        }
        task = urlSession.uploadTask(with: request, fromFile: formDataFile.url) { data, response, error in
            if let error = error {
                return self.finish(.failure(error))
            }

            guard let data = data else {
                return self.finish(.failure(MissingResponseData()))
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970

            let responseData: ResponseData
            do {
                let decodedResponse = try decoder.decode(APIResponse<ResponseData>.self, from: data)
                switch decodedResponse.data {
                case .left(let value):
                    responseData = value
                case .right(let error):
                    return self.finish(.failure(error))
                }
            } catch {
                return self.finish(.failure(error))
            }

            let httpResponse = response as? HTTPURLResponse
            
            // The headers dictionary is meant to handle its keys in a case-insensitive manner (much like HTTP), but the Swift bridging breaks this functionality, so we need to handle it ourselves. https://bugs.swift.org/browse/SR-2429
            let headers: [String: Any] = {
                let unknownCaseHeaders = httpResponse?.allHeaderFields as? [String: Any] ?? [:]
                let downcased = unknownCaseHeaders.map { ($0.key.lowercased(), $0.value) }
                
                // Having multiple headers with the same name is allowed by the spec. The documentation for `allHeaderFields` doesn't explain how that situation is conveyed via the returned dictionary, and we're already dealing with a dictionary instance that does something special with its keys, so let's be safe and not assume the dictionary keys are already unique. Instead, we'll arbitrariy coalesce multiple headers into one of the given values.
                return Dictionary(downcased, uniquingKeysWith: { $1 })
            }()
            
            self.finish(.success(.init(
                id: responseData.id,
                link: responseData.link,
                postLimit: ImgurUploader.PostLimit(headers),
                rateLimit: ImgurUploader.RateLimit(headers))))
        }

        log(.debug, "starting \(self) with url \(request.url as Any)")
        task?.resume()
    }

    override func cancel() {
        task?.cancel()
        super.cancel()
    }
}

private extension ImgurUploader.PostLimit {
    init?(_ headers: [String: Any]) {
        guard
            let rawAllocation = headers["x-post-rate-limit-limit"] as? String,
            let allocation = Int(rawAllocation),
            let rawRemaining = headers["x-post-rate-limit-remaining"] as? String,
            let remaining = Int(rawRemaining),
            let rawTimeUntilReset = headers["x-post-rate-limit-reset"] as? String,
            let timeUntilReset = TimeInterval(rawTimeUntilReset)
            else { return nil }
        
        self.allocation = allocation
        self.remaining = remaining
        self.timeUntilReset = timeUntilReset
    }
}

private extension ImgurUploader.RateLimit {
    init?(_ headers: [String: Any]) {
        guard
            let rawClientAllocation = headers["x-ratelimit-clientlimit"] as? String,
            let clientAllocation = Int(rawClientAllocation),
            let rawClientRemaining = headers["x-ratelimit-clientremaining"] as? String,
            let clientRemaining = Int(rawClientRemaining),
            let rawUserAllocation = headers["x-ratelimit-userlimit"] as? String,
            let userAllocation = Int(rawUserAllocation),
            let rawUserRemaining = headers["x-ratelimit-userremaining"] as? String,
            let userRemaining = Int(rawUserRemaining),
            let rawUserResetTimeIntervalSince1970 = headers["x-ratelimit-userreset"] as? String,
            let userResetTimeIntervalSince1970 = TimeInterval(rawUserResetTimeIntervalSince1970)
            else { return nil }
        
        self.clientAllocation = clientAllocation
        self.clientRemaining = clientRemaining
        self.userAllocation = userAllocation
        self.userRemaining = userRemaining
        self.userResetDate = Date(timeIntervalSince1970: userResetTimeIntervalSince1970)
    }
}

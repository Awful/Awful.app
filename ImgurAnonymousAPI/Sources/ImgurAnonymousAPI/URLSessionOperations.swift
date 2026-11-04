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

        /// Whether Imgur turned down the upload because it didn't like the image's format, as opposed to some other problem.
        public var isUnsupportedFileType: Bool {
            switch error {
            case .left(let string):
                return APIError.mentionsFileType(string)
            case .right(let detail):
                // 1003 is Imgur's documented "File type invalid".
                return detail.code == 1003 || APIError.mentionsFileType(detail.message)
            }
        }

        /// Whether Imgur turned down the request because too many have been made recently, as opposed to some other problem.
        public var isRateLimited: Bool {
            switch error {
            case .left(let string):
                return APIError.mentionsRateLimit(string)
            case .right(let detail):
                return detail.code == 429 || APIError.mentionsRateLimit(detail.message)
            }
        }

        private static func mentionsRateLimit(_ message: String) -> Bool {
            let message = message.lowercased()
            return message.contains("too many requests") || message.contains("rate limit")
        }

        private static func mentionsFileType(_ message: String) -> Bool {
            let message = message.lowercased()

            // Being over the file size limit is a different problem with a different answer, and Imgur says "File is over the size limit" which would otherwise look like a complaint about the file itself.
            guard !message.contains("size limit"), !message.contains("too large") else { return false }

            return ["file type", "filetype", "invalid file", "invalid image", "not an image", "image format", "unsupported"]
                .contains { message.contains($0) }
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

/// Imgur sometimes skips the usual `data`/`status`/`success` envelope and instead answers with e.g. `{"errors":[{"code":"429","status":"Too Many Requests","detail":"Too Many Requests"}]}` (seen on rate-limited uploads). Every field is optional so a partial body still tells us something.
private struct ErrorsResponse: Decodable {
    let errors: [Entry]

    struct Entry: Decodable {
        let code: String?
        let status: String?
        let detail: String?
    }
}

/// Decodes an Imgur API response body into either the expected value or an `ImgurUploader.APIError`. Never fails with a bare `DecodingError`, whose "The data couldn't be read because it is missing." says nothing about what Imgur actually said.
private func decodeAPIResponse<T: Decodable>(_ data: Data, response: URLResponse?) -> Swift.Result<T, Error> {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970

    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

    do {
        let decoded = try decoder.decode(APIResponse<T>.self, from: data)
        switch decoded.data {
        case .left(let value):
            return .success(value)
        case .right(let error):
            return .failure(error)
        }
    } catch {
        log(.error, "could not decode Imgur response (HTTP \(statusCode)) as the usual envelope: \(error); body: \(String(decoding: data.prefix(500), as: UTF8.self))")
    }

    if let entry = (try? decoder.decode(ErrorsResponse.self, from: data))?.errors.first {
        return .failure(ImgurUploader.APIError(error: .right(ImgurUploader.DetailedAPIError(
            code: entry.code.flatMap { Int($0) } ?? statusCode,
            message: entry.detail ?? entry.status ?? "Unknown error",
            type: entry.status ?? "HTTP \(statusCode)"))))
    }

    return .failure(ImgurUploader.APIError(error: .left("Unexpected response from Imgur (HTTP \(statusCode))")))
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
internal final class FetchURL<T: Decodable>: AsynchronousOperation<T>, @unchecked Sendable {
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

            switch decodeAPIResponse(data, response: response) as Swift.Result<T, Error> {
            case .success(let value):
                self.finish(.success(value))
            case .failure(let error):
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
internal final class UploadImageAsFormData: AsynchronousOperation<ImgurUploader.UploadResponse>, @unchecked Sendable {
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

            let responseData: ResponseData
            switch decodeAPIResponse(data, response: response) as Swift.Result<ResponseData, Error> {
            case .success(let value):
                responseData = value
            case .failure(let error):
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

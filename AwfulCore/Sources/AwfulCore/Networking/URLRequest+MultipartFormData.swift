//  URLRequest+MultipartFormData.swift
//
//  Copyright 2023 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

extension URLRequest {
    /**
     Configures the URL request for `multipart/form-data`. The request's `httpBody` is set, and a value is set for the HTTP header field `Content-Type`.

     - Parameter parameters: The form data to set.
     - Parameter encoding: The encoding to use for the keys and values.

     - Throws: `EncodingError` if any keys or values in `parameters` are not entirely in `encoding`.

     - Note: The default `httpMethod` is `GET`, and `GET` requests do not typically have a response body. Remember to set the `httpMethod` to e.g. `POST` before sending the request.
     */
    mutating func setMultipartFormData(
        _ parameters: some Sequence<KeyValuePairs<String, String>.Element>,
        encoding: String.Encoding
    ) throws {
        let boundary = String(format: "------------------------%08X%08X", arc4random(), arc4random())

        let contentType: String = try {
            guard let charset = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(encoding.rawValue)) else {
                throw EncodingError("charset")
            }
            return "multipart/form-data; charset=\(charset); boundary=\(boundary)"
        }()
        addValue(contentType, forHTTPHeaderField: "Content-Type")

        httpBody = try {
            var body = Data()

            for (rawName, rawValue) in parameters {
                if !body.isEmpty {
                    guard let newline = "\r\n".data(using: .utf8) else {
                        throw EncodingError("UTF-8 encoding failed")
                    }
                    body.append(newline)
                }

                guard let boundaryData = "--\(boundary)\r\n".data(using: .utf8) else {
                    throw EncodingError("UTF-8 encoding failed")
                }
                body.append(boundaryData)

                guard rawName.canBeConverted(to: encoding),
                      let disposition = "Content-Disposition: form-data; name=\"\(rawName)\"\r\n".data(using: .utf8)
                else { throw EncodingError("name") }
                body.append(disposition)

                guard let headerEnd = "\r\n".data(using: .utf8) else {
                    throw EncodingError("UTF-8 encoding failed")
                }
                body.append(headerEnd)

                guard let value = rawValue.data(using: encoding) else {
                    throw EncodingError("value")
                }

                body.append(value)
            }

            guard let finalBoundary = "\r\n--\(boundary)--\r\n".data(using: .utf8) else {
                throw EncodingError("UTF-8 encoding failed")
            }
            body.append(finalBoundary)

            return body
        }()
    }

    mutating func appendFileData(
        _ data: Data,
        withName name: String,
        filename: String,
        mimeType: String
    ) throws {
        guard var existingBody = httpBody else {
            throw EncodingError("httpBody not set; call setMultipartFormData first")
        }

        guard let contentType = value(forHTTPHeaderField: "Content-Type"),
              contentType.hasPrefix("multipart/form-data"),
              let boundaryRange = contentType.range(of: "boundary="),
              boundaryRange.upperBound < contentType.endIndex else {
            throw EncodingError("Content-Type not set or invalid; call setMultipartFormData first")
        }

        let boundary = String(contentType[boundaryRange.upperBound...]).trimmingCharacters(in: .whitespaces)

        guard let lastBoundary = "--\(boundary)--\r\n".data(using: .utf8) else {
            throw EncodingError("UTF-8 encoding failed")
        }

        if existingBody.suffix(lastBoundary.count) == lastBoundary {
            existingBody.removeLast(lastBoundary.count)
        } else {
            throw EncodingError("httpBody does not end with expected boundary")
        }

        var filePartData = Data()

        guard let newline = "\r\n--\(boundary)\r\n".data(using: .utf8),
              let disposition = "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8),
              let contentTypeData = "Content-Type: \(mimeType)\r\n".data(using: .utf8),
              let headerEnd = "\r\n".data(using: .utf8),
              let finalBoundary = "\r\n--\(boundary)--\r\n".data(using: .utf8) else {
            throw EncodingError("UTF-8 encoding failed")
        }

        filePartData.append(newline)
        filePartData.append(disposition)
        filePartData.append(contentTypeData)
        filePartData.append(headerEnd)
        filePartData.append(data)
        filePartData.append(finalBoundary)

        existingBody.append(filePartData)
        httpBody = existingBody
    }

    struct EncodingError: Error {
        let what: String
        init(_ what: String) {
            self.what = what
        }
    }
}

//
//  Foundation+Promises.swift
//  Awful
//
//  Created by Nolan Waite on 2018-04-21.
//  Copyright © 2018 Awful Contributors. All rights reserved.
//

import Foundation
import PromiseKit

extension URLSession {

    /**
     PromiseKit's convenience method with a couple changes:

     - Can optionally overwrite an existing item at the save location.
     - Does nothing if the server returns an HTTP 304 status.
     
     - Parameter replacingIfNecessary: If `true`, will attempt `FileManager.replaceItemAt(…)` if the attempt to `moveItem(…)` fails due to `fileWriteFileExists`.
     */
    func downloadTask(_: PMKNamespacer, with convertible: URLRequestConvertible, to saveLocation: URL, replacingIfNecessary: Bool) -> Promise<(saveLocation: URL, response: URLResponse)> {
        return Promise { seal in
            downloadTask(with: convertible.pmkRequest, completionHandler: { tempURL, response, error in
                if let error = error {
                    return seal.reject(error)
                }
                guard let response = response, let tempURL = tempURL else {
                    return seal.reject(PMKError.invalidCallingConvention)
                }

                if let http = response as? HTTPURLResponse, http.statusCode == 304 {
                    return seal.fulfill((saveLocation, response))
                }

                do {
                    try FileManager.default.moveItem(at: tempURL, to: saveLocation)
                    return seal.fulfill((saveLocation, response))
                } catch let error as CocoaError where error.code == .fileWriteFileExists && replacingIfNecessary {
                    // will continue below
                } catch {
                    return seal.reject(error)
                }

                do {
                    _ = try FileManager.default.replaceItemAt(saveLocation, withItemAt: tempURL, backupItemName: nil, options: .usingNewMetadataOnly)
                    return seal.fulfill((saveLocation, response))
                } catch {
                    return seal.reject(error)
                }
            }).resume()
        }
    }
}

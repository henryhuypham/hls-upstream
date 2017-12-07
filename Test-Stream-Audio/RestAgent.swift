//
//  RestAgent.swift
//  Test-Stream-Audio
//
//  Created by Henry Pham on 12/7/17.
//  Copyright © 2017 JBach. All rights reserved.
//

import Alamofire
import RxSwift
import SwiftyJSON


typealias SuccessHandler = (JSON) -> Void
typealias FailureHandler = (JSON) -> Void
typealias StringSuccessHandler = (String) -> Void
typealias StringFailureHandler = (String) -> Void

class RestAgent {
    
    private class func handleResponseJson(response: DataResponse<Any>, success: @escaping SuccessHandler, failure: @escaping FailureHandler, reAuthData: (HTTPMethod, String, Parameters?)? = nil) {
        guard let statusCode = response.response?.statusCode else {
            return failure(JSON(response.result.value ?? [:]))
        }
        
        switch response.result {
        case .success:
            switch statusCode {
            case 200..<300:
                success(JSON(response.result.value ?? [:]))
            default:
                failure(JSON(response.result.value ?? [:]))
            }
        case .failure:
            failure(JSON(response.result.value ?? [:]))
        }
    }
    
    class func upload(method: HTTPMethod, url: String, dataName: String, data: Data, fileName: String, mimeType: String, success: @escaping SuccessHandler, failure: @escaping FailureHandler) {
        Alamofire.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(data, withName: dataName, fileName: fileName, mimeType: mimeType)
            },
            usingThreshold: UInt64.init(),
            to: url,
            method: method,
            headers: [:],
            encodingCompletion: { encodingResult in
                switch encodingResult {
                case .success(let upload, _, _):
                    upload.responseJSON { response in
                        handleResponseJson(response: response, success: success, failure: failure)
                    }
                case .failure(let encodingError):
                    print(encodingError)
                }
            }
        )
    }
    
    class func singleUpload(url: String, dataName: String, data: Data, fileName: String, mimeType: String, method: HTTPMethod) -> Single<JSON> {
        return Single<JSON>.create { (single) -> Disposable in
            RestAgent.upload(
                method: method,
                url: url,
                dataName: dataName, data: data, fileName: fileName,
                mimeType: mimeType,
                success: { (result) in
                    single(.success(result))
                },
                failure: { response in
                    single(.error(RxJsonError(json: response)))
                }
            )
            
            return Disposables.create()
        }
    }
}

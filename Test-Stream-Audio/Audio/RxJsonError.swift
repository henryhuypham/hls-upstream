//
//  RxJsonError.swift
//  Test-Stream-Audio
//
//  Created by Henry Pham on 12/7/17.
//  Copyright © 2017 JBach. All rights reserved.
//

import SwiftyJSON

class RxJsonError: Error {
    var jsonData: JSON?
    
    var errorCode: String {
        get {
            if let errCode = jsonData?["errorCode"] {
                return errCode.stringValue
            }
            return ""
        }
    }
    
    init(json: JSON?) {
        jsonData = json
    }
}

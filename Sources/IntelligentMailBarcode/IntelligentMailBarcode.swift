//
//  IntelligentMailBarcode.swift
//  IntelligentMailBarcode
//
//  Created by Paul Herz on 7/29/24.
//

import Foundation

public class IntelligentMailBarcode: RawIntelligentMailBarcode {
    
    enum BarcodeIdentifier: String {
        // Intelligent Mail Barcode Technical Resource Guide, June, 2009, Rev. 4.1: Appendix B, Table B1
        case none = "00",
             carrierRouteEnhancedAndFirm = "10",
             fiveDigitScheme = "20",
             threeDigitScheme = "30",
             areaDistributionCenter = "40",
             mixedAreaDistributionCenterOriginMixedADC = "50"
    }
    
    enum ServiceTypeIdentifier: String {
        // Intelligent Mail Barcode Technical Resource Guide, June, 2009, Rev. 4.1: Appendix B, Table B2
        //
        // uses nonauto/other codes, no full service, no basic option, and no ancillary service endorsements
        // such as destination confirm, manual corrections, origin confirm, traditional ASR/CSR
        case firstClassMail = "700",
             periodicals = "704",
             standardMail = "702",
             boundPrintedMatter = "706",
             businessReplyMail = "708",
             priorityMail = "710",
             priorityMailFlatRate = "712"
    }
    
    // Tracking code elements
    let barcodeID: BarcodeIdentifier // 2 digits, 2nd must be 0–4
    // 3.1. 2-digit field reserved to encode presort identification.
    // should be left as "00" if OEL not printed on the mail piece, unless automation-rate eligible
    // flat mail with OEL, where IMB must contain OEL coding corresponding to correct sortation level
    // of each piece.
    let serviceTypeID: ServiceTypeIdentifier// 3 digits
    
    var payload: String {
        get {
            let payload = trackingCode + routingCode
            assert((20...31).contains(payload.count), "IMB Payload must be 20–31 characters long, was \(payload.count)")
            return payload
        }
    }
    
    init?(barcodeID: BarcodeIdentifier, serviceTypeID: ServiceTypeIdentifier, mailerID: String, serialNumber: String, routingCode: String) {
        
        guard barcodeID.rawValue[barcodeID.rawValue.index(barcodeID.rawValue.startIndex, offsetBy: 1)] == "0" else {
            print("Cannot create IMB: Barcode ID second digit must be '0', given ID of '\(barcodeID.rawValue)' (\(barcodeID.rawValue))")
            return nil
        }
        self.barcodeID = barcodeID
        
        self.serviceTypeID = serviceTypeID
        
        super.init(barcodeID: barcodeID.rawValue, serviceTypeID: serviceTypeID.rawValue, mailerID: mailerID, serialNumber: serialNumber, routingCode: routingCode)
    }
}

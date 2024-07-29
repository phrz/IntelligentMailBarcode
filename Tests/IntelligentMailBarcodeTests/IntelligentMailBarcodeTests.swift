import Foundation
import Testing
@testable import IntelligentMailBarcode

func makeExampleRawIMB(
    barcodeID: String? = nil,
    serviceTypeID: String? = nil,
    mailerID: String? = nil,
    serialNumber: String? = nil,
    routingCode: String? = nil
) -> RawIntelligentMailBarcode? {
    // parameters allow overriding these test values.
    //
    // sample values used throughout examples written in
    // USPS-B-3200 Rev. H, at 5, § 2.2.
    // NOTE: These values are not valid in real-world IMBs.
    // The validation of acceptable real-world values happens
    // in the `IntelligentMailBarcode` class, so we use
    // `RawIntelligentMailBarcode`, which simply checks that values
    // are correct length and all digits, which this test data from
    // the publication is.
    return RawIntelligentMailBarcode(
        barcodeID: barcodeID ?? "01",
        serviceTypeID: serviceTypeID ?? "234",
        mailerID: mailerID ?? "567094",
        serialNumber: serialNumber ?? "987654321",
        routingCode: routingCode ?? "01234567891"
    )
}

@Test func rawIMBInit() {
    let imb = makeExampleRawIMB()
    #expect(imb != nil, "Raw IMB should initialize with valid-length digits.")
}

@Test func rawIMBInitBarcodeIDValidation() {
    #expect(makeExampleRawIMB(barcodeID: "") == nil, "Empty barcodeID should fail.")
    #expect(makeExampleRawIMB(barcodeID: "99") != nil, "Two digit barcodeID should initialize.")
    #expect(makeExampleRawIMB(barcodeID: "1") == nil, "Overly short barcodeID should fail (two digits required).")
    #expect(makeExampleRawIMB(barcodeID: "123") == nil, "Overly long barcodeID should fail (two digits required).")
    #expect(makeExampleRawIMB(barcodeID: "--") == nil, "Non-digit barcodeID should fail.")
    #expect(makeExampleRawIMB(barcodeID: "aa") == nil, "Non-digit barcodeID should fail.")
    #expect(makeExampleRawIMB(barcodeID: "AA") == nil, "Non-digit barcodeID should fail.")
    #expect(makeExampleRawIMB(barcodeID: "  ") == nil, "Non-digit barcodeID should fail.")
    #expect(makeExampleRawIMB(barcodeID: "1 ") == nil, "Non-digit barcodeID should fail.")
}

@Test func rawIMBInitServiceTypeIDValidation() {
    #expect(makeExampleRawIMB(serviceTypeID: "") == nil, "Empty serviceTypeID should fail.")
    #expect(makeExampleRawIMB(serviceTypeID: "999") != nil, "Three digit serviceTypeID should initialize.")
    #expect(makeExampleRawIMB(serviceTypeID: "12") == nil, "Overly short serviceTypeID should fail (three digits required).")
    #expect(makeExampleRawIMB(serviceTypeID: "1234") == nil, "Overly long serviceTypeID should fail (three digits required).")
    #expect(makeExampleRawIMB(serviceTypeID: "---") == nil, "Non-digit barcodeID should fail.")
    #expect(makeExampleRawIMB(serviceTypeID: "aaa") == nil, "Non-digit barcodeID should fail.")
    #expect(makeExampleRawIMB(serviceTypeID: "AAA") == nil, "Non-digit barcodeID should fail.")
    #expect(makeExampleRawIMB(serviceTypeID: "   ") == nil, "Non-digit barcodeID should fail.")
    #expect(makeExampleRawIMB(serviceTypeID: "1  ") == nil, "Non-digit barcodeID should fail.")
}

@Test func rawIMBInitMailIDAndSerialNumberValidation() {
    #expect(
        makeExampleRawIMB(mailerID: "123456", serialNumber: "123456789") != nil,
        "6-digit mailerID, 9-digit serialNumber should initialize."
    )
    #expect(
        makeExampleRawIMB(mailerID: "123456789", serialNumber: "123456") != nil,
        "9-digit mailerID, 6-digit serialNumber should initialize."
    )
    // Make sure the code that tests mailerID and serialNumber length isn't naïve to
    // lengths summing to 15 without the respective lengths being 6 and 9 or vice versa.
    for m in 0...15 {
        let s = 15 - m
        let mailerID = String(repeating: "1", count: m)
        let serialNumber = String(repeating: "1", count: s)
        // skip valid lengths
        if (m == 6 && s == 9) || (m == 9 && s == 6) {
            continue
        }
        #expect(
            makeExampleRawIMB(mailerID: mailerID, serialNumber: serialNumber) == nil,
            "\(m)-digit mailerID, \(s)-digit serialNumber should fail."
        )
    }
    
    // default serial number length in test set is 6,
    // so use 9-digit mailerID
    #expect(makeExampleRawIMB(mailerID: "---------") == nil, "Non-digit mailerID should fail.")
    #expect(makeExampleRawIMB(mailerID: "aaaaaaaaa") == nil, "Non-digit mailerID should fail.")
    #expect(makeExampleRawIMB(mailerID: "AAAAAAAAAAA") == nil, "Non-digit mailerID should fail.")
    #expect(makeExampleRawIMB(mailerID: "         ") == nil, "Non-digit mailerID should fail.")
    #expect(makeExampleRawIMB(mailerID: "1        ") == nil, "Non-digit mailerID should fail.")
    
    #expect(makeExampleRawIMB(serialNumber: "------") == nil, "Non-digit serialNumber should fail.")
    #expect(makeExampleRawIMB(serialNumber: "aaaaaa") == nil, "Non-digit serialNumber should fail.")
    #expect(makeExampleRawIMB(serialNumber: "AAAAAAAA") == nil, "Non-digit serialNumber should fail.")
    #expect(makeExampleRawIMB(serialNumber: "      ") == nil, "Non-digit serialNumber should fail.")
    #expect(makeExampleRawIMB(serialNumber: "1     ") == nil, "Non-digit serialNumber should fail.")
}

@Test func rawIMBInitRoutingCodeValidation() {
    for i in [0, 5, 9, 11] {
        // valid lengths
        let code = String(repeating: "1", count: i)
        #expect(
            makeExampleRawIMB(routingCode: code) != nil,
            "\(i)-digit routingCode should initialize."
        )
    }
    
    for i in [1, 2, 3, 4, 6, 7, 8, 10, 12] {
        // invalid lengths
        let code = String(repeating: "1", count: i)
        #expect(
            makeExampleRawIMB(routingCode: code) == nil,
            "\(i)-digit routingCode should fail."
        )
    }
    
    #expect(makeExampleRawIMB(routingCode: "-----") == nil, "Non-digit routingCode should fail.")
    #expect(makeExampleRawIMB(routingCode: "aaaaa") == nil, "Non-digit routingCode should fail.")
    #expect(makeExampleRawIMB(routingCode: "AAAAAAA") == nil, "Non-digit routingCode should fail.")
    #expect(makeExampleRawIMB(routingCode: "     ") == nil, "Non-digit routingCode should fail.")
    #expect(makeExampleRawIMB(routingCode: "1    ") == nil, "Non-digit routingCode should fail.")
}

@Test func rawIMBTrackingCode() {
    let imb = makeExampleRawIMB()
    #expect(imb?.trackingCode.count == 20)
}

@Test func makeRawIMBStepwise() {
    // Test each step of the IMB and the expected values
    // using the example data in USPS documentation
    let imb = makeExampleRawIMB()!
    
    let encodedStep1 = imb.encodedAsBinaryUnchecked
    #expect(encodedStep1 == Data([
        0x01,0x69,0x07,0xB2,0xA2,0x4A,0xBC,0x16,0xA2,0xE5,
        0xC0,0x04,0xB1
    ]))

    // Step 2: CRC to generate FCS
    let step2FCS = RawIntelligentMailBarcode.generateCRC11ForRightmost102Bits(encodedStep1)
    #expect(step2FCS == 0x751)

    // Step 3: Binary Data to Codewords
    let step3Codewords = RawIntelligentMailBarcode.generateCodewords(from: encodedStep1)
    #expect(step3Codewords! == [14, 787, 607, 1022, 861, 19, 816, 1294, 35, 301])

    // Step 4: Inserting Additional Information to Codewords
    let step4AdditionalInformation = RawIntelligentMailBarcode.insert(fcs: step2FCS, into: step3Codewords!)
    #expect(step4AdditionalInformation == [673, 787, 607, 1022, 861, 19, 816, 1294, 35, 602])

    // Step 5: Conversion from Codewords to Characters
    let step5aCharacters = IntelligentMailBarcode.characters(from: step4AdditionalInformation)
    #expect(step5aCharacters == [0x1234, 0x085C, 0x08E4, 0x0B06, 0x1922, 0x1740, 0x0839, 0x1200, 0x0DC0, 0x04D4])

    let step5bCharacters = IntelligentMailBarcode.apply(fcs: step2FCS, to: step5aCharacters ?? [])
    #expect(step5bCharacters == [0x0DCB, 0x085C, 0x08E4, 0x0B06, 0x06DD, 0x1740, 0x17C6, 0x1200, 0x123F, 0x1B2B])

    // Step 6: Conversion from Characters to the Intelligent Mail Barcode
    let barcodeText = IntelligentMailBarcode.makeIMB(from: step5bCharacters)
    #expect(barcodeText == "AADTFFDFTDADTAADAATFDTDDAAADDTDTTDAFADADDDTFFFDDTTTADFAAADFTDAADA")
}

@Test func rawIMBGenerate() {
    // example data in USPS documentation
    let imb = makeExampleRawIMB()!
    
    let barcodeText = imb.generate()
    #expect(barcodeText == "AADTFFDFTDADTAADAATFDTDDAAADDTDTTDAFADADDDTFFFDDTTTADFAAADFTDAADA")
}

@Test func rawIMBPrintCustomStringConvertible() {
    // example data in USPS documentation
    let imb = makeExampleRawIMB()!
    
    // used when print(imb) called
    let barcodeText = imb.description
    #expect(barcodeText == "AADTFFDFTDADTAADAATFDTDDAAADDTDTTDAFADADDDTFFFDDTTTADFAAADFTDAADA")
}

//
//  RawIntelligentMailBarcode.swift
//  IntelligentMailBarcode
//
//  Created by Paul Herz on 7/29/24.
//

import Foundation

// https://developer.apple.com/documentation/swift/uint128
// Mac OS 15.0, iOS 18.0 add UInt128, but it's too early to count on it,
// and it's too hard to do a conditional import, therefore:
import struct UInt128.UInt128

open class RawIntelligentMailBarcode: CustomStringConvertible {
    public typealias IMBIntegerType = UInt128
    public typealias IMBWordIntegerType = UInt16
    
    public static let bytesPerCharacter = 13
    public static let barsPerIMB = 65
    // From spec.
    // Where `n` is position in array,
    // Bar `n` is calculated based on "i j k l"
    // `i` is a character, `j` is a bit -> if 1, descender present
    // `k` is a character, `l` is a bit -> if 1, ascender present
    public static let table22_barToCharacterTable = [
        "H 2 E 3", "B 10 A 0", "J 12 C 8", "F 5 G 11", "I 9 D 1",
        "A 1 F 12", "C 5 B 8", "E 4 J 11", "G 3 I 10", "D 9 H 6",
        "F 11 B 4", "I 5 C 12", "J 10 A 2", "H 1 G 7", "D 6 E 9",
        "A 3 I 6", "G 4 C 7", "B 1 J 9", "H 10 F 2", "E 0 D 8",
        "G 2 A 4", "I 11 B 0", "J 8 D 12", "C 6 H 7", "F 1 E 10",
        "B 12 G 9", "H 3 I 0", "F 8 J 7", "E 6 C 10", "D 4 A 5",
        "I 4 F 7", "H 11 B 9", "G 0 J 6", "A 6 E 8", "C 1 D 2",
        "F 9 I 12", "E 11 G 1", "J 5 H 4", "D 3 B 2", "A 7 C 0",
        "B 3 E 1", "G 10 D 5", "I 7 J 4", "C 11 F 6", "A 8 H 12",
        "E 2 I 1", "F 10 D 0", "J 3 A 9", "G 5 C 4", "H 8 B 7",
        "F 0 E 5", "C 3 A 10", "G 12 J 2", "D 11 B 6", "I 8 H 9",
        "F 4 A 11", "B 5 C 2", "J 1 E 12", "I 3 G 6", "H 0 D 7",
        "E 7 H 5", "A 12 B 11", "C 9 J 0", "G 8 F 3", "D 10 I 2",
    ]
    
    static let table19_5of13: [IMBWordIntegerType] = RawIntelligentMailBarcode.makeNof13Table(n: 5, length: 1286+1)!
    static let table20_2of13: [IMBWordIntegerType] = RawIntelligentMailBarcode.makeNof13Table(n: 2, length: 77+1)!
    
    // Tracking code elements
    public let _barcodeID: String // 2 digits, 2nd must be 0–4
    // 3.1. 2-digit field reserved to encode presort identification.
    // should be left as "00" if OEL not printed on the mail piece, unless automation-rate eligible
    // flat mail with OEL, where IMB must contain OEL coding corresponding to correct sortation level
    // of each piece.
    public let _serviceTypeID: String // 3 digits
    public let mailerID: String       // 6 or 9 digits (6 = large mailer, 9 = small mailer)
    public let serialNumber: String   // 9 (when mailerID is 6 digits), or 6 (when mailerID is 9 digits)
    
    // Routing code
    public let routingCode: String // delivery point ZIP code: 0, 5, 9 or 11 digits
    
    public var description: String {
        return generate() ?? ""
    }

    public init?(barcodeID: String, serviceTypeID: String, mailerID: String, serialNumber: String, routingCode: String) {
        // Barcode ID r/\d0/
        guard barcodeID.count == 2 else {
            print("Cannot create IMB: Barcode ID must be 2 characters, given was \(barcodeID.count) ('\(barcodeID)')")
            return nil
        }
        guard CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: barcodeID)) else {
            print("Cannot create IMB: Barcode ID must be all digits, given '\(barcodeID)'")
            return nil
        }
        self._barcodeID = barcodeID
        
        // Service Type ID (enum) r/\d{3}/
        // TODO: validate that Service Type ID is in the spec
        guard serviceTypeID.count == 3 else {
            print("Cannot create IMB: Service Type ID must be 3 characters, given was \(serviceTypeID.count) ('\(serviceTypeID)')")
            return nil
        }
        guard CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: serviceTypeID)) else {
            print("Cannot create IMB: Service Type ID must be all digits, given '\(serviceTypeID)'")
            return nil
        }
        self._serviceTypeID = serviceTypeID
        
        // Mailer ID r/(?:\d{6}|\d{9})/
        guard [6, 9].contains(mailerID.count) else {
            print("Cannot create IMB: Mailer ID must be 6 or 9 characters, given was \(mailerID.count) ('\(mailerID)')")
            return nil
        }
        guard CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: mailerID)) else {
            print("Cannot create IMB: Mailer ID must be all digits, given '\(mailerID)'")
            return nil
        }
        self.mailerID = mailerID
        
        // Serial Number & Mailer ID r/\d{15}/
        guard mailerID.count + serialNumber.count == 15 else {
            print("Cannot create IMB: Serial Number must be 6 characters if Mailer ID is 9, or vice versa, given was \(serialNumber.count) (\(serialNumber)) with Mailer ID length \(mailerID.count)")
            return nil
        }
        guard CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: serialNumber)) else {
            print("Cannot create IMB: Serial Number must be all digits, given '\(serialNumber)'")
            return nil
        }
        self.serialNumber = serialNumber
        
        // Routing Code r/(?:\d{5}|\d{9}|\d{11})?/
        guard [0, 5, 9, 11].contains(routingCode.count) else {
            print("Cannot create IMB: Routing Code must be 0, 5 (ZIP5), 9 (ZIP5+4), or 11 (Delivery Point) digits long. Got \(routingCode.count) ('\(routingCode)')")
            return nil
        }
        guard CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: routingCode)) else {
            print("Cannot create IMB: Routing Code must be all digits, given '\(routingCode)'")
            return nil
        }
        self.routingCode = routingCode
    }
    
    public var trackingCode: String {
        // 20 digit tracking code
        // Tracking = Barcode + Service + MID + Serial
        let code = _barcodeID + _serviceTypeID + mailerID + serialNumber
//        assert(code.count == 20, "IMB Tracking Code must be 20 characters long, was \(code.count)")
        return code
    }
    
    public var encodedAsBinaryUnchecked: Data {
        // USPS-B-3200
        // Intelligent Mail Barcode 4-State
        
        // 2.2.1 Step 1 — Conversion of Data Fields into Binary Data
        //
        // 2.2.1.1 Conversion of Routing Code
        //
        // The routing code shall be converted from a 0-, 5-, 9-, or 11-digit string to an integer value in the range of
        // 0 to 101,000,100,000 by applying the following algorithm, as shown in Table 4 below.
        //
        // TABLE 4
        //
        // Routing Code Length      Value
        // 0 digits long            Value = 0
        // 5 digits long            Value = (5-digit string converted to integer) + 1
        // 9 digits long            Value = (9-digit string converted to integer) + 100000 + 1
        // 11 digits long           Value = (11-digit string converted to integer) + 1000000000 + 100000 + 1
        
        let integerRoutingCode: IMBIntegerType = switch routingCode.count {
        case 0:
            IMBIntegerType(0)
        case 5: // ZIP5
            IMBIntegerType(routingCode)! + 1
        case 9: // ZIP5+4
            IMBIntegerType(routingCode)! + 100000 + 1
        case 11: // ZIP5+4+Delivery Point
            IMBIntegerType(routingCode)! + 1000000000 + 100000 + 1
        default:
            fatalError("Length \(routingCode.count) Routing Code unexpected ('\(routingCode)')")
        }
                
        // The routing code shall then be converted into binary data. The binary data shall hold 104 bits maximum
        // (or 13 bytes). The routing code binary data, which shall fit within 37 bits, shall be put into the rightmost 37
        // bits of the binary data.
        var dataInt = integerRoutingCode
        
        // 2.2.1.2 Conversion of Tracking Code
        // The tracking code shall be converted into binary data using the following steps:
        //
        // A. Multiply the Binary Data field by 10 decimal, and then add the first Tracking Code digit (left
        // digit of Barcode Identifier).
        let digits = self.trackingCode.map { IMBIntegerType(String($0))! }
        dataInt *= 10
        dataInt += digits[0]
                
        // B. Multiply the Binary Data field by 5 decimal, and then add the second Tracking Code digit
        // (right digit of Barcode Identifier, which is limited to value of 0 to 4).
        dataInt *= 5
        dataInt += digits[1]
        
        // C. For each of the remaining 18 Tracking Code digits (from left to right, each of which can range
        // from 0 to 9), multiply the Binary Data Field by 10 decimal, then add the Tracking Code
        for digit in digits[2...] {
            dataInt *= 10
            dataInt += digit
        }
        
//        var int = dataInt.bigEndian
//        let MAX_64: UInt128 = 2 << 32 - 1
//        let HI = int >> 64
//        let LO = int & MAX_64
//        print("HI \(String(HI, radix: 16, uppercase: true)) LO \(String(LO, radix: 16, uppercase: true))")
        // this Data cast has inconsistent results between the UInt128 package and the new builtin,
        // probably due to bad endianness handling in the former?
//        let data: Data = Data(bytes: &int, count: MemoryLayout<IMBIntegerType>.size)
        return Data((4...16).map { (i: Int) -> UInt8 in
            UInt8((dataInt.littleEndian >> ((16-i) * 8)) & 0xFF)
        })
        // At the completion of this step, the binary data (13 bytes long) shall have the
        // rightmost 102 bits filled with data from the routing code and tracking code.
//        let dataLast13Bytes = data.suffix(Self.bytesPerCharacter)
//        return data
    }
    
    public static func generateCRC11ForRightmost102Bits(_ byteArrayIn: Data) -> Int {
        // (IMBWordIntegerType)
        // USPS-B-3200
        // Intelligent Mail Barcode 4-State
        
        // 2.2.2 Step 2 — Generation of 11-Bit CRC on Binary Data
        /* An 11-bit CRC Frame Check Sequence (FCS) value shall be generated by applying the Generator Polynomial (0xF35) to the rightmost 102 bits of the Binary Data. The leftmost 2 bits of the leftmost byte shall be excluded from the Conversion of Routing Code (CRC) calculation. This 11-bit FCS value shall be set aside for later use. The code in Appendix C shall be used to generate the CRC. See Table 6 for an example of the value CRC returned. */
        
        let byteArray = Data(byteArrayIn)
        
        // translated from C code in Appendix D: Example Code
        let generatorPolynomial: IMBWordIntegerType = 0x0F35
        var frameCheckSequence: IMBWordIntegerType = 0x07FF
        var data: IMBWordIntegerType = IMBWordIntegerType(byteArray[0]) << 5
        
        for byteIndex in 0..<Self.bytesPerCharacter {
            var startBit = 0
            
            if byteIndex == 0 {
                // per spec exclude the two most significant bits of the most significant byte from CRC
                startBit = 2
            } else {
                data = IMBWordIntegerType(byteArray[byteIndex]) << 3
            }
            
            for _ in startBit..<8 {
                if ((frameCheckSequence ^ data) & 0x0400) != 0 {
                    frameCheckSequence = (frameCheckSequence << 1) ^ generatorPolynomial
                }
                else {
                    frameCheckSequence = frameCheckSequence << 1
                }
                frameCheckSequence &= 0x7FF
                data <<= 1
            }
            
        }
        return Int(frameCheckSequence)
    }
    
    public static func generateCodewords(from data: Data) -> [IMBWordIntegerType]? {
        // USPS-B-3200
        // Intelligent Mail Barcode 4-State
        
        // exclude most significant 2 bits of 104 bit (13 byte) payload (leaving 102 bits)
        var data = data
        data[data.startIndex] &= 0x7F
        
        var dataInt: IMBIntegerType = {
            var d: IMBIntegerType = 0
            for (i, byte) in data.enumerated() {
                d |= IMBIntegerType(byte) << (8 * (data.count - i - 1))
            }
            return d
        }()
        
        // 2.2.2 Step 2 — Generation of 11-Bit CRC on Binary Data
        /* The Binary Data shall then be converted to several bases. The rightmost Codeword (J) shall be base 636. The leftmost Codeword (A) shall use 659 values (0–658). Codewords B through I shall be base 1365. Ten Codewords shall be generated, with the first (or leftmost) considered the most significant. The leftmost 2 bits of the 104-bit binary data shall be excluded from this conversion. The Codewords shall be labeled (from leftmost to rightmost) A through J. The conversion process consists of the following steps per Table 7: */
        /*
         Table 7
         Step    Action                     Quotient                         Remainder
         1    Divide Binary Data by 636     quotient replaces Binary Data    remainder is Codeword J
         2    Divide Binary Data by 1365    quotient replaces Binary Data    remainder is Codeword I
         3    Divide Binary Data by 1365    quotient replaces Binary Data    remainder is Codeword H
         4    Divide Binary Data by 1365    quotient replaces Binary Data    remainder is Codeword G
         5    Divide Binary Data by 1365    quotient replaces Binary Data    remainder is Codeword F
         6    Divide Binary Data by 1365    quotient replaces Binary Data    remainder is Codeword E
         7    Divide Binary Data by 1365    quotient replaces Binary Data    remainder is Codeword D
         8    Divide Binary Data by 1365    quotient replaces Binary Data    remainder is Codeword C
         9    Divide Binary Data by 1365    quotient replaces Binary Data    remainder is Codeword B
         10   Binary Data                   (should be value between 0 and 658)        is Codeword A
         */
        
        // codewords J...A
        var codewords = [IMBWordIntegerType]()
        
        for step in 1...9 {
            let divisor: IMBIntegerType = step == 1 ? 636 : 1365
            let (quotient, remainder) = dataInt.quotientAndRemainder(dividingBy: divisor)
            // quotient replaces binary data steps 1...9
            dataInt = quotient
            // remainder is next codeword
            codewords.append(IMBWordIntegerType(remainder))
        }
        // step 10
//        assert(0 <= dataInt && dataInt <= 658, "Cannot generate IMB: Codeword A must be 0...658, was \(dataInt)")
        guard (0...658).contains(dataInt) else {
            print("Cannot generate IMB: Codeword A must be 0...658, was \(dataInt)")
            return nil
        }
        codewords.append(IMBWordIntegerType(dataInt))
        
        // A...J
        codewords.reverse()
        
        return codewords
    }

    public static func insert(fcs: Int, into codewords: [IMBWordIntegerType]) -> [IMBWordIntegerType] {
        // USPS-B-3200
        // Intelligent Mail Barcode 4-State
        
        var codewords = codewords
        
        // 2.2.4 Step 4 — Inserting Additional Information into Codewords
        /* Codeword J shall be modified to contain orientation information. Codeword A shall be modified to contain the most significant FCS bit (bit 10). */
        // A. Codeword J shall be converted from 0 through 635 to even numbers in the range 0 through 1270 (as shown in Table 9 below), such that:
        codewords[9] *= 2
        
        // B. If the most significant bit of the FCS 11-bit value is a binary 1, Codeword A shall be incremented by 659. See Table 10 below for an example.
        let fcsBit10 = (fcs >> 10) & 1
        if(fcsBit10 == 1) {
            codewords[0] += 659
        }
        
        return codewords
    }
    
    private static func reverseIMBWordInt(_ input: IMBWordIntegerType) -> IMBWordIntegerType {
        // Adapted from example code
        // USPS-B-3200
        // Intelligent Mail Barcode 4-State
        // Appendix D, 9.2: Example for Generating Codeword to Character Table
        // Table 18: Example for Generating Codeword to Character Table
        //
        // extern unsigned short ReverseUnsignedShort( unsigned short Input )
        var input = input
        var reversed: IMBWordIntegerType = 0
        for _ in 0..<16 {
            reversed <<= 1
            reversed |= input & 1
            input >>= 1
        }
        return reversed
    }
    
    internal static func makeNof13Table(n: Int, length: Int) -> [IMBWordIntegerType]? {
        // MARK: I have no idea what this does. Just following e.g. code
        
        // Adapted from example code
        // USPS-B-3200
        // Intelligent Mail Barcode 4-State
        // Appendix D, 9.2: Example for Generating Codeword to Character Table
        // Table 18: Example for Generating Codeword to Character Table
        //
        // extern BOOLEAN InitializeNof13Table( int *TableNof13 ,
        //                                      int N ,
        //                                      int TableLength )
        // count up to 2^13-1 and find all those values that have N bits on
        var table = Array.init(repeating: IMBWordIntegerType(0), count: length)
        var lutLowerIndex: Int = 0
        var lutUpperIndex: Int = length - 1
        
        for count in IMBWordIntegerType(0)..<IMBWordIntegerType(8192) {
            var bitCount: IMBWordIntegerType = 0
            for bitIndex in IMBWordIntegerType(0)..<IMBWordIntegerType(13) {
                bitCount += ((count & (1 << bitIndex)) != 0) ? 1 : 0
            }
            // if we don't have the right number of bits on, go on to the next value
            if bitCount != n {
                continue
            }
            // if the reverse is less than count, we have already visited this pair before
            let reverse = reverseIMBWordInt(count) >> 3
            if reverse < count {
                continue
            }
            // if count is symmetric, place it at the first free slot from the end of the list. Otherwise, place it at the first free slot from the beginning of the list AND place Reverse at the next free slot from the beginning of the list.
            if count == reverse {
                table[lutUpperIndex] = count
                lutUpperIndex -= 1
            } else {
                table[lutLowerIndex] = count
                lutLowerIndex += 1
                table[lutLowerIndex] = reverse
                lutLowerIndex += 1
            }
        }
        // make sure the lower and upper parts of the table meet properly
        if lutLowerIndex != lutUpperIndex+1 {
            return nil
        }
        
        // MARK: Test Code
//        for index in 0..<length {
//            print("Index \(index)\t\tValue \(table[index])")
//        }
        
        return table
    }
    
    /*private static func cachedMakeNof13Table(n: Int, length: Int) -> [IMBWordIntegerType]? {
        let docDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = "table_\(n)of13_\(length).json"
        let url = docDirectory.appendingPathComponent(filename)
        
        let cacheResult: [IMBWordIntegerType]? = {
            do {
                if !(FileManager.default.fileExists(atPath: url.path)) {
                    return nil
                }
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                let ints = try JSONDecoder().decode([IMBWordIntegerType].self, from: data)
                return ints
            } catch {
                print("Error loading JSON: \(error)")
                return nil
            }
        }()
        
        if let cacheResult = cacheResult {
            print("Cache hit n=\(n) length=\(length)")
            return cacheResult
        }
        
        // fall back to calculation
        print("Cache miss n=\(n) length=\(length)")
        let result = makeNof13Table(n: n, length: length)
        // save to cache
        do {
            let data = try JSONEncoder().encode(result)
            try data.write(to: url, options: .atomicWrite)
        } catch {
            print("Error saving cached result to JSON: \(error)")
        }
        
        return result
    }*/
    
    public static func characters(from codewords: [IMBWordIntegerType]) -> [IMBWordIntegerType] {
        // USPS-B-3200
        // Intelligent Mail Barcode 4-State
        // 2.2.5 Step 5 — Conversion from Codewords to Characters
        // (Step 5a)
        /* The Codewords shall be converted to the Characters in two steps. The Characters shall be labeled from A to J in accordance with the Codeword from which they were generated. The bits in each Character shall be labeled from 12 (leftmost and most significant) to 0 (rightmost and least significant). The code in Appendix D can be used to generate the Codewords to Characters lookup tables.
         */
//         A. Each Codeword shall be converted from a decimal value to a 13-bit Character, ranging from 0 to 1364; except Codeword A, which ranges from 0 to 1317; and Codeword J, which ranges from 0 to 1270 even.
        let characters = codewords.map { codeword in
            // 1. If the Codeword has a value from 0 to 1286, the Character shall be determined by indexing into Table 19, in ,Appendix E - Tables for Converting Characters using the Codeword.
            if (0...1286).contains(codeword) {
                return table19_5of13[Int(codeword)]
            }
            // 2. If the Codeword has a value from 1287 to 1364, the Character shall be determined by indexing into, Table 20 in Appendix E - Tables for Converting Characters, using the Codeword reduced by 1287 (result from 0 to 77).
            else if (1287...1364).contains(codeword) {
                return table20_2of13[Int(codeword - 1287)]
            }
            else {
                print("IntelligentMailBarcode.characters(from:) - Unexpected OOB codeword value \(codeword)")
                return 0
            }
            // 3. An example of looking up Codewords to Characters using Table 19 and Table 20 in Appendix E - Tables for Converting Characters is shown in Figure 3.
        }
        return characters
    }
    
    public static func apply(fcs: Int, to characters: [IMBWordIntegerType]) -> [IMBWordIntegerType] {
        // 2.2.5 Step 5 — Conversion from Codewords to Characters
        // (Step 5b)
        /*
         B. Each Character shall be paired to one of the unused remaining 10 bits of the 11-bit FCS value. If the bit’s value is 1, the Character shall be bitwise negated; if the bit’s value is 0, the Character shall be left as is. Mapping of FCS bits to Characters is listed in Table 21 in Appendix E - Tables for Converting Characters. See Figure 4 below for an example.
         */
        let characters = characters.enumerated().map { (i,character) in
            (fcs & (1<<i)) != 0 ? character ^ 0x1FFF : character
        }
        return characters
    }
    
    public static func makeIMB(from characters: [IMBWordIntegerType]) -> String {
        // 2.2.6 Step 6 — Conversion from Characters to the Intelligent Mail Barcode
        /* At this point there are 10 (A–J) Characters of 13 (12–0) bits each, for a total of 130 bits. Each bit shall correspond to an extender (either an ascender or a descender) in a 65-bar Intelligent Mail barcode. A bit value of 0 shall represent the absence of the extender, and a bit value of 1 shall represent the presence of the extender. The bars shall be numbered from 1 (leftmost) to 65 (rightmost). Table 22 in Appendix E - Tables for Converting Characters maps bars to characters. At this point the barcode shall consist of 65 bars, each of which is in one of four possible states (see Figure 5 below). */
//        Self.table22_barToCharacterTable.map { entry in
//
//        }
        
        var bars = Array(repeating: " ", count: barsPerIMB)

        RawIntelligentMailBarcode.table22_barToCharacterTable.enumerated().forEach { (barIndex, row) in
//            print("Bar \(barIndex): ", row)
            let values = row.split(separator: " ")
            // letter -> 0-index
            // "A" -> 0; "B" -> 1; ...
            let ord = { (s: (any StringProtocol)) -> Int in Int(s.utf8.first! - "A".utf8.first!) }

            let (descenderCharIndex, descenderBitIndex, ascenderCharIndex, ascenderBitIndex)
                = (ord(values[0]), Int(values[1])!, ord(values[2]), Int(values[3])!)

//            print("Bar \(barIndex): Descender if char \(descenderCharIndex) bit \(descenderBitIndex) is 1, ascender if char \(ascenderCharIndex) bit \(ascenderBitIndex) is 1")
            let descenderChar = characters[descenderCharIndex]
            let ascenderChar = characters[ascenderCharIndex]
            
            /*
             Bars are constructed left to right, selecting bits from characters. The ****LEAST**** significant bit is bit 0. Using Table IV in Appendix D, the left 5 bars are constructed using the bit specified in the table.
             */
            let descenderBit = descenderChar >> descenderBitIndex & 1
            let ascenderBit = ascenderChar >> ascenderBitIndex & 1

//            print("\t- DSC: char \(descenderCharIndex): \(String(descenderChar, radix: 2)), bit \(descenderBitIndex): \(descenderBit)")
//            print("\t- ASC: char \(ascenderCharIndex): \(String(ascenderChar, radix: 2)), bit \(ascenderBitIndex): \(ascenderBit)")
            
            /*
             1 represents the presence of the extender. 0 represents its absence.

             A represents an ascender is present. D indicates a descender is present. T indicates neither is present, and F indicates both are present.
             */
            let barLetter = ["T","D","A","F"][Int(ascenderBit << 1 | descenderBit)]
//            print(barLetter, "\n")
            bars[barIndex] = barLetter
        }
        return bars.joined()
    }
    
    public func generate() -> String? {
        let encodedStep1 = self.encodedAsBinaryUnchecked

        // Step 2: CRC to generate FCS
        let step2FCS = Self.generateCRC11ForRightmost102Bits(encodedStep1)

        // Step 3: Binary Data to Codewords
        guard let step3Codewords = Self.generateCodewords(from: encodedStep1) else {
            print("Cannot create IMB: Step 3 generateCodewords failure.")
            return nil
        }

        // Step 4: Inserting Additional Information to Codewords
        let step4AdditionalInformation = Self.insert(fcs: step2FCS, into: step3Codewords)

        // Step 5: Conversion from Codewords to Characters
        let step5aCharacters = Self.characters(from: step4AdditionalInformation)

        let step5bCharacters = Self.apply(fcs: step2FCS, to: step5aCharacters)

        // Step 6: Conversion from Characters to the Intelligent Mail Barcode
        let barcodeText = Self.makeIMB(from: step5bCharacters)
        
        return barcodeText
    }
}

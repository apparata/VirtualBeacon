//
// MIT License
//
// Copyright (C) 2016 by Apparata AB
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import UIKit
import CoreLocation
import CoreBluetooth

/// Delegate of the VirtualBeacon class.
public protocol VirtualBeaconDelegate : class {
    func virtualBeaconBluetoothPoweredOn(_ virtualVeacon: VirtualBeacon)
    func virtualBeaconDidStartAdvertising(_ virtualBeacon: VirtualBeacon)
    func virtualBeaconDidFailToStartAdvertising(_ virtualBeacon: VirtualBeacon, error: NSError)
    func virtualBeaconDidFailToStartAdvertisingDueToBluetoothNotEnabled(_ virtualBeacon: VirtualBeacon)
    func virtualBeaconDidStopAdvertising(_ virtualBeacon: VirtualBeacon)
}

#if os(tvOS)
    private struct BeaconRegion {
        let proximityUUID: NSUUID
        let major: UInt16
        let minor: UInt16
        let identifier: String
        
        init(proximityUUID: NSUUID, major: UInt16, minor: UInt16, identifier: String) {
            self.proximityUUID = proximityUUID
            self.major = major
            self.minor = minor
            self.identifier = identifier
        }
        
        func peripheralData(withMeasuredPower power: Int8?) -> [String: AnyObject] {
            let iBeaconKey = "kCBAdvDataAppleBeaconKey"
            
            let data = NSMutableData(capacity: 21)!
            var uuidBytes = [UInt8](repeating: 0, count: 16)
            proximityUUID.getBytes(&uuidBytes)
            data.append(uuidBytes, length: 16)
            var majorValue = CFSwapInt16(major)
            data.append(&majorValue, length: 2)
            var minorValue = CFSwapInt16(minor)
            data.append(&minorValue, length: 2)
            var powerValue: Int8 = power ?? -59
            data.append(&powerValue, length: 1)
            
            return [iBeaconKey: data]
        }
    }
#else
    typealias BeaconRegion = CLBeaconRegion
#endif

/// VirtualBeacon allows an iOS/tvOS device to act as an iBeacon.
public class VirtualBeacon: NSObject, CBPeripheralManagerDelegate {
    
    public weak var delegate: VirtualBeaconDelegate?
    
    /// Indicates whether the beacon is currently being advertised or not.
    public var isAdvertising: Bool {
        return peripheralManager.isAdvertising
    }
    
    private var peripheralManager: CBPeripheralManager!
    
    private var region: BeaconRegion!
    
    private static let regionIdentifier = UUID().uuidString
    
    public override init() {
        super.init()
        peripheralManager = CBPeripheralManager()
        peripheralManager.delegate = self
    }
    
    deinit {
        stopAdvertising()
    }
    
    /// Start advertising the beacon.
    ///
    /// NOTE: CoreBluetooth only allows virtual beacons while the app is in
    ///       the foreground, so VirtualBeacon sets idleTimerDisabled to true
    ///       while it is advertising.
    ///
    /// - Parameters:
    ///     - uuid: The proximity UUID of the beacon.
    ///     - major: The most significant value of the beacon.
    ///     - minor: The least significant value of the beacon.
    ///
    /// - SeeAlso: CoreLocation.CLBeacon
    public func startAdvertising(uuid: UUID, major: CLBeaconMajorValue, minor: CLBeaconMinorValue) {
        let isBluetoothEnabled = peripheralManager.state == .poweredOn
        if isBluetoothEnabled {
#if os(tvOS)
    region = BeaconRegion(proximityUUID: uuid as NSUUID, major: major, minor: minor, identifier: VirtualBeacon.regionIdentifier)
#else
    region = BeaconRegion(proximityUUID: uuid, major: major, minor: minor, identifier: VirtualBeacon.regionIdentifier)
#endif
            if isAdvertising {
                peripheralManager.stopAdvertising()
            }
            startAdvertisingRegion(region: region)
        } else {
            delegate?.virtualBeaconDidFailToStartAdvertisingDueToBluetoothNotEnabled(self)
        }
    }
    
    /// Stop advertising the beacon.
    public func stopAdvertising() {
        UIApplication.shared.isIdleTimerDisabled = false
        if isAdvertising {
            peripheralManager.stopAdvertising()
            delegate?.virtualBeaconDidStopAdvertising(self)
        }
    }
    
    private func startAdvertisingRegion(region: BeaconRegion) {
        let advertisingData = NSDictionary(dictionary: region.peripheralData(withMeasuredPower: nil)) as! [String : AnyObject]
        peripheralManager.startAdvertising(advertisingData)
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    // MARK: - Peripheral Manager Delegate
    
    public func peripheralManagerDidUpdateState(_ peripheralManager: CBPeripheralManager) {
        let isBluetoothEnabled = peripheralManager.state == .poweredOn
        if !isBluetoothEnabled {
            stopAdvertising()
        }
    }
    
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if error == nil {
            delegate?.virtualBeaconDidStartAdvertising(self)
        } else {
            delegate?.virtualBeaconDidFailToStartAdvertising(self, error: error! as NSError)
        }
    }
}

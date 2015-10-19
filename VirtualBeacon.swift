//
// Copyright © 2015 Apparata AB. All rights reserved.
//
// MIT License
//
// Copyright (C) 2015 by Apparata AB
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
    func virtualBeaconDidStartAdvertising(virtualBeacon: VirtualBeacon)
    func virtualBeaconDidFailToStartAdvertising(virtualBeacon: VirtualBeacon, error: NSError)
    func virtualBeaconDidFailToStartAdvertisingDueToBluetoothNotEnabled(virtualBeacon: VirtualBeacon)
    func virtualBeaconDidStopAdvertising(virtualBeacon: VirtualBeacon)
}

/// VirtualBeacon allows a iOS device to act as an iBeacon.
public class VirtualBeacon: NSObject, CBPeripheralManagerDelegate {
    
    public weak var delegate: VirtualBeaconDelegate?
    
    /// Indicates whether the beacon is currently being advertised or not.
    public var isAdvertising: Bool {
        return peripheralManager.isAdvertising
    }
    
    private var peripheralManager: CBPeripheralManager!
    
    private var region: CLBeaconRegion!
    
    private static let regionIdentifier = NSUUID().UUIDString
    
    public override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))
    }
    
    /// Start advertising the beacon.
    ///
    /// NOTE: CoreBluetooth only allows virtual beacons while the app is in
    ///       the foreground, so VirtualBeacon set idleTimerDisabled to true
    ///       while it is advertising.
    ///
    /// - Parameters:
    ///     - uuid: The proximity UUID of the beacon.
    ///     - major: The most significant value of the beacon.
    ///     - minor: The least significant value of the beacon.
    ///
    /// - SeeAlso: CoreLocation.CLBeacon
    public func startAdvertising(uuid uuid: NSUUID, major: CLBeaconMajorValue, minor: CLBeaconMinorValue) {
        let isBluetoothEnabled = peripheralManager.state == .PoweredOn
        if isBluetoothEnabled {
            region = CLBeaconRegion(proximityUUID: uuid, major: major, minor: minor, identifier: VirtualBeacon.regionIdentifier)
            if isAdvertising {
                peripheralManager.stopAdvertising()
            }
            startAdvertisingRegion(region)
        } else {
            delegate?.virtualBeaconDidFailToStartAdvertisingDueToBluetoothNotEnabled(self)
        }
    }
    
    /// Stop advertising the beacon.
    public func stopAdvertising() {
        UIApplication.sharedApplication().idleTimerDisabled = false
        if isAdvertising {
            peripheralManager.stopAdvertising()
            delegate?.virtualBeaconDidStopAdvertising(self)
        }
    }
    
    private func startAdvertisingRegion(region: CLBeaconRegion) {
        let advertisingData = NSDictionary(dictionary: region.peripheralDataWithMeasuredPower(nil)) as! [String : AnyObject]
        peripheralManager.startAdvertising(advertisingData)
        UIApplication.sharedApplication().idleTimerDisabled = true
    }
    
    // MARK: - Peripheral Manager Delegate
    
    public func peripheralManagerDidUpdateState(peripheralManager: CBPeripheralManager) {
        let isBluetoothEnabled = peripheralManager.state == .PoweredOn
        if !isBluetoothEnabled {
            stopAdvertising()
        }
    }
    
    public func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager, error: NSError?) {
        if error == nil {
            delegate?.virtualBeaconDidStartAdvertising(self)
        } else {
            delegate?.virtualBeaconDidFailToStartAdvertising(self, error: error!)
        }
    }
}

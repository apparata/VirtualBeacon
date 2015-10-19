# VirtualBeacon
A class that allows an iOS device to act as an iBeacon.

## Example

```Swift
let beacon = VirtualBeacon()
beacon.delegate = <Insert VirtualBeaconDelegate here>
beacon.startAdvertising(uuid: "<Insert your UUID here>", major: <insert major here>, minor: <insert minor here>)
// ...
beacon.stopAdvertising()
```

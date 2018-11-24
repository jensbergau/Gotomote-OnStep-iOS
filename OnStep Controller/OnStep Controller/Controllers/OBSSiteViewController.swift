//
//  OBSSiteViewController.swift
//  OnStep Controller
//
//  Created by Satnam on 8/21/18.
//  Copyright © 2018 Satnam Singh. All rights reserved.
//

import UIKit
import CocoaAsyncSocket
import CoreLocation
import NotificationBanner

class OBSSiteViewController: UIViewController, CLLocationManagerDelegate {
    
    @IBOutlet var segmentControl: TTSegmentedControl!
    
    var clientSocket: GCDAsyncSocket!
    
    // Used to start getting the users location
    let locationManager = CLLocationManager()
    
    @IBOutlet var siteNaTF: CustomTextField!
  //  @IBOutlet var latTF: CustomTextField!
    
    @IBOutlet var latDDTF: CustomTextField!
    @IBOutlet var latMMTF: CustomTextField!
    
    @IBOutlet var longDDTF: CustomTextField!
    @IBOutlet var longMMTF: CustomTextField!
    
    @IBOutlet var utcHHTF: CustomTextField!
    @IBOutlet var utcMMTF: CustomTextField!

    @IBOutlet var uploadBtn: UIButton!
    @IBOutlet var useLocat: UIButton!
    
    var selectedIndex: Int = Int()
    var readerText: String = String()
    
    @IBAction func userCurrentLocation(_ sender: UIButton) {
        
        if CLLocationManager.locationServicesEnabled() {
            switch CLLocationManager.authorizationStatus() {
            case .notDetermined, .restricted, .denied:
                print("No access")
            case .authorizedAlways, .authorizedWhenInUse:
                print("Access")
                locationManager.startUpdatingLocation()
                if locationManager.location != nil {
                    let latSplit = "\(locationManager.location!.coordinate.latitude.roundedDecimal(to: 2))".split(separator: ".")
                    let longSplit = "\(locationManager.location!.coordinate.longitude.roundedDecimal(to: 2))".split(separator: ".")
                    print("locationManager.location!.coordinate", locationManager.location!.coordinate)
                    
                    // fix symbol for latitude degrees
                    let z = Int(latSplit[opt: 0]!)!
                    if (z < 0) {
                      //  decString = String(format: "%03d:%02d", Int(decStr![0])!, Int(decStr![1])!)
                        latDDTF.text = String(format: "%03d", Int(latSplit[opt: 0]!)!) //neg
                    } else if (z == 0) {
                        //    print(String(format: "%02d:%02d:%02d", decDD as CVarArg, decMM, decSS)) // not happening
                        latDDTF.text = String(format: "%02d", Int(latSplit[opt: 0]!)!)
                    } else {
                        latDDTF.text = String(format: "+%02d", Int(latSplit[opt: 0]!)!) //pos
                    }
                    
                    latMMTF.text = String(format: "%02d", doubleToInteger(data: ((Double(latSplit[opt: 1]!)!/100)*60).rounded()))

                    let y = Int(longSplit[opt: 0]!)!
                    if (y < 0) {
                        //  decString = String(format: "%03d:%02d", Int(decStr![0])!, Int(decStr![1])!)
                        longDDTF.text = String(format: "%04d", Int(longSplit[opt: 0]!)!) //neg
                    } else if (y == 0) {
                        longDDTF.text = String(format: "%03d", Int(longSplit[opt: 0]!)!)
                    } else {
                        longDDTF.text = String(format: "+%03d", Int(longSplit[opt: 0]!)!) //pos
                    }
                    
                    longMMTF.text = String(format: "%02d", doubleToInteger(data: ((Double(longSplit[opt: 1]!)!/100)*60).rounded()))
                    
                    let utc = TimeZone.current.offsetInHours().components(separatedBy: ":")
                    utcHHTF.text = utc[opt: 0]
                    utcMMTF.text = utc[opt: 1]
                }

            }
        } else {
            print("Location services are not enabled")
            showLocationDisabledPopUp()
        }
        
    }
    
    func doubleToInteger(data:Double) -> Int {
        let doubleToString = "\(data)"
        let stringToInteger = (doubleToString as NSString).integerValue
        
        return stringToInteger
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUserInterface()
        
        // For use when the app is open & in the background
        locationManager.requestAlwaysAuthorization()
        
        // For use when the app is open
        //locationManager.requestWhenInUseAuthorization()
        
        // If location services is enabled get the users location
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest // You can change the locaiton accuary here.
        }
    }
    
    // Print out the location to the console
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            print(location.coordinate)
            locationManager.stopUpdatingLocation()
        //    latTF.text = "\(locationManager.location!.coordinate.latitude.roundedDecimal(to: 2))"
        //    longTF.text = "\(locationManager.location!.coordinate.longitude.roundedDecimal(to: 2))"
        }
    }
    
    // If we have been deined access give the user the option to change it
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == CLAuthorizationStatus.denied {
            showLocationDisabledPopUp()
        } else if status == CLAuthorizationStatus.restricted {
            showLocationDisabledPopUp()
        }
    }
    
    // Show the popup to the user if we have been deined access
    func showLocationDisabledPopUp() {
        let alertController = UIAlertController(title: "Location Service disabled",
                                                message: "In order to access your location app needs to have loction services enabled in settings.",
                                                preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        let openAction = UIAlertAction(title: "Open Settings", style: .default) { (action) in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        alertController.addAction(openAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clErr = error as? CLError {
            switch clErr {
            case CLError.locationUnknown:
                print("location unknown")
            case CLError.denied:
                print("denied")
            default:
                print("other Core Location error")
            }
        } else {
            print("other error:", error.localizedDescription)
        }
    }
    
    func triggerConnection(cmd: String, setTag: Int) {
        
        clientSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        
        do {
            var addr = "192.168.0.1"
            var port: UInt16 = 9999
            
            // Populate data
            if addressPort.value(forKey: "addressPort") as? String == nil {
                
                addressPort.set("192.168.0.1:9999", forKey: "addressPort")
                addressPort.synchronize()  // Initialize
                
            } else {
                let addrPort = (addressPort.value(forKey: "addressPort") as? String)?.components(separatedBy: ":")
                
                addr = addrPort![opt: 0]!
                port = UInt16(addrPort![opt: 1]!)!
            }
            
            try clientSocket.connect(toHost: addr, onPort: port, withTimeout: 1.5)
            let data = cmd.data(using: .utf8)
            clientSocket.write(data!, withTimeout: 1.5, tag: setTag)
            clientSocket.readData(withTimeout: 1.5, tag: setTag)
        } catch {
        }
    }
    
    func setupUserInterface() {
        
        navigationItem.title = "SITE SELECTION"
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.font: UIFont(name: "SFUIDisplay-Bold", size: 11)!,NSAttributedString.Key.foregroundColor: UIColor.white, kCTKernAttributeName : 1.1] as? [NSAttributedString.Key : Any]
        self.view.backgroundColor = .black
        
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        
        let item = UIBarButtonItem(title: " ", style: .plain, target: nil, action: nil)
        self.navigationItem.backBarButtonItem = item
        
        addBtnProperties(button: uploadBtn)
        addBtnProperties(button: useLocat)
        
        addTFProperties(tf: siteNaTF, placeholder: "")
        
        addTFProperties(tf: latDDTF, placeholder: "")
        addTFProperties(tf: latMMTF, placeholder: "")

        addTFProperties(tf: longDDTF, placeholder: "")
        addTFProperties(tf: longMMTF, placeholder: "")

        addTFProperties(tf: utcHHTF, placeholder: "")
        addTFProperties(tf: utcMMTF, placeholder: "")

        segmentControl.itemTitles = ["Site 0","Site 1","Site 2", "Site 3"]
        
        segmentControl.allowChangeThumbWidth = false
        segmentControl.selectedTextFont = UIFont(name: "SFUIDisplay-Medium", size: 14.0)!
        segmentControl.selectedTextColor = UIColor.black
        segmentControl.defaultTextFont = UIFont(name: "SFUIDisplay-Medium", size: 14.0)!
        segmentControl.defaultTextColor = UIColor.white
        segmentControl.useGradient = false
        segmentControl.useShadow = false
        segmentControl.containerBackgroundColor = .clear
        segmentControl.thumbColor = (UIColor(red: 255/255.0, green: 192/255.0, blue: 0/255.0, alpha: 1.0))
        
        segmentControl.selectItemAt(index: 0, animated: true)
        selectedIndex = 0
        
        self.triggerConnection(cmd: ":W0#:GM#:Gt#:Gg#:GG#", setTag: 0) // Reader for Site 0
        
        segmentControl.didSelectItemWith = { index, title in
            self.selectedIndex = index
            
            switch self.selectedIndex {
            case 0:
                print("0")
                self.readerText = ""
                DispatchQueue.main.async {
                    self.siteNaTF.text = ""
                    self.latDDTF.text = ""
                    self.latMMTF.text = ""
                    self.longDDTF.text = ""
                    self.longMMTF.text = ""
                    self.utcHHTF.text = ""
                    self.utcMMTF.text = ""
                    
                }
                self.triggerConnection(cmd: ":W0#:GM#:Gt#:Gg#:GG#", setTag: 0) // Reader for Site 0
                
            case 1:
                print("1")
                self.readerText = ""
                DispatchQueue.main.async {
                    self.siteNaTF.text = ""
                    self.latDDTF.text = ""
                    self.latMMTF.text = ""
                    self.longDDTF.text = ""
                    self.longMMTF.text = ""
                    self.utcHHTF.text = ""
                    self.utcMMTF.text = ""
                }
                
                self.triggerConnection(cmd: ":W1#:GN#:Gt#:Gg#:GG#", setTag: 0) // Reader for Site 1
                
                
            case 2:
                print("2")
                self.readerText = ""
                DispatchQueue.main.async {
                    self.siteNaTF.text = ""
                    self.latDDTF.text = ""
                    self.latMMTF.text = ""
                    self.longDDTF.text = ""
                    self.longMMTF.text = ""
                    self.utcHHTF.text = ""
                    self.utcMMTF.text = ""
                }
                
                self.triggerConnection(cmd: ":W2#:GO#:Gt#:Gg#:GG#", setTag: 0) // Reader for Site 2
                
            case 3:
                print("3")
                self.readerText = ""
                DispatchQueue.main.async {
                    self.siteNaTF.text = ""
                    self.latDDTF.text = ""
                    self.latMMTF.text = ""
                    self.longDDTF.text = ""
                    self.longMMTF.text = ""
                    self.utcHHTF.text = ""
                    self.utcMMTF.text = ""
                    
                }
                
                self.triggerConnection(cmd: ":W3#:GP#:Gt#:Gg#:GG#", setTag: 0) // Reader for Site 3
                
            default:
                print("do something default")
            }
            
            
        }
    }
    
    // Upload content to server
    @IBAction func uploadAction(_ sender: UIButton) {
        
        
        switch selectedIndex {
        case 0:
            print("upload 0")
            
            self.triggerConnection(cmd: ":W\(0)#:SM\(siteNaTF.text!)#:St\(self.latDDTF.text! + "*" + self.latMMTF.text!)#:Sg\(self.longDDTF.text!)*\(self.longMMTF.text!)#:SG\(self.utcHHTF.text!   + ":" + self.utcMMTF.text!)#", setTag: 1) // select site 0 // site name //
        case 1:
            print("upload 1")
            
            self.triggerConnection(cmd: ":W\(1)#:SN\(siteNaTF.text!)#:St\(self.latDDTF.text! + "*" + self.latMMTF.text!)#:Sg\(self.longDDTF.text!)*\(self.longMMTF.text!)#:SG\(self.utcHHTF.text!   + ":" + self.utcMMTF.text!)#", setTag: 1) // select site 0 // site name //
        case 2:
            print("upload 2")
            
            self.triggerConnection(cmd: ":W\(2)#:SO\(siteNaTF.text!)#:St\(self.latDDTF.text! + "*" + self.latMMTF.text!)#:Sg\(self.longDDTF.text!)*\(self.longMMTF.text!)#:SG\(self.utcHHTF.text!   + ":" + self.utcMMTF.text!)#", setTag: 1) // select site 0 // site name //
        case 3:
            print("upload 3")
            
            self.triggerConnection(cmd: ":W\(3)#:SP\(siteNaTF.text!)#:St\(self.latDDTF.text! + "*" + self.latMMTF.text!)#:Sg\(self.longDDTF.text!)*\(self.longMMTF.text!)#:SG\(self.utcHHTF.text!   + ":" + self.utcMMTF.text!)#", setTag: 1) // select site 0 // site name //
        default:
            print("default")
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}


extension OBSSiteViewController: GCDAsyncSocketDelegate {
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        let getText = String(data: data, encoding: .utf8)
        print("got:", getText)
        switch tag {
        case 0:
            readerText += "\(getText!)"
            
            let index = readerText.replacingOccurrences(of: "#", with: ",").dropLast().components(separatedBy: ",")
              print(index)
            DispatchQueue.main.async {
                self.siteNaTF.text = index[opt: 0]
                
                self.latDDTF.text = index[opt: 1]?.components(separatedBy: "*")[opt: 0]
                self.latMMTF.text = index[opt: 1]?.components(separatedBy: "*")[opt: 1]
                self.longDDTF.text = index[opt: 2]?.components(separatedBy: "*")[opt: 0]
                self.longMMTF.text = index[opt: 2]?.components(separatedBy: "*")[opt: 1]
                // save retrieved location
    //            UserDefaults.standard.set(location:CLLocation(latitude: CLLocationDegrees(Double(self.latDDTF.text! + "." + self.latMMTF.text!)!), longitude: CLLocationDegrees(Double(self.longDDTF.text! + "." + self.longMMTF.text!)!)), forKey:"myLocation")
   //             print("yaay:", UserDefaults.standard.location(forKey:"myLocation")
//)
             //   self.latTF.text =
                
                self.utcHHTF.text = index[opt: 3]?.components(separatedBy: ":")[opt: 0]
                self.utcMMTF.text = index[opt: 3]?.components(separatedBy: ":")[opt: 1]

            }
            
        case 1:
            print("Tag 1:", getText!)
            
        default:
            print("def")
        }
        clientSocket.readData(withTimeout: -1, tag: tag)
        // clientSocket.disconnect()
        
    }
    
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        
        let address = "Server IP：" + "\(host)"
        print("didConnectToHost:", address)
        
        switch sock.isConnected {
        case true:
            print("Connected")
        case false:
            print("Disconnected")
        default:
            print("Default")
        }
        
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        
        if err != nil && String(err!.localizedDescription) != "Socket closed by remote peer" {
            print("Disconnected called:", err!.localizedDescription)
            let banner = StatusBarNotificationBanner(title: "\(err!.localizedDescription)", style: .danger)
            banner.show()
            banner.remove()
        }
    }
    
}

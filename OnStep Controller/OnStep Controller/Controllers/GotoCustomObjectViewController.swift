//
//  GotoCustomObjectViewController.swift
//  OnStep Controller
//
//  Created by Satnam on 11/20/18.
//  Copyright © 2018 Silver Seahog. All rights reserved.
//

// TODO Goto command rejects if not aligned

import UIKit
import SwiftyJSON
import CoreLocation
import SpaceTime
import MathUtil
import CocoaAsyncSocket
import NotificationBanner

class GotoCustomObjectViewController: UIViewController {
    
    var passedCoordinates: [String] = [String]() // Get Latitude (for current site) // Get Longitude (for current site) // Get UTC Offset(for current site)
    var passedRA: String = String()
    var passedDec: String = String()

    // coordinatesToPass: ["+01.55", "+179.52"] rightAscension: 01:01:00 declination: -01:01:00
    
    var socketConnector: SocketDataManager!
    var clientSocket: GCDAsyncSocket!
    
    var filteredJSON: [JSON] = [JSON()]
    
    @IBOutlet var gotoBtn: UIButton!
    @IBOutlet var abortBtn: UIButton!
    
  //  @IBOutlet var leftArrowBtn: UIButton!
  //  @IBOutlet var rightArrowBtn: UIButton!
    @IBOutlet var revNSBtn: UIButton!
    @IBOutlet var revEWBtn: UIButton!
    @IBOutlet var syncBtn: UIButton!
    
    @IBOutlet var northBtn: UIButton!
    @IBOutlet var southBtn: UIButton!
    @IBOutlet var westBtn: UIButton!
    @IBOutlet var eastBtn: UIButton!
    
    @IBOutlet var speedSlider: UISlider!
    
    // Segue Data
    var alignTypePassed: Int = Int()
    var passedSlctdObjIndex: Int = Int()
    
    @IBOutlet var ra: UILabel!
    @IBOutlet var dec: UILabel!
    
    @IBOutlet var altitude: UILabel!
    @IBOutlet var azimuth: UILabel!
    
    @IBOutlet var aboveHorizon: UILabel!
    
    // retrieved
   // var slctdJSONObj: [JSON] = [JSON()]
    
    let formatter = NumberFormatter()
    
    // formed
    
    // --------------------------------------------------------------------------------------------------------------------------------------------------------------------
    @objc func screenUpdate() {

        
        //Right Ascension in hours and minutes  ->     :SrHH:MM:SS# *
        //The declination is given in degrees and minutes. -> :SdsDD:MM:SS# *
        
        // https://groups.io/g/onstep/topic/ios_app_for_onstep/23675334?p=,,,20,0,0,0::recentpostdate%2Fsticky,,,20,2,40,23675334
        
        var splitRA = passedRA.split(separator: ":")
        var splitDec = passedDec.split(separator: ":")
        
        let vegaCoord = EquatorialCoordinate(rightAscension: HourAngle(hour: Double(splitRA[0])!, minute: Double(splitRA[1])!, second: Double(splitRA[2])!), declination: DegreeAngle(degree: Double(splitDec[0])!, minute: Double(splitDec[1])!, second: Double(splitDec[2])!), distance: 1)
        
        let date = Date()
        
        let locTime = ObserverLocationTime(location: CLLocation(latitude: Double(passedCoordinates[0])!, longitude: Double(passedCoordinates[1])!), timestamp: JulianDay(date: date))
        
        let vegaAziAlt = HorizontalCoordinate.init(equatorialCoordinate: vegaCoord, observerInfo: locTime)
        
        self.altitude.text = "Altitude: " + "\(vegaAziAlt.altitude.wrappedValue.roundedDecimal(to: 3))".replacingOccurrences(of: ".", with: "° ") + "'"
        self.azimuth.text = "Azimuth: " + "\(vegaAziAlt.azimuth.wrappedValue.roundedDecimal(to: 3))".replacingOccurrences(of: ".", with: "° ") + "'"
        
        self.aboveHorizon.text = "Above Horizon? = \(vegaAziAlt.altitude.wrappedValue > 0 ? "Yes" : "No")"
    }

    //         print("thisss:", String(format: "%02d:%02d:%02d", hours, minutes, seconds))
    
    @IBAction func gotoBtn(_ sender: UIButton) {
        let formatRA = passedRA.replacingOccurrences(of: ":", with: "")
        let formatDec = passedDec.replacingOccurrences(of: ":", with: "")

        triggerConnection(cmd: ":Sr\(formatRA)#:Sd\(formatDec)#:CS#") //Set target RA # Set target Dec
        // this -> :Sr21:30:00#:Sd+12:10:00#:MS#
    }
    
    // Mark: Slider - Increase Speed
    
    @IBAction func abortBtn(_ sender: UIButton) {
        triggerConnection(cmd: ":Q#")
    }
    
    // Mark: Slider - Increase Speed
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        
        switch Int(sender.value) {
        case 0:
            triggerConnection(cmd: ":R0#")
        case 1:
            triggerConnection(cmd: ":R1#")
        case 2:
            triggerConnection(cmd: ":R2#")
        case 3:
            triggerConnection(cmd: ":R3#")
        case 4:
            triggerConnection(cmd: ":R4#")
        case 5:
            triggerConnection(cmd: ":R5#")
        case 6:
            triggerConnection(cmd: ":R6#")
        case 7:
            triggerConnection(cmd: ":R7#")
        case 8:
            triggerConnection(cmd: ":R8#")
        case 9:
            triggerConnection(cmd: ":R9#")
        default:
            print("sero")
        }
        
    }
    
    
    func triggerConnection(cmd: String) {
        
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
            clientSocket.write(data!, withTimeout: -1, tag: 0)
        } catch {
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("passedCoordinatesss:", passedCoordinates)

        speedSlider.minimumValue = 0
        speedSlider.maximumValue = 9
        speedSlider.isContinuous = true
        
        northBtn.addTarget(self, action: #selector(moveToNorth), for: UIControl.Event.touchDown)
        northBtn.addTarget(self, action: #selector(stopToNorth), for: UIControl.Event.touchUpInside)
        
        southBtn.addTarget(self, action: #selector(moveToSouth), for: UIControl.Event.touchDown)
        southBtn.addTarget(self, action: #selector(stopToSouth), for: UIControl.Event.touchUpInside)
        
        westBtn.addTarget(self, action: #selector(moveToWest), for: UIControl.Event.touchDown)
        westBtn.addTarget(self, action: #selector(stopToWest), for: UIControl.Event.touchUpInside)
        
        eastBtn.addTarget(self, action: #selector(moveToEast), for: UIControl.Event.touchDown)
        eastBtn.addTarget(self, action: #selector(stopToEast), for: UIControl.Event.touchUpInside)
        
        setupLabelData()
        setupUserInterface()
        
        let displayLink = CADisplayLink(target: self, selector: #selector(screenUpdate))
        displayLink.add(to: .main, forMode: RunLoop.Mode.default)
    }
    
    func alertMessage(message:String,buttonText:String,completionHandler:(()->())?) {
        let alert = UIAlertController(title: "Location", message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: buttonText, style: .default) { (action:UIAlertAction) in
            completionHandler?()
        }
        alert.addAction(action)
        self.present(alert, animated: true, completion: nil)
    }
    
    func replace(myString: String, _ index: Int, _ newChar: Character) -> String {
        var chars = Array(myString)     // gets an array of characters
        chars[index] = newChar
        let modifiedString = String(chars)
        return modifiedString
    }
    
    func setupUserInterface() {
        addBtnProperties(button: gotoBtn)
        addBtnProperties(button: abortBtn)
      //  addBtnProperties(button: leftArrowBtn)
      //  addBtnProperties(button: rightArrowBtn)
        addBtnProperties(button: revNSBtn)
        addBtnProperties(button: revEWBtn)
        addBtnProperties(button: syncBtn)
        
        addBtnProperties(button: northBtn)
        northBtn.backgroundColor = UIColor(red: 255/255.0, green: 192/255.0, blue: 0/255.0, alpha: 1.0)
        addBtnProperties(button: southBtn)
        southBtn.backgroundColor = UIColor(red: 255/255.0, green: 192/255.0, blue: 0/255.0, alpha: 1.0)
        addBtnProperties(button: westBtn)
        westBtn.backgroundColor = UIColor(red: 255/255.0, green: 192/255.0, blue: 0/255.0, alpha: 1.0)
        addBtnProperties(button: eastBtn)
        eastBtn.backgroundColor = UIColor(red: 255/255.0, green: 192/255.0, blue: 0/255.0, alpha: 1.0)
        
        speedSlider.tintColor = UIColor(red: 255/255.0, green: 192/255.0, blue: 0/255.0, alpha: 1.0)
        
        // Do any additional setup after loading the view.
        
        navigationItem.title = "SYNC CUSTOM OBJECT"
        
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.font: UIFont(name: "SFUIDisplay-Bold", size: 11)!,NSAttributedString.Key.foregroundColor: UIColor.white, kCTKernAttributeName : 1.1] as? [NSAttributedString.Key : Any]
        
        self.view.backgroundColor = .black
    }
    
    func setupLabelData() {
        
        // RA
        var splitRA = passedRA.split(separator: ":")
        ra.text = "RA = \(splitRA[0])h \(splitRA[1])m \(splitRA[2])s"
        
        formatter.numberStyle = .decimal
        
        // DEC
            var splitDec = passedDec.split(separator: ":")
            dec.text = "DEC = \(splitDec[0])° \(splitDec[1])' \(splitDec[2])\""
    }
    
    func doubleToInteger(data:Double)-> Int {
        let doubleToString = "\(data)"
        let stringToInteger = (doubleToString as NSString).integerValue
        
        return stringToInteger
    }
    
    // Align the Star
    @IBAction func syncAction(_ sender: UIButton) {
        triggerConnection(cmd: ":CM#")
        //  :CM#   Synchonize the telescope with the current database object (as above)
        //    Returns: "N/A#" on success, "En#" on failure where n is the error code per the :MS# command
    }
    
    // Pass Int back to controller
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
    }
    
    // North
    @objc func moveToNorth() {
        triggerConnection(cmd: ":Mn#")
        print("moveToNorth")
    }
    
    @objc func stopToNorth() {
        triggerConnection(cmd: ":Qn#")
        print("stopToNorth")
    }
    
    // South
    @objc func moveToSouth() {
        triggerConnection(cmd: ":Ms#")
        print("moveToSouth")
    }
    
    @objc func stopToSouth() {
        triggerConnection(cmd: ":Qs#")
        print("stopToSouth")
    }
    
    // West
    @objc func moveToWest(_ sender: UIButton) {
        triggerConnection(cmd: ":Mw#")
        print("moveToWest")
    }
    
    @objc func stopToWest() {
        triggerConnection(cmd: ":Qw#")
        print("stopToWest")
    }
    
    // East
    @objc func moveToEast() {
        triggerConnection(cmd: ":Me#")
        print("moveToEast")
    }
    
    @objc func stopToEast() {
        triggerConnection(cmd: ":Qe#")
        print("stopToEast")
    }
    
    // Stop
    @IBAction func stopScope(_ sender: Any) {
        triggerConnection(cmd: ":Q#")
        //   print("stopScope")
        //    :T+#
        //    triggerConnection(cmd: ":R9#")
        
    }
    
    
    // Mark: Reverse North-South buttons
    @IBAction func reverseNS(_ sender: UIButton) {
        self.northBtn.removeTarget(nil, action: nil, for: .allEvents)
        self.southBtn.removeTarget(nil, action: nil, for: .allEvents)
        DispatchQueue.main.async {
            
            if self.northBtn.currentTitle == "North" {
                
                self.northBtn.setTitle("South", for: .normal)
                self.southBtn.setTitle("North", for: .normal)
                
                //south targets north
                self.southBtn.addTarget(self, action: #selector(self.moveToNorth), for: UIControl.Event.touchDown)
                self.southBtn.addTarget(self, action: #selector(self.stopToNorth), for: UIControl.Event.touchUpInside)
                
                //north targets south
                self.northBtn.addTarget(self, action: #selector(self.moveToSouth), for: UIControl.Event.touchDown)
                self.northBtn.addTarget(self, action: #selector(self.stopToSouth), for: UIControl.Event.touchUpInside)
                
            } else {
                self.northBtn.setTitle("North", for: .normal)
                self.southBtn.setTitle("South", for: .normal)
                
                //north targets north
                self.northBtn.addTarget(self, action: #selector(self.moveToNorth), for: UIControl.Event.touchDown)
                self.northBtn.addTarget(self, action: #selector(self.stopToNorth), for: UIControl.Event.touchUpInside)
                
                //south targets south
                self.southBtn.addTarget(self, action: #selector(self.moveToSouth), for: UIControl.Event.touchDown)
                self.southBtn.addTarget(self, action: #selector(self.stopToSouth), for: UIControl.Event.touchUpInside)
                
            }
        }
        
    }
    
    // Mark: Reverse East-West buttons
    @IBAction func reverseEW(_ sender: UIButton) {
        self.westBtn.removeTarget(nil, action: nil, for: .allEvents)
        self.eastBtn.removeTarget(nil, action: nil, for: .allEvents)
        DispatchQueue.main.async {
            
            if self.westBtn.currentTitle == "West" {
                
                self.westBtn.setTitle("East", for: .normal)
                self.eastBtn.setTitle("West", for: .normal)
                
                //east targets west
                self.eastBtn.addTarget(self, action: #selector(self.moveToWest), for: UIControl.Event.touchDown)
                self.eastBtn.addTarget(self, action: #selector(self.stopToWest), for: UIControl.Event.touchUpInside)
                
                //west targets east
                self.westBtn.addTarget(self, action: #selector(self.moveToEast), for: UIControl.Event.touchDown)
                self.westBtn.addTarget(self, action: #selector(self.stopToEast), for: UIControl.Event.touchUpInside)
                
            } else {
                self.westBtn.setTitle("West", for: .normal)
                self.eastBtn.setTitle("East", for: .normal)
                
                //west targets west
                self.westBtn.addTarget(self, action: #selector(self.moveToWest), for: UIControl.Event.touchDown)
                self.westBtn.addTarget(self, action: #selector(self.stopToWest), for: UIControl.Event.touchUpInside)
                
                //east targets east
                self.eastBtn.addTarget(self, action: #selector(self.moveToEast), for: UIControl.Event.touchDown)
                self.eastBtn.addTarget(self, action: #selector(self.stopToEast), for: UIControl.Event.touchUpInside)
                
            }
        }
        
    }
    
    // Mark: Lock Buttons
    @IBAction func lockButtons(_ sender: UIButton) {
        
        if revNSBtn.isUserInteractionEnabled == true {
            buttonTextAlpha(alpha: 0.25, activate: false)
        } else {
            buttonTextAlpha(alpha: 1.0, activate: true)
        }
        
    }
    
    func buttonTextAlpha(alpha: CGFloat, activate: Bool) {
        DispatchQueue.main.async {
            self.revEWBtn.alpha = alpha
            self.revNSBtn.alpha = alpha
            self.syncBtn.alpha = alpha
          //  self.leftArrowBtn.alpha = alpha
          //  self.rightArrowBtn.alpha = alpha
            self.speedSlider.alpha = alpha
            
          //  self.leftArrowBtn.isUserInteractionEnabled = activate
          //  self.rightArrowBtn.isUserInteractionEnabled = activate
            self.revNSBtn.isUserInteractionEnabled = activate
            self.revEWBtn.isUserInteractionEnabled = activate
            self.syncBtn.isUserInteractionEnabled = activate
            self.speedSlider.isUserInteractionEnabled = activate
            
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}


extension GotoCustomObjectViewController: GCDAsyncSocketDelegate {
    
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
        clientSocket.readData(withTimeout: -1, tag: 0)
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        let text = String(data: data, encoding: .utf8)
        print("didRead:", text!)
        clientSocket.readData(withTimeout: -1, tag: 0)
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

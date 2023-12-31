//
//  MapViewController.swift
//  WeTrain
//
//  Created by Bobby Ren on 8/1/15.
//  Copyright (c) 2015 Bobby Ren. All rights reserved.
//

import UIKit
import GoogleMaps
import Parse

class MapViewController: UIViewController, CLLocationManagerDelegate, GMSMapViewDelegate {

    var requestedTrainingType: Int?
    var requestedTrainingLength: Int?
    
    @IBOutlet var mapView: GMSMapView!
    @IBOutlet var iconLocation: UIImageView!
    let locationManager = CLLocationManager()
    var currentLocation: CLLocation?
    
    @IBOutlet var buttonRequest: UIButton!
    
    // address view
    @IBOutlet var viewAddress: UIView!
    @IBOutlet var inputStreet: UITextField!
    @IBOutlet var inputCity: UITextField!
    
    var inputManualAddress: UITextField?
    
    // request status
    var requestMarker: GMSMarker?
    
    var currentRequest: PFObject?
    
    var warnedAboutService: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.buttonRequest.enabled = false
        
        locationManager.delegate = self
        
        if (locationManager.respondsToSelector("requestWhenInUseAuthorization")) {
            locationManager.requestWhenInUseAuthorization()
        }
        else {
            locationManager.startUpdatingLocation()
        }

        self.mapView.myLocationEnabled = true
        self.iconLocation.layer.zPosition = 1
        self.iconLocation.image = UIImage(named: "iconLocation")!.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        self.iconLocation.tintColor = UIColor(red: 215.0/255.0, green: 84.0/255.0, blue: 82.0/255.0, alpha: 1)

        // always allow button
        self.buttonRequest.enabled = true
        self.buttonRequest.layer.zPosition = 1
        self.buttonRequest.alpha = 1

        self.setTitleBarColor(UIColor.blackColor(), tintColor: UIColor.whiteColor())
        self.navigationController!.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName:UIColor.whiteColor()]

        //self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: UIBarButtonItemStyle.Done, target: self, action: "close")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func close() {
        self.navigationController!.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        // if location is nil, then we haven't tried to load location yet so let locationManager work
        // if location is non-nil and location has been disabled, warn
        if self.currentLocation != nil {
            let status: CLAuthorizationStatus = CLLocationManager.authorizationStatus()
            if status == CLAuthorizationStatus.Denied {
                self.warnForLocationPermission()
            }
        }
        else {
            // can come here if location permission has already be requested, was initially denied then enabled through settings, but now doesn't start location
            locationManager.startUpdatingLocation()
        }
        
        self.appDelegate().refreshUser()
    }

    func warnForLocationPermission() {
        let message: String = "WeTrain needs GPS access to find trainers near you. Please go to your phone settings to enable location access. Go there now?"
        let alert: UIAlertController = UIAlertController(title: "Could not access location", message: message, preferredStyle: .Alert)
        alert.view.tintColor = UIColor.blackColor()
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Settings", style: .Default, handler: { (action) -> Void in
            UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
        }))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func warnAboutService(string: String?) {
        self.warnedAboutService = true
        var message = "Sorry, WeTrain is not available in your area. We currently service the Philadelphia area. Please stay tuned for more cities!"
        if string != nil {
            message = string!
        }
        self.simpleAlert("WeTrain unavailable", message: message)
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        mapView.settings.myLocationButton = true
        
        if status == .AuthorizedWhenInUse || status == .AuthorizedAlways {
            locationManager.startUpdatingLocation()
            mapView.myLocationEnabled = true
            mapView.settings.myLocationButton = true
        }
        else if status == .Denied {
            self.warnForLocationPermission()
            self.currentLocation = CLLocation(latitude: PHILADELPHIA_LAT, longitude: PHILADELPHIA_LON)
            print("Authorization is not available")
        }
        else {
            print("status unknown")
        }
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first as CLLocation? {
            locationManager.stopUpdatingLocation()
            self.currentLocation = location
            self.updateMapToCurrentLocation()
            
            if self.warnedAboutService == false {
                self.inServiceRange({ (inRange, message) -> Void in
                    if inRange == false && self.warnedAboutService == false {
                        self.warnAboutService(message)
                    }
                })
            }
        }
    }

    func updateMapToCurrentLocation() {
        var zoom = self.mapView.camera.zoom
        if zoom < 12 {
            zoom = 17
        }
        self.mapView.camera = GMSCameraPosition(target: self.currentLocation!.coordinate, zoom: zoom, bearing: 0, viewingAngle: 0)
    }
    
    func inServiceRange(completion:((Bool, message: String?) -> Void)) {
        // create a user flag instead of checking current location
        if PFUser.currentUser() == nil {
            completion(true, message: nil)
            return
        }
        
        let client: PFObject = PFUser.currentUser()!.objectForKey("client") as! PFObject
        do {
            try client.fetchIfNeeded()
        }
        catch _ {
            print("no")
            completion(true, message: nil)
            return
        }
        
        if self.currentLocation == nil {
            completion(false, message: "WeTrain could not determine your GPS location.")
            return
        }

        if let override: Bool = client.objectForKey("locationOverride") as? Bool {
            if override == true {
                completion(true, message: nil)
                return
            }
        }
        
        PFCloud.callFunctionInBackground("inServiceRange", withParameters: ["latitude": self.currentLocation!.coordinate.latitude, "longitude": self.currentLocation!.coordinate.longitude]) { (results, error) -> Void in
            if results != nil {
                completion(true, message: nil)
            }
            else {
                var message: String? = nil
                if error != nil {
                    if let msg: String = error!.userInfo["error"] as? String {
                        message = msg
                    }
                }
                completion(false, message: message)
            }
        }
    }
    
    // MARK: - GMSMapView  delegate
    func didTapMyLocationButtonForMapView(mapView: GMSMapView!) -> Bool {
        self.view.endEditing(true)

        if self.currentLocation != nil {
            let status: CLAuthorizationStatus = CLLocationManager.authorizationStatus()
            if status == CLAuthorizationStatus.Denied {
                self.warnForLocationPermission()
            }
            self.updateMapToCurrentLocation()
        }
        locationManager.startUpdatingLocation()
        return false
    }
    
    func mapView(mapView: GMSMapView!, idleAtCameraPosition position: GMSCameraPosition!) {
        self.currentLocation = CLLocation(latitude: position.target.latitude, longitude: position.target.longitude)
        let coder = CLGeocoder()
        coder.reverseGeocodeLocation(self.currentLocation!) { (results, error) -> Void in
            if error != nil {
                print("error: \(error!.userInfo)")
                self.simpleAlert("Could not find your current address", message: "Please reposition the map and try again")
            }
            else {
                print("result: \(results)")
                if let placemarks: [CLPlacemark]? = results as [CLPlacemark]? {
                    if let placemark: CLPlacemark = placemarks!.first as CLPlacemark! {
                        print("name \(placemark.name) address \(placemark.addressDictionary)")
                        if let dict: [String: AnyObject] = placemark.addressDictionary as? [String: AnyObject] {
                            if let lines = dict["FormattedAddressLines"] {
                                print("lines: \(lines)")
                                if lines.count > 0 {
                                    self.inputStreet.text = lines[0] as? String
                                }
                                if lines.count > 1 {
                                    self.inputCity.text = lines[1] as? String
                                }
                                else {
                                    self.inputCity.text = ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: Location search
    @IBAction func didClickSearch(button: UIButton) {
        let status: CLAuthorizationStatus = CLLocationManager.authorizationStatus()
        if status == CLAuthorizationStatus.Denied {
            self.warnForLocationPermission()
            return
        }

        let prompt = UIAlertController(title: "Enter Address", message: nil, preferredStyle: UIAlertControllerStyle.Alert)
        prompt.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: nil))
        prompt.addAction(UIAlertAction(title: "Search", style: .Default, handler: { (action) -> Void in
            self.searchForAddress()
        }))
        prompt.addTextFieldWithConfigurationHandler({(textField: UITextField!) in
            textField.placeholder = "Enter your address here"
            self.inputManualAddress = textField
        })
        self.presentViewController(prompt, animated: true, completion: nil)
    }
    
    func searchForAddress() {
        if self.inputManualAddress!.text == nil {
            return
        }
        
        let address: String = self.inputManualAddress!.text!
        print("address: \(address)")
        
        self.view.endEditing(true)
        
        let coder = CLGeocoder()
        coder.geocodeAddressString(address, completionHandler: { (results, error) -> Void in
            if error != nil {
                print("error: \(error!.userInfo)")
                self.simpleAlert("Could not find that location", message: "Please check your address and try again")
            }
            else {
                print("result: \(results)")
                if let placemarks: [CLPlacemark]? = results as [CLPlacemark]? {
                    if let placemark: CLPlacemark = placemarks!.first as CLPlacemark! {
                        self.currentLocation = CLLocation(latitude: placemark.location!.coordinate.latitude, longitude: placemark.location!.coordinate.longitude)
                        self.updateMapToCurrentLocation()
                    }
                }
            }
        })
    }
    
    // MARK: - TextFieldDelegate
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    // MARK: - request
    @IBAction func didClickRequest(sender: UIButton) {
        let status: CLAuthorizationStatus = CLLocationManager.authorizationStatus()
        if status == CLAuthorizationStatus.Denied {
            self.warnForLocationPermission()
            return
        }
        
        if PFUser.currentUser() == nil {
            let alert: UIAlertController = UIAlertController(title: "Please log in or sign up", message: "Before you start using WeTrain, you must create a user! Sign up now?", preferredStyle: UIAlertControllerStyle.Alert)
            alert.view.tintColor = UIColor.blackColor()
            alert.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.Cancel, handler: { (action) -> Void in
                print("cancel")
            }))
            alert.addAction(UIAlertAction(title: "Log in", style: UIAlertActionStyle.Default, handler: { (action) -> Void in
                self.login()
            }))
            alert.addAction(UIAlertAction(title: "Sign up", style: UIAlertActionStyle.Default, handler: { (action) -> Void in
                self.signup()
            }))
            self.presentViewController(alert, animated: true, completion: nil)
            return
        }

        self.inServiceRange { (inRange, message) -> Void in
            if !inRange {
                self.warnAboutService(message)
            }
            else {
                
                let client: PFObject = PFUser.currentUser()!.objectForKey("client") as! PFObject
                client.refreshInBackgroundWithBlock { (object, error) -> Void in
                    if client.objectForKey("firstName") == nil || client.objectForKey("lastName") == nil || client.objectForKey("phone") == nil || client.objectForKey("photo") == nil {
                        self.simpleAlert("Please complete profile", message: "You must add your name, phone, and photo before requesting a trainer so that they can contact you. Go to the Account tab edit your profile.")
                        return
                    }
                    if client.objectForKey("card") == nil {
                        self.simpleAlert("Please add a credit card", message: "You must add a credit card before requesting a trainer. Your card won't be charged until you and the trainer agree to start a workout.")
                        return
                    }
                    
                    if self.currentLocation != nil {
                        if self.inputStreet.text != nil && self.inputCity.text != nil {
                            let addressString = "\(self.inputStreet.text!) \(self.inputCity.text!)"
                            self.confirmRequestForAddress(addressString, coordinate: self.currentLocation!.coordinate)
                            return
                        }
                        let coder = GMSGeocoder()
                        coder.reverseGeocodeCoordinate(self.currentLocation!.coordinate, completionHandler: { (response, error) -> Void in
                            if let gmresponse:GMSReverseGeocodeResponse = response as GMSReverseGeocodeResponse! {
                                let results: [AnyObject] = gmresponse.results()
                                let addresses: [GMSAddress] = results as! [GMSAddress]
                                let address: GMSAddress = addresses.first!
                                
                                var addressString: String = ""
                                let lines: [String] = address.lines as! [String]
                                for line: String in lines {
                                    addressString = "\(addressString)\n\(line)"
                                }
                                print("Address: \(addressString)")
                                
                                self.confirmRequestForAddress(addressString, coordinate: address.coordinate)
                            }
                            else {
                                self.simpleAlert("Invalid location", message: "We could not request a session; your current location is invalid")
                            }
                        })
                    }
                    else {
                        self.simpleAlert("Invalid location", message: "We could not request a session; your current location was invalid")
                    }
                }
            }
        }
    }
    
    func confirmRequestForAddress(addressString: String, coordinate: CLLocationCoordinate2D) {
        var message: String = ""
        if self.requestedTrainingLength != nil {
            var coststr = "$17"
            if self.requestedTrainingLength! == 60 {
                coststr = "$25"
            }
            message = "\(self.requestedTrainingLength!)min / \(coststr)"
        }
        if self.requestedTrainingType != nil {
            let title = TRAINING_TITLES[self.requestedTrainingType!]
            message = "\(message)\n\(title)"
        }
        message = "\(message)\n\(addressString)\n\nYou will not be charged until you meet the trainer and your session starts."
        
        let alert: UIAlertController = UIAlertController(title: "Just to confirm", message: message, preferredStyle: UIAlertControllerStyle.Alert)
        alert.view.tintColor = UIColor.blackColor()
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: nil))
        alert.addAction(UIAlertAction(title: "Let's Go", style: UIAlertActionStyle.Default, handler: { (action) -> Void in
            print("requesting")
            self.initiateWorkoutRequest(addressString, coordinate: coordinate)
        }))
        self.presentViewController(alert, animated: true, completion: nil)
    }
        
    func initiateWorkoutRequest(addressString: String, coordinate: CLLocationCoordinate2D) {
        var dict: [String: AnyObject] = [String: AnyObject]()
        dict = ["time": NSDate(), "lat": Double(coordinate.latitude), "lon": Double(coordinate.longitude), "status":RequestState.Searching.rawValue, "address": addressString]
        
        let request: PFObject = PFObject(className: "Workout", dictionary: dict)
        let client: PFObject = PFUser.currentUser()!.objectForKey("client") as! PFObject
        let id = client.objectId
        print("client: \(client) \(id)")
        request.setObject(client, forKey: "client")
        if self.requestedTrainingType != nil {
            let title = TRAINING_TITLES[self.requestedTrainingType!]
            request.setObject(title, forKey: "type")
        }
        if self.requestedTrainingLength != nil {
            request.setObject(self.requestedTrainingLength!, forKey: "length")
        }
        if TESTING == 1 {
            request.setObject(true, forKey: "testing")
        }
        print("request: \(request)")
        request.saveInBackgroundWithBlock { (success, error) -> Void in
            print("saved: \(success)")
            client.setObject(request, forKey: "workout")
            client.saveInBackground()
            
            if success {
                self.currentRequest = request
                self.performSegueWithIdentifier("GoToRequestState", sender: nil)
                
                // subscribe to channel
                if request.objectId != nil {
                    let currentInstallation = PFInstallation.currentInstallation()
                    let requestId: String = request.objectId!
                    let channelName = "workout_\(requestId)"
                    currentInstallation.addUniqueObject(channelName, forKey: "channels")
                    currentInstallation.saveInBackgroundWithBlock({ (success, error) -> Void in
                        if success {
                            let channels = currentInstallation.objectForKey("channels")
                            print("installation registering while initiating: channel \(channels)")
                        }
                        else {
                            print("installation registering error:\(error)")
                        }
                    })
                }
            }
            else {
                var message = "There was an issue requesting a training session. Please try again."
                print("error: \(error)")
                self.simpleAlert("Could not request workout", defaultMessage: message, error: error)
            }
        }
    }
        
    // MARK: - Navigation
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "GoToRequestState" {
            let controller: RequestStatusViewController = segue.destinationViewController as! RequestStatusViewController
            controller.currentRequest = self.currentRequest
        }
        else if segue.identifier == "GoToViewTrainer" {
            let controller: TrainerProfileViewController = segue.destinationViewController as! TrainerProfileViewController
        }
    }
    
    // MARK: - Log in
    func login() {
        let controller: LoginViewController = UIStoryboard(name: "Login", bundle: nil).instantiateViewControllerWithIdentifier("LoginViewController") as! LoginViewController
        let nav = UINavigationController(rootViewController: controller)
        self.navigationController!.presentViewController(nav, animated: true, completion: nil)
    }

    func signup() {
        let controller: SignupViewController = UIStoryboard(name: "Login", bundle: nil).instantiateViewControllerWithIdentifier("SignupViewController") as! SignupViewController
        let nav = UINavigationController(rootViewController: controller)
        self.navigationController!.presentViewController(nav, animated: true, completion: nil)
    }
}

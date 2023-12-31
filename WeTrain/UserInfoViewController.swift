//
//  UserInfoViewController.swift
//  WeTrain
//
//  Created by Bobby Ren on 10/19/15.
//  Copyright © 2015 Bobby Ren. All rights reserved.
//

import UIKit
import Parse
import Photos

let genders = ["Select gender", "Male", "Female", "Other"]
class UserInfoViewController: UIViewController, UITextFieldDelegate, CreditCardDelegate, UIPickerViewDelegate, UIPickerViewDataSource, UIGestureRecognizerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var buttonPhotoView: UIButton!
    @IBOutlet weak var buttonEditPhoto: UIButton!
    
    @IBOutlet var inputFirstName: UITextField!
    @IBOutlet var inputLastName: UITextField!
    @IBOutlet var inputPhone: UITextField!
    @IBOutlet var inputGender: UITextField!
    @IBOutlet var inputAge: UITextField!
    @IBOutlet var inputInjuries: UITextField!
    @IBOutlet var inputCreditCard: UITextField!
    
    var currentInput: UITextField?
    
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var viewScrollContent: UIView!
    @IBOutlet var constraintContentWidth: NSLayoutConstraint!
    @IBOutlet var constraintContentHeight: NSLayoutConstraint!
    
    @IBOutlet var constraintTopOffset: NSLayoutConstraint!
    @IBOutlet var constraintBottomOffset: NSLayoutConstraint!
    
    var isSignup:Bool = false
    var selectedPhoto: UIImage?
    
    var client: PFObject?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .Done, target: self, action: "didUpdateInfo:")
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
        
        let picker = UIPickerView()
        picker.delegate = self
        picker.dataSource = self
        self.inputGender.inputView = picker

        let keyboardDoneButtonView: UIToolbar = UIToolbar()
        keyboardDoneButtonView.sizeToFit()
        keyboardDoneButtonView.barStyle = UIBarStyle.Black
        keyboardDoneButtonView.tintColor = UIColor.whiteColor()
        let button: UIBarButtonItem = UIBarButtonItem(title: "Next", style: UIBarButtonItemStyle.Done, target: self, action: "dismissKeyboard")
        let flex: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FlexibleSpace, target: nil, action: nil)
        keyboardDoneButtonView.setItems([flex, button], animated: true)
        self.inputGender.inputAccessoryView = keyboardDoneButtonView
        self.inputPhone.inputAccessoryView = keyboardDoneButtonView
        self.inputAge.inputAccessoryView = keyboardDoneButtonView
        
        let tap = UITapGestureRecognizer(target: self, action: "handleGesture:")
        tap.delegate = self
        self.viewScrollContent.addGestureRecognizer(tap)
        let tap2 = UITapGestureRecognizer(target: self, action: "handleGesture:")
        self.view.addGestureRecognizer(tap2)

        if self.isSignup {
            let left: UIBarButtonItem = UIBarButtonItem(title: "", style: .Done, target: self, action: "nothing")
            self.navigationItem.leftBarButtonItem = left
        }
        
        let clientObject: PFObject = PFUser.currentUser()!.objectForKey("client") as! PFObject
        clientObject.fetchInBackgroundWithBlock({ (result, error) -> Void in
            self.client = clientObject
            if result != nil {
                if let file = self.client!.objectForKey("photo") as? PFFile {
                    file.getDataInBackgroundWithBlock { (data, error) -> Void in
                        if data != nil {
                            let photo: UIImage = UIImage(data: data!)!
                            self.buttonPhotoView.setImage(photo, forState: .Normal)
                            self.buttonPhotoView.layer.cornerRadius = self.buttonPhotoView.frame.size.width / 2
                            
                            self.buttonEditPhoto.setTitle("Edit photo", forState: .Normal)
                            self.selectedPhoto = photo
                        }
                    }
                }
                
                // populate all info
                if let firstName = self.client!.objectForKey("firstName") as? String {
                    print("first: \(firstName)")
                    self.inputFirstName.text = firstName
                }
                if let lastName = self.client!.objectForKey("lastName") as? String {
                    self.inputLastName.text = lastName
                }
                if let phone = self.client!.objectForKey("phone") as? String {
                    self.inputPhone.text = phone
                }
                if let age = self.client!.objectForKey("age") as? String {
                    self.inputAge.text = age
                }
                if let gender = self.client!.objectForKey("gender") as? String {
                    self.inputGender.text = gender
                }
                if let injuries = self.client!.objectForKey("injuries") as? String {
                    self.inputInjuries.text = injuries
                }
                if let last4: String = self.client!.objectForKey("stripeFour") as? String{
                    self.inputCreditCard.text = "Credit Card: *\(last4)"
                }
            }
            else {
                // user's client was deleted; create a new one
                self.client! = PFObject(className: "Client")
                PFUser.currentUser()!.setObject(self.client!, forKey: "client")
                PFUser.currentUser()!.saveInBackground()
            }
        })
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.constraintContentWidth.constant = (self.appDelegate().window?.bounds.size.width)!
        self.constraintContentHeight.constant = self.inputCreditCard.frame.origin.y + self.inputCreditCard.frame.size.height + 40
    }
    
    func nothing() {
        // hides left button
    }

    func dismissKeyboard() {
        if self.currentInput! == self.inputPhone {
            self.inputGender.becomeFirstResponder()
        }
        else if self.currentInput! == self.inputGender {
            self.inputAge.becomeFirstResponder()
        }
        else if self.currentInput! == self.inputAge {
            self.inputInjuries.becomeFirstResponder()
        }
        else {
            self.view.endEditing(true)
        }
    }
    
    func handleGesture(sender: UIGestureRecognizer) {
        if sender.isKindOfClass(UITapGestureRecognizer) {
            self.view.endEditing(true)
        }
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        if gestureRecognizer.isKindOfClass(UITapGestureRecognizer) {
            let location: CGPoint = touch.locationInView(self.viewScrollContent)
            for input: UIView in [self.inputFirstName, self.inputLastName, self.inputPhone, self.inputGender, self.inputAge, self.inputInjuries, self.inputCreditCard] {
                if CGRectContainsPoint(input.frame, location) {
                    return false
                }
            }
        }
        return true
    }

    func didUpdateInfo(sender: AnyObject) {

        if TESTING == 0 {
            let firstName = self.inputFirstName.text
            if firstName?.characters.count == 0 {
                self.simpleAlert("Please enter your first name", message: nil)
                return
            }
            let lastName = self.inputLastName.text
            if lastName?.characters.count == 0 {
                self.simpleAlert("Please enter your last name", message: nil)
                return
            }
            
            let phone = self.inputPhone.text
            if phone?.characters.count == 0 {
                self.simpleAlert("Please enter a valid phone number", message: nil)
                return
            }
        
            /*
            if self.isSignup && self.selectedPhoto == nil {
            self.simpleAlert("Please select a photo", message: "You must add a photo so your trainer can recognize you.")
            return
            }
            */
        }

        /*
        let gender = self.inputGender.text
        if gender?.characters.count == 0 {
        self.simpleAlert("Please enter your gender", message: nil)
        return
        }
        
        let age = self.inputAge.text
        if age?.characters.count == 0 {
        self.simpleAlert("Please enter your age", message: nil)
        return
        }
        */

        /*
        let four = self.inputCreditCard.text
        if four?.characters.count == 0 {
            let alert: UIAlertController = UIAlertController(title: "Skip payment method?", message: "Are you sure you want to complete signup without adding your credit card? You won't be able to request a workout. You can add a credit card later.", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "Continue signup", style: .Default, handler: { (action) -> Void in
                self.updateClientProfile()
            }))
            alert.addAction(UIAlertAction(title: "Add payment", style: .Cancel, handler: { (action) -> Void in
                self.inputCreditCard.becomeFirstResponder()
            }))
            self.presentViewController(alert, animated: true, completion: nil)
        }
        else {
            self.updateClientProfile()
        }
        */
        self.updateClientProfile()
    }
    

    func updateClientProfile() {
        // update profile information
        var clientDict: [String: AnyObject] = ["firstName": self.inputFirstName.text!, "phone": self.inputPhone.text!];
        if self.inputLastName.text != nil {
            clientDict["lastName"] = self.inputLastName.text!
        }
        if self.inputAge.text != nil {
            clientDict["age"] = self.inputAge.text!
        }
        if self.inputGender.text != nil {
            clientDict["gender"] = self.inputGender.text!
        }
        if self.inputInjuries.text != nil {
            clientDict["injuries"] = self.inputInjuries.text!
        }
        
        self.client!.setValuesForKeysWithDictionary(clientDict)
        let user = PFUser.currentUser()!
        self.client!.setObject(user, forKey: "user")
        
        if self.selectedPhoto != nil {
            let data: NSData = UIImageJPEGRepresentation(self.selectedPhoto!, 0.8)!
            let file: PFFile = PFFile(name: "profile.jpg", data: data)!
            self.client!.setObject(file, forKey: "photo")
        }
        
        self.client!.saveInBackgroundWithBlock { (success, error) -> Void in
            if error != nil {
                var message = "We could not create your user profile."
                self.simpleAlert("Error creating profile", defaultMessage: message, error: error)
                return
            }
            else {
                print("signup succeeded")
                if self.isSignup {
                    self.navigationController!.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
                }
                else {
                    self.navigationController!.popToRootViewControllerAnimated(true)
                }
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - keyboard notifications
    func keyboardWillShow(n: NSNotification) {
        let size = n.userInfo![UIKeyboardFrameBeginUserInfoKey]?.CGRectValue.size
        
        //        self.constraintTopOffset.constant = -size!.height
        self.constraintBottomOffset.constant = size!.height
        //self.view.layoutIfNeeded()
    }
    
    func keyboardWillHide(n: NSNotification) {
        self.constraintTopOffset.constant = 0
        self.constraintBottomOffset.constant = 0
        
        self.view.layoutIfNeeded()
    }
    
    // MARK: - TextFieldDelegate
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if textField == self.inputFirstName {
            self.inputLastName.becomeFirstResponder()
        }
        else if textField == self.inputLastName {
            self.inputPhone.becomeFirstResponder()
        }
        else if textField == self.inputPhone {
            self.inputGender.becomeFirstResponder()
        }
        else if textField == self.inputGender {
            self.inputAge.becomeFirstResponder()
        }
        else if textField == self.inputAge {
            self.inputInjuries.becomeFirstResponder()
        }
        else {
            textField.resignFirstResponder()
        }
        return true
    }
    
    func textFieldShouldBeginEditing(textField: UITextField) -> Bool {
        if textField == self.inputCreditCard {
            self.view.endEditing(true)
            self.goToCreditCard()
            return false
        }
        self.currentInput = textField

        return true
    }
    
    func goToCreditCard() {
        let nav = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("CreditCardNavigationController") as! UINavigationController
        let controller: CreditCardViewController = nav.viewControllers[0] as! CreditCardViewController
        controller.delegate = self
        
        self.presentViewController(nav, animated: true) { () -> Void in
        }
    }
    
    // MARK: - CreditCardDelegate
    func didSaveCreditCard(token: String, lastFour: String) {
        // actually save credit card
        PFCloud.callFunctionInBackground("updatePayment", withParameters: ["clientId": self.client!.objectId!, "stripeToken": token]) { (results, error) -> Void in
            if error == nil {
                self.inputCreditCard.text = "Credit Card: *\(lastFour)"
                self.client!.setObject(lastFour, forKey: "stripeFour")
                self.client!.saveInBackground()
            }
            else {
                self.simpleAlert("Could not save credit card", defaultMessage: "There was an error updating your credit card.", error: error)
            }
        }
    }
    
    // MARK: - UIPickerViewDelegate
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 4 // select, MFO
    }
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        print("row: \(row)")
        print("genders \(genders)")
        return genders[row]
    }
    
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if row == 0 {
            self.inputGender.text = nil
        }
        self.inputGender.text = genders[row]
    }
    
    // MARK: - Photo
    @IBAction func didClickAddPhoto(sender: UIButton) {
        let picker: UIImagePickerController = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        alert.view.tintColor = UIColor.blackColor()
        if UIImagePickerController.isSourceTypeAvailable(.Camera) {
            alert.addAction(UIAlertAction(title: "Camera", style: .Default, handler: { (action) -> Void in
                let cameraStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
                if cameraStatus == .Denied {
                    self.warnForCameraAccess()
                }
                else {
                    // go to camera
                    picker.sourceType = .Camera
                    self.presentViewController(picker, animated: true, completion: nil)
                }
            }))
        }
        alert.addAction(UIAlertAction(title: "Photo library", style: .Default, handler: { (action) -> Void in
            let libraryStatus = PHPhotoLibrary.authorizationStatus()
            if libraryStatus == .Denied {
                self.warnForLibraryAccess()
            }
            else {
                // go to library
                picker.sourceType = .PhotoLibrary
                self.presentViewController(picker, animated: true, completion: nil)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func warnForLibraryAccess() {
        let message: String = "WeTrain needs photo library access to load your profile picture. Would you like to go to your phone settings to enable the photo library?"
        let alert: UIAlertController = UIAlertController(title: "Could not access photos", message: message, preferredStyle: .Alert)
        alert.view.tintColor = UIColor.blackColor()
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Settings", style: .Default, handler: { (action) -> Void in
            UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
        }))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func warnForCameraAccess() {
        let message: String = "WeTrain needs camera access to take your profile photo. Would you like to go to your phone settings to enable the camera?"
        let alert: UIAlertController = UIAlertController(title: "Could not access camera", message: message, preferredStyle: .Alert)
        alert.view.tintColor = UIColor.blackColor()
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Settings", style: .Default, handler: { (action) -> Void in
            UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
        }))
        self.presentViewController(alert, animated: true, completion: nil)
    }

    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage, editingInfo: [String : AnyObject]?) {
        self.buttonPhotoView.setImage(image, forState: .Normal)
        self.buttonEditPhoto.setTitle("Edit photo", forState: .Normal)
        self.selectedPhoto = image
        picker.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        picker.dismissViewControllerAnimated(true, completion: nil)
    }
    // MARK: - Navigation
    
}

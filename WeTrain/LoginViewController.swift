//
//  LoginViewController.swift
//  WeTrain
//
//  Created by Bobby Ren on 8/2/15.
//  Copyright (c) 2015 Bobby Ren. All rights reserved.
//

import UIKit
import Parse

class LoginViewController: UIViewController, UITextFieldDelegate, UIScrollViewDelegate {

    @IBOutlet var inputLogin: UITextField!
    @IBOutlet var inputPassword: UITextField!
    @IBOutlet var buttonLogin: UIButton!
    @IBOutlet var buttonSignup: UIButton!
    
    @IBOutlet weak var tutorialView: TutorialScrollView!
    var tutorialCreated: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.reset()
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func reset() {
        self.inputPassword.text = nil;

        self.inputLogin.superview!.layer.borderWidth = 1;
        self.inputLogin.superview!.layer.borderColor = UIColor.lightGrayColor().CGColor;
        self.inputPassword.superview!.layer.borderWidth = 1;
        self.inputPassword.superview!.layer.borderColor = UIColor.lightGrayColor().CGColor;
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if PFUser.currentUser() == nil {
            if !self.tutorialCreated {
                self.tutorialView.setTutorialPages(["IntroTutorial0", "IntroTutorial1", "IntroTutorial2", "IntroTutorial3", "IntroTutorial4"])
                self.tutorialCreated = true
            }
        }
    }
    
    @IBAction func didClickLogin(sender: UIButton) {
        if self.inputLogin.text?.characters.count == 0 {
            self.simpleAlert("Please enter a login email", message: nil)
            return
        }
        if self.inputPassword.text?.characters.count == 0 {
            self.simpleAlert("Please enter a password", message: nil)
            return
        }
        
        let username: String = self.inputLogin.text!
        let password: String = self.inputPassword.text!
        PFUser.logInWithUsernameInBackground(username, password: password) { (user, error) -> Void in
            print("logged in")
            if user != nil {
                self.loggedIn()
            }
            else {
                let title = "Login error"
                var message: String?
                if error?.code == 100 {
                    message = "Please check your internet connection"
                }
                else if error?.code == 101 {
                    message = "Invalid email or password"
                }
                
                self.simpleAlert(title, message: message)
            }
        }
    }
    
    @IBAction func didClickSignup(sender: UIButton) {
        self.performSegueWithIdentifier("GoToSignup", sender: nil)
    }
    
    func loggedIn() {
        self.appDelegate().didLogin()
    }
    
    // MARK: - TextFieldDelegate
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

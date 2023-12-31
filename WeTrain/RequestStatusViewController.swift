//
//  RequestStatusViewController.swift
//  WeTrain
//
//  Created by Bobby Ren on 8/17/15.
//  Copyright (c) 2015 Bobby Ren. All rights reserved.
//

import UIKit
import Parse

typealias RequestStatusButtonHandler = () -> Void

class RequestStatusViewController: UIViewController {

    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelMessage: UILabel!
    @IBOutlet weak var buttonTop: UIButton!
    @IBOutlet weak var buttonBottom: UIButton!
    
    @IBOutlet weak var imageViewBG: UIImageView!
    
    @IBOutlet weak var constraintDetailsHeight: NSLayoutConstraint!
    
    @IBOutlet weak var progressView: ProgressView!
    
    var state: RequestState = .NoRequest
    var currentRequest: PFObject?
    var currentTrainer: PFObject?
    
    var timer: NSTimer?

    var topButtonHandler: RequestStatusButtonHandler? = nil
    var bottomButtonHandler: RequestStatusButtonHandler? = nil
    
    var trainerController: TrainerProfileViewController? = nil
    var goingToTrainer: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        let index = arc4random_uniform(3)+1
        self.imageViewBG.image = UIImage(named: "bg_workout\(index)")!

        if let previousState: String = self.currentRequest?.objectForKey("status") as? String{
            let newState: RequestState = RequestState(rawValue: previousState)!
            if newState == RequestState.Matched || newState == RequestState.Training {
                self.goToTrainerInfo()
                return
            }
            else {
                self.updateRequestState()
                
                if !self.hasPushEnabled() {
                    self.registerForRemoteNotifications()
                }
                else {
                    if newState == RequestState.Searching {
                        if self.currentRequest!.objectId != nil {
                            let currentInstallation = PFInstallation.currentInstallation()
                            let requestId: String = self.currentRequest!.objectId!
                            let channelName = "workout_\(requestId)"
                            currentInstallation.addUniqueObject(channelName, forKey: "channels")
                            currentInstallation.saveInBackgroundWithBlock({ (success, error) -> Void in
                                if success {
                                    let channels = currentInstallation.objectForKey("channels")
                                    print("installation registering while searching: channel \(channels)")
                                }
                                else {
                                    print("installation registering error:\(error)")
                                }
                            })
                        }
                    }
                }
            }
        }
        
        if self.timer == nil {
            self.timer = NSTimer.scheduledTimerWithTimeInterval(10, target: self, selector: "updateRequestState", userInfo: nil, repeats: true)
            self.timer?.fire()
        }
        
        self.labelTitle.hidden = true
        self.labelMessage.hidden = true

        self.setTitleBarColor(UIColor.blackColor(), tintColor: UIColor.whiteColor())
        self.navigationController!.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName:UIColor.whiteColor()]
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "", style: UIBarButtonItemStyle.Done, target: self, action: "nothing")
    }
    
    func nothing() {
        // do nothing
    }
    
    @IBAction func didClickButton(sender: UIButton) {
        if sender == buttonTop {
            print("top button")
            if self.topButtonHandler != nil {
                self.topButtonHandler!()
            }
        }
        else if sender == buttonBottom {
            print("bottom button")
            if self.bottomButtonHandler != nil {
                self.bottomButtonHandler!()
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func updateRequestState() {
        let client: PFObject = PFUser.currentUser()!.objectForKey("client") as! PFObject
        if let request: PFObject = client.objectForKey("workout") as? PFObject {
            request.fetchInBackgroundWithBlock({ (object, error) -> Void in
                self.currentRequest = object
                if self.currentRequest == nil {
                    // if request is still nil, then it got cancelled/deleted somehow.
                    self.toggleRequestState(.NoRequest)
                    return
                }
                
                if let previousState: String = self.currentRequest!.objectForKey("status") as? String{
                    let newState: RequestState = RequestState(rawValue: previousState)!
                    
                    if let trainer: PFObject = request.objectForKey("trainer") as? PFObject {
                        trainer.fetchInBackgroundWithBlock({ (object, error) -> Void in
                            print("trainer: \(object) newState: \(newState.rawValue)")
                            self.currentTrainer = trainer
                            self.toggleRequestState(newState)
                        })
                    }
                    else {
                        self.toggleRequestState(newState)
                    }
                }
            })
        }
    }

    func updateTitle(title: String, message: String, top: String?, bottom: String, topHandler: RequestStatusButtonHandler?, bottomHandler: RequestStatusButtonHandler) {
        self.labelTitle.text = title
        self.labelMessage.text = message

        self.labelTitle.hidden = false
        self.labelMessage.hidden = false

        let string:NSString = self.labelMessage.text! as NSString
        let bounds = CGSizeMake(self.labelMessage.frame.size.width, 500)
        let rect = string.boundingRectWithSize(bounds, options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: [NSFontAttributeName:self.labelMessage.font], context:nil)
        self.constraintDetailsHeight.constant = rect.size.height;

        self.labelMessage.superview!.layoutSubviews()
        
        if top == nil {
            self.buttonTop.hidden = true
        }
        else {
            self.buttonTop.hidden = false
            self.buttonTop.setTitle(top!, forState: .Normal)
        }
        
        self.buttonBottom.setTitle(bottom, forState: .Normal)
        
        self.topButtonHandler = topHandler
        self.bottomButtonHandler = bottomHandler
    }
    
    
    func toggleRequestState(newState: RequestState) {
        self.state = newState
        print("going to state \(newState.rawValue)")
        
        switch self.state {
        case .NoRequest:
            let title = "No current workout"
            let message = "You're not currently in a workout or waiting for a trainer. Please click OK to go back to the training menu."
            self.updateTitle(title, message: message, top: nil, bottom: "Close", topHandler: nil, bottomHandler: { () -> Void in
                // dismiss the current stack and go back
                self.navigationController!.popToRootViewControllerAnimated(true)
            })
            
            if self.timer != nil {
                self.timer!.invalidate()
                self.timer = nil
            }
            self.progressView.stopActivity()
        case .Cancelled:
            // request state is set to .NoRequest if cancelled from an app action.
            // "cancelled" state is set on the web in order to trigger this state
            let title = "Search was cancelled"
            var message: String? = self.currentRequest!.objectForKey("cancelReason") as? String
            if message == nil {
                message = "You have cancelled the training session. You have not been charged for this training session since no trainer was matched. Please click OK to go back to the training menu."
            }
            
            self.unsubscribeToCurrentRequestChannel()

            self.currentRequest = nil
            self.updateTitle(title, message: message!, top: nil, bottom: "OK", topHandler: nil, bottomHandler: { () -> Void in
                // dismiss the current stack and go back
                self.navigationController!.popToRootViewControllerAnimated(true)
            })
            
            if self.timer != nil {
                self.timer!.invalidate()
                self.timer = nil
            }
            self.progressView.stopActivity()
        case .Searching:
            
            var title = "Searching for an available trainer"
            var message = "Please be patient; this may take a few minutes. If you close the app, we will notify you once a trainer has been matched!"
            if let addressString: String = self.currentRequest?.objectForKey("address") as? String {
                title = "Searching for an available trainer near:"
                message = "\(addressString)\n\n\(message)"
            }
            self.updateTitle(title, message: message, top: nil, bottom: "Cancel Request", topHandler: nil, bottomHandler: { () -> Void in
                self.promptForCancel()
            })
            self.progressView.startActivity()
        case .Matched:
            let title = "Trainer found"
            let message = "You have been matched with a trainer!"
            self.updateTitle(title, message: message, top: nil, bottom: "Cancel Request", topHandler: nil, bottomHandler: { () -> Void in
            })
            self.goToTrainerInfo()
            if self.timer != nil {
                self.timer!.invalidate()
                self.timer = nil
            }
            self.progressView.stopActivity()
            
            self.unsubscribeToCurrentRequestChannel()

        case .Training:
            let title = "Training in session"
            let message = ""
            self.updateTitle(title, message: message, top: nil, bottom: "Cancel Request", topHandler: nil, bottomHandler: { () -> Void in
            })
            self.goToTrainerInfo()
            if self.timer != nil {
                self.timer!.invalidate()
                self.timer = nil
            }
            self.progressView.stopActivity()

            self.unsubscribeToCurrentRequestChannel()

        default:
            break
        }
    }

    func goToTrainerInfo() {
        if self.trainerController != nil || self.goingToTrainer {
            return
        }
        self.goingToTrainer = true
        print("display info")
        if let trainer: PFObject = self.currentRequest!.objectForKey("trainer") as? PFObject {
            trainer.fetchInBackgroundWithBlock({ (object, error) -> Void in
                print("trainer: \(object)")
                self.currentTrainer = trainer
                self.performSegueWithIdentifier("GoToViewTrainer", sender: nil)
            })
        }
    }
    
    func promptForCancel() {
        let alert = UIAlertController(title: "Cancel request?", message: "Are you sure you want to cancel your training request?", preferredStyle: .Alert)
        alert.view.tintColor = UIColor.blackColor()
        alert.addAction(UIAlertAction(title: "Cancel training", style: .Cancel, handler: { (action) -> Void in
            if self.currentRequest != nil {
                self.currentRequest!.setObject(RequestState.Cancelled.rawValue, forKey: "status")
                self.currentRequest!.saveInBackgroundWithBlock({ (success, error) -> Void in
                    self.toggleRequestState(RequestState.Cancelled)
                })
            }
        }))
        alert.addAction(UIAlertAction(title: "Keep waiting", style: .Default, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "GoToViewTrainer" {
            let controller: TrainerProfileViewController = segue.destinationViewController as! TrainerProfileViewController
            controller.request = self.currentRequest
            controller.trainer = self.currentTrainer
            
            self.trainerController = controller
        }
    }
    
    // push
    func hasPushEnabled() -> Bool {
        if !UIApplication.sharedApplication().isRegisteredForRemoteNotifications() {
            return false
        }
        let settings = UIApplication.sharedApplication().currentUserNotificationSettings()
        if (settings?.types.contains(.Alert) == true){
            return true
        }
        else {
            return false
        }
    }
    
    func registerForRemoteNotifications() {
        let alert = UIAlertController(title: "Enable push notifications?", message: "To receive notifications you must enable push. In the next popup, please click Yes.", preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { (action) -> Void in
            let settings = UIUserNotificationSettings(forTypes: [.Alert, .Badge, .Sound], categories: nil)
            UIApplication.sharedApplication().registerUserNotificationSettings(settings)
            UIApplication.sharedApplication().registerForRemoteNotifications()
        }))
        self.presentViewController(alert, animated: true, completion: nil)
    }

    func warnForRemoteNotificationRegistrationFailure() {
        let alert = UIAlertController(title: "Change notification settings?", message: "Push notifications are disabled, so you can't receive notifications from trainers. Would you like to go to the Settings to update them?", preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Settings", style: .Default, handler: { (action) -> Void in
            print("go to settings")
            UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
        }))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func unsubscribeToCurrentRequestChannel() {
        if self.currentRequest != nil && self.currentRequest!.objectId != nil {
            let currentInstallation = PFInstallation.currentInstallation()
            let requestId: String = self.currentRequest!.objectId!
            let channelName = "workout_\(requestId)"
            currentInstallation.removeObject(channelName, forKey: "channels")
            currentInstallation.saveInBackground()
        }
    }
    
}

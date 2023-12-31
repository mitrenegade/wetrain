//
//  AppDelegate.swift
//  WeTrain
//
//  Created by Bobby Ren on 7/31/15.
//  Copyright (c) 2015 Bobby Ren. All rights reserved.
//

import UIKit
import CoreData
import Parse
import Bolts
import Fabric
import Crashlytics
import GoogleMaps
import Stripe

@UIApplicationMain

class AppDelegate: UIResponder, UIApplicationDelegate, TutorialDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        Parse.enableLocalDatastore()

        if TESTING == 0 {
            Parse.setApplicationId(PARSE_APP_ID_PROD, clientKey: PARSE_CLIENT_KEY_PROD)
            Stripe.setDefaultPublishableKey(STRIPE_PUBLISHABLE_KEY_PROD)
        }
        else {
            Parse.setApplicationId(PARSE_APP_ID_DEV, clientKey: PARSE_CLIENT_KEY_DEV)
            Stripe.setDefaultPublishableKey(STRIPE_PUBLISHABLE_KEY_DEV)
        }
        
        // [Optional] Track statistics around application opens.
        PFAnalytics.trackAppOpenedWithLaunchOptions(launchOptions)
        
        Fabric.with([Crashlytics.self])
        
        // google maps
        GMSServices.provideAPIKey(GOOGLE_API_APP_KEY)

        // reregister for relevant channels
        if UIApplication.sharedApplication().isRegisteredForRemoteNotifications() {
            let settings = UIUserNotificationSettings(forTypes: [.Alert, .Badge, .Sound], categories: nil)
            UIApplication.sharedApplication().registerUserNotificationSettings(settings)
            UIApplication.sharedApplication().registerForRemoteNotifications()
        }

        UITabBar.appearance().tintColor = UIColor.redColor()
        UITabBar.appearance().selectedImageTintColor = UIColor.orangeColor()
        UITabBar.appearance().shadowImage = nil
        UITabBar.appearance().barTintColor = UIColor.blackColor()
        
        // delay for 0.5 seconds
        let time = dispatch_time(DISPATCH_TIME_NOW, Int64(1.5 * Double(NSEC_PER_SEC)))
        dispatch_after(time, dispatch_get_main_queue()) { () -> Void in
            if NSUserDefaults.standardUserDefaults().boolForKey("tutorial:seen") {
                self.goToMain()
            }
            else {
                self.goToTutorial()
            }
        }
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        self.refreshUser()
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }

    // MARK: - Core Data stack
    
    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "tech.bobbyren.TestCoreData" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1] as! NSURL
        }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource("Model", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
        }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("WeTrain.sqlite")
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            
            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            abort()
        }
        
        return coordinator
        }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
        }()
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }
    
    func refreshUser() {
        if PFUser.currentUser() == nil {
            if let cachedUsername: String = NSUserDefaults.standardUserDefaults().objectForKey("username:cached") as? String {
                if let cachedPassword: String = NSUserDefaults.standardUserDefaults().objectForKey("password:cached") as? String {
                    // HACK: load cached username and password and log user in. This is to fix a Parse bug (?) that PFUser.currentUser does not persist across app updates
                    PFUser.logInWithUsernameInBackground(cachedUsername, password: cachedPassword) { (user, error) -> Void in
                        self.refreshUser()
                    }
                    return
                }
            }
        }
        PFUser.currentUser()?.fetchInBackgroundWithBlock({ (user: PFObject?, error) -> Void in
            if error != nil {
                if let userInfo: [NSObject: AnyObject] = error!.userInfo {
                    let code = userInfo["code"] as! Int
                    print("code: \(code)")
                    
                    // if code == 209, invalid token; just display login
                    self.invalidLogin()
                }
            }
            else {
                if user != nil {
                    do {
                        try user!.pin()
                    } catch {
                        
                    }
                }

                if PFUser.currentUser()!.objectForKey("username") != nil {
                    let email: String = PFUser.currentUser()!.objectForKey("username") as! String
                    Crashlytics.sharedInstance().setUserEmail(email)
                }
                
                if PFUser.currentUser()!.objectId != nil {
                    Crashlytics.sharedInstance().setUserIdentifier(PFUser.currentUser()!.objectId)
                }

                if let client: PFObject = user!.objectForKey("client") as? PFObject {
                    client.fetchInBackgroundWithBlock({ (object, error) -> Void in
                        if object != nil {
                            var name: String = ""
                            if client.objectForKey("firstName") != nil {
                                let firstName: String = client.objectForKey("firstName") as! String
                                if firstName != "" {
                                    name = "\(firstName)"
                                }
                            }
                            if client.objectForKey("lastName") != nil {
                                let lastName: String = client.objectForKey("lastName") as! String
                                if lastName != "" {
                                    if name != "" {
                                        name = "\(name) \(lastName))"
                                    }
                                    else {
                                        name = lastName
                                    }
                                }
                            }
                            if name != "" {
                                Crashlytics.sharedInstance().setUserName(name)
                            }
                        }
                    })
                }
            }
        })
    }

    func goToMain() {
        let controller: UIViewController?  = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("MainTabController") as UIViewController?
        self.window!.rootViewController?.dismissViewControllerAnimated(true, completion: nil)
        self.window!.rootViewController?.presentViewController(controller!, animated: true, completion: nil)
    }
    
    func goToTutorial() {
        let nav: UINavigationController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("TutorialNavigationController") as! UINavigationController
        let controller: TutorialViewController = nav.viewControllers[0] as! TutorialViewController
        controller.delegate = self
        self.window!.rootViewController?.presentViewController(nav, animated: true, completion: nil)
    }
    
    // MARK: - TutorialDelegate
    func didCloseTutorial() {
        self.refreshUser()
        self.goToMain()
    }
    
    func createClient() {
        let client: PFObject = PFObject(className: "Client")
        client.setObject(false, forKey: "checkedTOS")
        client.saveInBackgroundWithBlock({ (success, error) -> Void in
            PFUser.currentUser()!.setObject(client, forKey: "client")
            PFUser.currentUser()!.saveInBackgroundWithBlock({ (success, error) -> Void in
                if success {
                    self.goToMain()
                }
                else {
                    self.invalidLogin()
                }
            })
        })
    }
    
    func promptToCompleteSignup() {
        let alert: UIAlertController = UIAlertController(title: "Complete signup", message: "You have not finished creating your account. Would you like to do that now?", preferredStyle: .Alert)
        alert.view.tintColor = UIColor.blackColor()
        alert.addAction(UIAlertAction(title: "Setup account", style: .Default, handler: { (action) -> Void in
            self.goToUserProfile()
        }))
        alert.addAction(UIAlertAction(title: "Logout", style: .Default, handler: { (action) -> Void in
            self.logout()
        }))
        if self.window?.rootViewController?.presentedViewController != nil {
            self.window?.rootViewController?.presentedViewController?.presentViewController(alert, animated: true, completion: nil)
        }
        else {
            self.window?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    func goToLogin() {
        let controller: LoginViewController  = UIStoryboard(name: "Login", bundle: nil).instantiateViewControllerWithIdentifier("LoginViewController") as! LoginViewController
        self.window!.rootViewController?.dismissViewControllerAnimated(true, completion: nil)
        self.window!.rootViewController?.presentViewController(controller, animated: true, completion: nil)
    }
    
    func goToUserProfile() {
        let controller: UserInfoViewController = UIStoryboard(name: "Login", bundle: nil).instantiateViewControllerWithIdentifier("UserInfoViewController") as! UserInfoViewController
        controller.isSignup = true
        let nav: UINavigationController = UINavigationController(rootViewController: controller)
        self.window!.rootViewController?.dismissViewControllerAnimated(true, completion: nil)
        self.window!.rootViewController?.presentViewController(nav, animated: true, completion: nil)
        let frame = controller.view.frame
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Logout", style: UIBarButtonItemStyle.Plain, target: self, action: "logout")
    }
    
    func logout() {
        NSUserDefaults.standardUserDefaults().removeObjectForKey("username:cached")
        NSUserDefaults.standardUserDefaults().removeObjectForKey("password:cached")
        NSUserDefaults.standardUserDefaults().synchronize()

        if PFUser.currentUser() != nil {
            do {
                try PFUser.currentUser()!.unpin()
            } catch {
                
            }
        }

        
        PFUser.logOutInBackgroundWithBlock { (error) -> Void in
            self.goToLogin()
        }
    }
    
    func invalidLogin() {
        let alert = UIViewController.simpleAlert("Invalid user", message: "We could not log you in.", completion: { () -> Void in
            self.logout()
        })
        self.window?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
    }

    /// MARK: - Push
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        // Store the deviceToken in the current Installation and save it to Parse
        NSNotificationCenter.defaultCenter().postNotificationName("push:enabled", object: nil)
        let installation = PFInstallation.currentInstallation()
        installation.setDeviceTokenFromData(deviceToken)
        installation.addUniqueObject("Clients", forKey: "channels") // subscribe to trainers channel
        installation.saveInBackground()
        let channels = installation.objectForKey("channels")
        print("installation registered for remote notifications: token \(deviceToken) channel \(channels)")
    }
    
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        print("failed: error \(error)")
        NSNotificationCenter.defaultCenter().postNotificationName("push:enable:failed", object: nil)
    }
}
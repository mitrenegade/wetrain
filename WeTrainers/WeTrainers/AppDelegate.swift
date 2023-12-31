//
//  AppDelegate.swift
//  WeTrainers
//
//  Created by Bobby Ren on 9/21/15.
//  Copyright © 2015 Bobby Ren. All rights reserved.
//

import UIKit
import CoreData
import Bolts
import Parse
//import GoogleMaps

import Crashlytics
import Fabric
//import GoogleMaps

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        if TESTING == 0 {
            Parse.setApplicationId(PARSE_APP_ID_PROD, clientKey: PARSE_CLIENT_KEY_PROD)
        }
        else {
            Parse.setApplicationId(PARSE_APP_ID_DEV, clientKey: PARSE_CLIENT_KEY_DEV)
        }
        
        // [Optional] Track statistics around application opens.
        PFAnalytics.trackAppOpenedWithLaunchOptions(launchOptions)

        Fabric.with([Crashlytics.self()])
        
        // reregister for relevant channels
        if UIApplication.sharedApplication().isRegisteredForRemoteNotifications() {
            let settings = UIUserNotificationSettings(forTypes: [.Alert, .Badge, .Sound], categories: nil)
            UIApplication.sharedApplication().registerUserNotificationSettings(settings)
            UIApplication.sharedApplication().registerForRemoteNotifications()
        }

        if (PFUser.currentUser() != nil) {
            self.didLogin()
        }
        else {
            self.goToLogin()
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
        
        if UIApplication.sharedApplication().isRegisteredForRemoteNotifications() {
            NSNotificationCenter.defaultCenter().postNotificationName("push:enabled", object: nil)
        }
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }

    // MARK: - Core Data stack

    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.wetrain.WeTrainers" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1]
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
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("WeTrainPT")
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

    // MARK: - Login
    
    func didLogin() {
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
                if let trainer: PFObject = user!.objectForKey("trainer") as? PFObject {
                    trainer.fetchInBackgroundWithBlock({ (object, error) -> Void in
                        if object != nil {
                            if trainer.objectForKey("firstName") != nil && trainer.objectForKey("email") != nil && trainer.objectForKey("phone") != nil {

                                // TODO: logged in
                                let nav: UINavigationController  = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("ConnectNavigationController") as! UINavigationController
                                self.window!.rootViewController = nav
                                
                            }
                            else {
                                self.goToUserProfile()
                            }
                        }
                        else {
                            self.invalidLogin()
                        }
                    })
                }
                else {
                    self.invalidLogin()
                }
            }
        })
    }
    
    func goToLogin() {
        let controller: LoginViewController  = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("LoginViewController") as! LoginViewController
        self.window!.rootViewController = controller
    }

    func goToUserProfile() {
        let nav: UINavigationController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("SignupNavigationController") as! UINavigationController
        self.window!.rootViewController = nav
    }

    func logout() {
        PFUser.logOutInBackgroundWithBlock { (error) -> Void in
            self.goToLogin()
        }
    }
    
    func invalidLogin() {
        let alert = UIViewController.simpleAlert("Invalid trainer", message: "We could not log you in as a trainer.", completion: { () -> Void in
            self.logout()
        })
        self.window?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
    }
    
    // MARK: - Push Notifications
    
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        // Store the deviceToken in the current Installation and save it to Parse
        let installation = PFInstallation.currentInstallation()
        installation.setDeviceTokenFromData(deviceToken)
        installation.addUniqueObject("Trainers", forKey: "channels") // subscribe to trainers channel
        installation.saveInBackground()
        
        NSNotificationCenter.defaultCenter().postNotificationName("push:enabled", object: nil)
    }
    
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        print("failed")
        NSNotificationCenter.defaultCenter().postNotificationName("push:enable:failed", object: nil)
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) {
        print("notification received: \(userInfo)")
        /* format:
        [aps: {
            alert = "test push 2";
            sound = default;
            }]
        
        // With info:
        [message: i want to lose weight, aps: {
            }, userid: 1]
        */
        if let requestId = userInfo["request"] as? String {
            NSNotificationCenter.defaultCenter().postNotificationName("request:received", object: nil, userInfo: userInfo)
        }
    }

}



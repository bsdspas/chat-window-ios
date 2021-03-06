//
//  LiveChat.swift
//  Example-Swift
//
//  Created by Łukasz Jerciński on 06/03/2017.
//  Copyright © 2017 LiveChat Inc. All rights reserved.
//

import Foundation
import UIKit

@objc public protocol LiveChatDelegate : NSObjectProtocol {
    @objc optional func received(message: LiveChatMessage)
    @objc optional func handle(URL: URL)
    @objc optional func chatPresented()
    @objc optional func chatDismissed()
}

public class LiveChat : NSObject {
    public static var licenseId : String? {
        didSet {
            updateConfiguration()
        }
    }
    public static var groupId : String? {
        didSet {
            updateConfiguration()
        }
    }
    public static var name : String? {
        didSet {
            updateConfiguration()
        }
    }
    public static var email : String? {
        didSet {
            updateConfiguration()
        }
    }
    public static var allCustomVariables : Dictionary<String, String>?
    
    public static weak var delegate : LiveChatDelegate? {
        didSet {
            Manager.sharedInstance.delegate = delegate
        }
    }
    
    public static var isChatPresented : Bool {
        get {
            return Manager.sharedInstance.overlayViewController.chatState == .presented
        }
    }
    
    public static var unreadMessagesCount : Int {
        get {
            return UnreadMessagesCounter.counterValue
        }
    }
    
    public class func setVariable(withKey key: String, value: String) {
        Manager.sharedInstance.setVariable(withKey: key, value: value)
    }
    
    public class func presentChat(animated: Bool = true, completion: ((Bool) -> Void)? = nil) {
        Manager.sharedInstance.presentChat(animated: animated, completion: completion)
    }
    
    public class func dismissChat(animated: Bool = true, completion: ((Bool) -> Void)? = nil) {
        Manager.sharedInstance.dismissChat(animated: animated, completion: completion)
    }
    
    private class func updateConfiguration() {
        if let licenseId = self.licenseId {
            let conf = LiveChatConfiguration(licenseId: licenseId, groupId: self.groupId ?? "0", name: self.name ?? "", email: self.email ?? "")
            Manager.sharedInstance.configuration = conf
        }
    }
}

private class Manager : NSObject, LiveChatOverlayViewControllerDelegate, WebViewBridgeDelegate {
    var configuration : LiveChatConfiguration? {
        didSet {
            overlayViewController.configuration = configuration
        }
    }
    var customVariables : Dictionary<String, String>? {
        didSet {
            overlayViewController.customVariables = customVariables
        }
    }
    weak var delegate : LiveChatDelegate?
    fileprivate let overlayViewController = LiveChatOverlayViewController()
    private let window = PassThroughWindow()
    private var previousKeyWindow : UIWindow?
    private let webViewBridge = WebViewBridge()
    static let sharedInstance: Manager = {
        return Manager()
    }()
    
    override init() {
        window.backgroundColor = UIColor.clear
        window.frame = UIScreen.main.bounds
        window.windowLevel = UIWindowLevelNormal + 1
        window.rootViewController = overlayViewController
        
        super.init()
        
        webViewBridge.delegate = self
        overlayViewController.delegate = self
        overlayViewController.webViewBridge = webViewBridge
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidBecomeActive, object: nil, queue: nil) { (notification) in
            self.window.frame = UIApplication.shared.keyWindow!.frame
        }
    }
    
    // MARK: Public methods
    
    func setVariable(withKey key: String, value: String) {
        var mutableCustomVariables = customVariables
        
        if mutableCustomVariables == nil {
            mutableCustomVariables = [:]
        }
        
        mutableCustomVariables?[key] = value
        
        self.customVariables = mutableCustomVariables
    }
    
    func presentChat(animated: Bool, completion: ((Bool) -> Void)? = nil) {
        previousKeyWindow = UIApplication.shared.keyWindow
        window.makeKeyAndVisible()
        
        overlayViewController.presentChat(animated: animated, completion: { (finished) in
            if finished {
                UnreadMessagesCounter.resetCounter()
                self.delegate?.chatPresented?()
            }
            
            if let completion = completion {
                completion(finished)
            }
        })
    }
    
    func dismissChat(animated: Bool, completion: ((Bool) -> Void)? = nil) {
        overlayViewController.dismissChat(animated: animated, completion: { (finished) in
            if finished {
                self.previousKeyWindow?.makeKeyAndVisible()
                self.previousKeyWindow = nil
                
                self.window.isHidden = true
                
                UnreadMessagesCounter.resetCounter()
                self.delegate?.chatDismissed?()
            }
            
            if let completion = completion {
                completion(finished)
            }
        })
    }
    
    // MARK: LiveChatViewDelegate
    
    @objc func closedChatView() {
        previousKeyWindow?.makeKeyAndVisible()
        previousKeyWindow = nil
        
        window.isHidden = true
    }
    
    @objc func handle(URL: URL) {
        delegate?.handle?(URL: URL)
    }
    
    // MARK: WebViewBridgeDelegate
    
    @objc func received(message: LiveChatMessage) {
        let unread = UnreadMessagesCounter.handleUnreadMessage(id: message.id)
        
        if (unread) {
            delegate?.received?(message: message)
        }
    }
    
    @objc func hideChatWindow() {
        dismissChat(animated: true)    }
}

private class PassThroughWindow: UIWindow {
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return super.hitTest(point, with: event)
    }
}

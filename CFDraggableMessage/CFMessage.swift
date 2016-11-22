//
//  CFDraggableMessage.swift
//  Dynamic Demo
//
//  Created by Johnny Choi on 9/11/2016.
//  Copyright © 2016 Johnny@Co-fire. All rights reserved.
//

import UIKit

private let globalInstance = CFMessage()

open class CFMessage: MessengerDelegate {
    
    public enum InitPosition {
        case top(HorizontalPosition)
        case bottom(HorizontalPosition)
        case left
        case right
        case custom(CGPoint)
    }
    
    public enum HorizontalPosition {
        case left
        case right
        case center
        case random
    }
    
    public enum AppearPosition {
        case top
        case center
        case bottom
        case custom(CGPoint)
    }
    
    public enum DismissTime {
        case `default`
        case never
        case custom(seconds: TimeInterval)
    }
    
    public struct Config {
        public init() {}
        public var initPosition = InitPosition.top(.center)
        public var appearPosition = AppearPosition.center
        public var dismissTime = DismissTime.default
        /**
        The max. drag distance that the view will return to snap point.
        If exceed the thresholdDistance, the view will be dismissed.
        Default: 50
        */
        public var thresholdDistance : CGFloat = 50
        public var minPushForce : CGFloat = 8
        public var pushForceFactor : CGFloat = 0.005
        public var defaultPushForce : CGFloat = 12
        /**
        Rotation speed factor, default: 0.8
        - 0.0 : View will not rotate
        - The higher factor, the faster rotation
        */
        public var angularVelocityFactor: CGFloat = 0.8
        /**
        Rotation resistance, default: 1.2
        */
        public var angularResistance: CGFloat = 1.2
        public var snapDamping: CGFloat = 0.3
    }
    
    public init() {}
    
    // MARK: - Public functions
    /**
    Show message with config and add tap handler to it
    */
    open func show(config: Config, view: UIView, tapHandler: (()->Void)? = nil) {
        syncQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            let message = Messenger(config: config, view: view, tapHandler: tapHandler, delegate: strongSelf)
            strongSelf.enqueue(message: message)
        }
    }
    
    open func show(config: Config, view: UIView) {
        show(config: config, view: view, tapHandler: nil)
    }
    
    open func show(view: UIView) {
        show(config: defaultConfig, view: view)
    }
    
    public typealias ViewProvider = () -> UIView
    
    open func show(config: Config, viewProvider: @escaping ViewProvider) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            let view = viewProvider()
            strongSelf.show(config: config, view: view)
        }
    }
    
    public func show(viewProvider: @escaping ViewProvider) {
        show(config: defaultConfig, viewProvider: viewProvider)
    }
    
    open func dismiss() {
        syncQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.dismissCurrent()
        }
    }
    
    open func dismissAll() {
        syncQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.messageQueue.removeAll()
            strongSelf.dismissCurrent()
        }
    }
    
    open weak var delegate: CFMessageDelegate!
    public var defaultConfig = Config()
    
    open var intervalBetweenMessages: TimeInterval = 0.5
    
    let syncQueue = DispatchQueue(label: "CFMessage.Queue", attributes: [])
    var messageQueue: [Messenger] = []
    var currentMsg: Messenger? = nil {
        didSet {
            if oldValue != nil {
                let delayTime = DispatchTime.now() + intervalBetweenMessages
                syncQueue.asyncAfter(deadline: delayTime, execute: { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.dequeueNext()
                })
            }
        }
    }
    
    func enqueue(message: Messenger) {
        messageQueue.append(message)
        dequeueNext()
    }
    
    func dequeueNext() {
//        print("Count = \(self.messageQueue.count)")
        guard self.currentMsg == nil else { return }
        guard messageQueue.count > 0 else { return }
        let current = messageQueue.removeFirst()
        self.currentMsg = current
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            current.show(completion: { (completed) in
                guard completed else { return }
                if completed {
                    strongSelf.queueAutoDismiss()
                }
            })
        }
    }
    
    fileprivate var msgToAutoDismiss: Messenger?
    
    fileprivate func queueAutoDismiss() {
        guard let currentMsg = self.currentMsg else { return }
        self.msgToAutoDismiss = currentMsg
        if let dissmissTime = currentMsg.dismissTime {
            let delayTime = DispatchTime.now() + dissmissTime
            syncQueue.asyncAfter(deadline: delayTime, execute: { [weak self] in
                guard let strongSelf = self else { return }
                if strongSelf.msgToAutoDismiss !== currentMsg {
                    return
                }
                strongSelf.dismiss(messager: currentMsg)
            })
        }
    }
    
    func dismiss(messager: Messenger) {
        self.syncQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            if let currentMsg = strongSelf.currentMsg, messager === currentMsg {
                strongSelf.dismissCurrent()
            }
        }
    }
    
    func dismissCurrent() {
        guard let currentMsg = self.currentMsg else { return }
        guard !currentMsg.isDismissing else { return }
        DispatchQueue.main.async {
            currentMsg.dismiss()
        }
    }
    
    // MARK: - MessengerDelegate
    func messengerDidAppear() {
        if let delegate = delegate {
            delegate.cfMessageDidAppear()
        }
    }
    
    func messengerStartDragging(atPoint: CGPoint) {
        if let delegate = delegate {
            delegate.cfMessageStartDragging(atPoint: atPoint)
        }
        self.msgToAutoDismiss = nil
    }
    
    func messengerIsDragging(atPoint: CGPoint) {
        if let delegate = delegate {
            delegate.cfMessageIsDragging(atPoint: atPoint)
        }
    }
    
    func messengerEndDragging(atPoint: CGPoint) {
        if let delegate = delegate {
            delegate.cfMessageEndDragging(atPoint: atPoint)
        }
        self.queueAutoDismiss()
    }
    
    func messengerDidDisappear(messenger: Messenger) {
        if let delegate = delegate {
            delegate.cfMessageDidDisappear()
        }
        self.syncQueue.async {
            self.messageQueue = self.messageQueue.filter{ $0 !== messenger }
            self.currentMsg = nil
        }
    }
    
    func messengerIsTapped() {
        if let delegate = delegate {
            delegate.cfMessageIsTapped()
        }
        self.msgToAutoDismiss = nil
        self.dismissCurrent()
    }
}

/* MARK: - Static APIs **/
extension CFMessage {
    
    public static var sharedInstance: CFMessage {
        return globalInstance
    }
    
    public static weak var delegate: CFMessageDelegate? {
        get {
            return globalInstance.delegate
        }
        set {
            globalInstance.delegate = newValue
        }
    }
    
    public static func show(view: UIView) {
        globalInstance.show(view: view)
    }
    
    public static func show(config: Config, view: UIView) {
        globalInstance.show(config: config, view: view)
    }
    
    public static func show(config: Config, view: UIView, tapHandler: (()->Void)? = nil) {
        globalInstance.show(config: config, view: view, tapHandler: tapHandler)
    }
    
    public static func show(viewProvider: @escaping ViewProvider) {
        globalInstance.show(viewProvider: viewProvider)
    }
    
    public static func show(config: Config, viewProvider: @escaping ViewProvider) {
        globalInstance.show(config: config, viewProvider: viewProvider)
    }
    
    public static func dismiss() {
        globalInstance.dismiss()
    }
    
    public static func dismissAll() {
        globalInstance.dismissAll()
    }
}

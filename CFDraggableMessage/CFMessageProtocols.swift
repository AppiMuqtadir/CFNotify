//
//  CFMessageProtocols.swift
//  CFDraggableMessage
//
//  Created by Johnny Choi on 10/11/2016.
//  Copyright © 2016 Johnny Choi@Co-Fire. All rights reserved.
//

import Foundation

public protocol CFMessageDelegate {
    func cfMessageDidAppear()
    func cfMessageIsDragging(atPoint: CGPoint)
    func cfMessageDidTap()
    func cfMessageDidDismiss()
}

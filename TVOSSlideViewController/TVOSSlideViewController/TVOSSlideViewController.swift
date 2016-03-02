//
//  TVOSSlideViewController.swift
//  TVOSSlideViewController
//
//  Created by Cem Olcay on 23/02/16.
//  Copyright © 2016 MovieLaLa. All rights reserved.
//

import UIKit

@objc public protocol TVOSSlideViewControllerDelegate {
  optional func slideViewControllerDidBeginUpdateLeftDrawer(slideViewController: TVOSSlideViewController)
  optional func slideViewControllerDidBeginUpdateRightDrawer(slideViewController: TVOSSlideViewController)
  optional func slideViewControllerDidUpdateLeftDrawer(slideViewController: TVOSSlideViewController, amount: CGFloat)
  optional func slideViewControllerDidUpdateRightDrawer(slideViewController: TVOSSlideViewController, amount: CGFloat)
  optional func slideViewControllerDidEndUpdateLeftDrawer(slideViewController: TVOSSlideViewController, amount: CGFloat)
  optional func slideViewControllerDidEndUpdateRightDrawer(slideViewController: TVOSSlideViewController, amount: CGFloat)
  optional func slideViewControllerDidSelectLeftDrawer(slideViewController: TVOSSlideViewController)
  optional func slideViewControllerDidSelectRightDrawer(slideViewController: TVOSSlideViewController)
}

public enum TVOSSlideViewControllerType {
  case LeftRightDrawer
  case LeftDrawer
  case RightDrawer
  case NoDrawer
}

@IBDesignable
public class TVOSSlideViewControllerShadow: NSObject {
  @IBInspectable public var color: UIColor = UIColor.blackColor()
  @IBInspectable public var opacity: CGFloat = 0.5
  @IBInspectable public var radius: CGFloat =  50
  @IBInspectable public var offset: CGSize = CGSize.zero
  @IBInspectable public var cornerRadius: CGFloat = 0

  public static var Empty: TVOSSlideViewControllerShadow {
    let shadow = TVOSSlideViewControllerShadow()
    shadow.color = UIColor.clearColor()
    shadow.opacity = 0
    shadow.radius = 0
    shadow.offset = CGSize.zero
    return shadow
  }

  public func apply(onLayer layer: CALayer?) {
    if let layer = layer {
      layer.shadowColor = color.CGColor
      layer.shadowOffset = offset
      layer.shadowRadius = radius
      layer.shadowOpacity = Float(opacity)
      layer.shadowPath = UIBezierPath(
        roundedRect: CGRect(x: 0, y: 0, width: layer.frame.size.width, height: layer.frame.size.height),
        cornerRadius: cornerRadius)
        .CGPath
    }
  }
}

@IBDesignable
public class TVOSSlideViewController: UIViewController {

  // MARK: Properties

  private var contentView: UIView!
  private var contentViewShadow: UIView?

  @IBOutlet public var leftView: UIView?
  @IBOutlet public var rightView: UIView?

  // max value for selection
  @IBInspectable public var leftValue: CGFloat = 400
  @IBInspectable public var rightValue: CGFloat = 400

  // if amount >= value - trashold than selected
  @IBInspectable public var rightTrashold: CGFloat = 0.1
  @IBInspectable public var leftTrashold: CGFloat = 0.1

  // animate contentView autolayout enabled or not
  @IBInspectable public var shrinks: Bool = false

  // center horizontally content for parallax effect
  @IBInspectable public var parallax: Bool = false

  // shadow style
  @IBOutlet public var shadow: TVOSSlideViewControllerShadow? {
    didSet {
      if let shadow = shadow {
        shadow.apply(onLayer: contentViewShadow?.layer)
      } else {
        TVOSSlideViewControllerShadow.Empty.apply(onLayer: contentViewShadow?.layer)
      }
    }
  }

  private var leftConstraint: NSLayoutConstraint?
  private var rightConstraint: NSLayoutConstraint?

  public weak var delegate: TVOSSlideViewControllerDelegate?
  
  private(set) var type: TVOSSlideViewControllerType = .NoDrawer
  internal var panGestureRecognizer: UIPanGestureRecognizer!

  // MARK: Init

  public init(contentViewController: UIViewController, leftView: UIView?, rightView: UIView?) {
    super.init(nibName: nil, bundle: nil)
    self.leftView = leftView
    self.rightView = rightView
    if let leftView = leftView { view.addSubview(leftView) }
    if let rightView = rightView { view.addSubview(rightView) }
    setup(contentViewController: contentViewController)
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  public func setup(contentViewController contentVC: UIViewController?) {
    // type
    switch (leftView, rightView) {
    case (.None, .None):
      type = .NoDrawer
    case (.Some(_), .None):
      type = .LeftDrawer
    case (.None, .Some(_)):
      type = .RightDrawer
    case (.Some(_), .Some(_)):
      type = .LeftRightDrawer
    }

    // reset child view controllers
    for child in childViewControllers {
      child.removeFromParentViewController()
      child.didMoveToParentViewController(nil)
    }

    // content view
    if contentView != nil {
      contentView.removeFromSuperview()
    }
    contentView = UIView()
    contentView.translatesAutoresizingMaskIntoConstraints = false
    contentView.layer.masksToBounds = true
    view.addSubview(contentView)

    let topConstraint = NSLayoutConstraint(
      item: contentView,
      attribute: NSLayoutAttribute.Top,
      relatedBy: NSLayoutRelation.Equal,
      toItem: view,
      attribute: NSLayoutAttribute.Top,
      multiplier: 1,
      constant: 0)
    let bottomConstraint = NSLayoutConstraint(
      item: contentView,
      attribute: NSLayoutAttribute.Bottom,
      relatedBy: NSLayoutRelation.Equal,
      toItem: view,
      attribute: NSLayoutAttribute.Bottom,
      multiplier: 1,
      constant: 0)
    leftConstraint = NSLayoutConstraint(
      item: contentView,
      attribute: NSLayoutAttribute.Leading,
      relatedBy: NSLayoutRelation.Equal,
      toItem: view,
      attribute: NSLayoutAttribute.Leading,
      multiplier: 1,
      constant: 0)
    rightConstraint = NSLayoutConstraint(
      item: contentView,
      attribute: NSLayoutAttribute.Trailing,
      relatedBy: NSLayoutRelation.Equal,
      toItem: view,
      attribute: NSLayoutAttribute.Trailing,
      multiplier: 1,
      constant: 0)

    view.addConstraints([
      topConstraint, 
      bottomConstraint, 
      leftConstraint!, 
      rightConstraint!])

    // content view shadow
    contentViewShadow?.removeFromSuperview()
    contentViewShadow = nil
    if let shadow = shadow {
      let shadowView = UIView()
      shadowView.backgroundColor = UIColor.clearColor()
      shadowView.translatesAutoresizingMaskIntoConstraints = false
      shadowView.userInteractionEnabled = false
      shadowView.layer.masksToBounds = false
      view.addSubview(shadowView)
      view.addSubview(contentView)

      // shadow constraints
      view.addConstraints([
        NSLayoutConstraint(
          item: shadowView,
          attribute: NSLayoutAttribute.Top,
          relatedBy: NSLayoutRelation.Equal,
          toItem: contentView,
          attribute: NSLayoutAttribute.Top,
          multiplier: 1,
          constant: 0),
        NSLayoutConstraint(
          item: shadowView,
          attribute: NSLayoutAttribute.Bottom,
          relatedBy: NSLayoutRelation.Equal,
          toItem: contentView,
          attribute: NSLayoutAttribute.Bottom,
          multiplier: 1,
          constant: 0),
        NSLayoutConstraint(
          item: shadowView,
          attribute: NSLayoutAttribute.Leading,
          relatedBy: NSLayoutRelation.Equal,
          toItem: contentView,
          attribute: NSLayoutAttribute.Leading,
          multiplier: 1,
          constant: 0),
        NSLayoutConstraint(
          item: shadowView,
          attribute: NSLayoutAttribute.Trailing,
          relatedBy: NSLayoutRelation.Equal,
          toItem: contentView,
          attribute: NSLayoutAttribute.Trailing,
          multiplier: 1,
          constant: 0)
      ])

      contentViewShadow = shadowView
      shadow.apply(onLayer: contentViewShadow?.layer)
    } else {
      TVOSSlideViewControllerShadow.Empty.apply(onLayer: contentViewShadow?.layer)
    }

    // content view controller
    if let contentViewController = contentVC {
      contentView.addSubview(contentViewController.view)
      contentViewController.view.translatesAutoresizingMaskIntoConstraints = false

      if parallax {
        shrinks = true
        contentView.addConstraints([
          NSLayoutConstraint(
            item: contentViewController.view,
            attribute: NSLayoutAttribute.Top,
            relatedBy: NSLayoutRelation.Equal,
            toItem: contentView,
            attribute: NSLayoutAttribute.Top,
            multiplier: 1,
            constant: 0),
          NSLayoutConstraint(
            item: contentViewController.view,
            attribute: NSLayoutAttribute.Bottom,
            relatedBy: NSLayoutRelation.Equal,
            toItem: contentView,
            attribute: NSLayoutAttribute.Bottom,
            multiplier: 1,
            constant: 0),
          NSLayoutConstraint(
            item: contentViewController.view,
            attribute: NSLayoutAttribute.CenterX,
            relatedBy: NSLayoutRelation.Equal,
            toItem: contentView,
            attribute: NSLayoutAttribute.CenterX,
            multiplier: 1,
            constant: 0),
          NSLayoutConstraint(
            item: contentViewController.view,
            attribute: NSLayoutAttribute.Width,
            relatedBy: NSLayoutRelation.Equal,
            toItem: nil,
            attribute: NSLayoutAttribute.NotAnAttribute,
            multiplier: 1,
            constant: contentViewController.view.frame.size.width)
          ])
      } else {
      contentView.addConstraints([
          NSLayoutConstraint(
            item: contentViewController.view,
            attribute: NSLayoutAttribute.Top, 
            relatedBy: NSLayoutRelation.Equal, 
            toItem: contentView,
            attribute: NSLayoutAttribute.Top, 
            multiplier: 1, 
            constant: 0),
          NSLayoutConstraint(
            item: contentViewController.view,
            attribute: NSLayoutAttribute.Bottom,
            relatedBy: NSLayoutRelation.Equal,
            toItem: contentView,
            attribute: NSLayoutAttribute.Bottom,
            multiplier: 1,
            constant: 0),
          NSLayoutConstraint(
            item: contentViewController.view,
            attribute: NSLayoutAttribute.Leading,
            relatedBy: NSLayoutRelation.Equal,
            toItem: contentView,
            attribute: NSLayoutAttribute.Leading,
            multiplier: 1,
            constant: 0),
          NSLayoutConstraint(
            item: contentViewController.view,
            attribute: NSLayoutAttribute.Trailing,
            relatedBy: NSLayoutRelation.Equal,
            toItem: contentView,
            attribute: NSLayoutAttribute.Trailing,
            multiplier: 1,
            constant: 0)
        ])
      }

      addChildViewController(contentViewController)
      contentViewController.didMoveToParentViewController(self)
    }

    view.setNeedsLayout()
    view.layoutIfNeeded()

    // pan gesture
    panGestureRecognizer = UIPanGestureRecognizer(target: self, action: "panGestureDidChange:")
    contentView.addGestureRecognizer(panGestureRecognizer)
  }

  // MARK: Pan Gesture Recognizer

  public func enablePanGestureRecognizer() {
    panGestureRecognizer.enabled = true
  }

  public func disablePanGestureRecognizer() {
    panGestureRecognizer.enabled = false
  }

  internal func panGestureDidChange(pan: UIPanGestureRecognizer) {
    if pan == panGestureRecognizer {
      let translation = pan.translationInView(view)

      switch type {
      case .LeftRightDrawer:
        if translation.x > 0 {
          updateLeftDrawer(translation.x, state: pan.state)
        } else {
          updateRightDrawer(translation.x, state: pan.state)
        }
      case .LeftDrawer:
        if translation.x > 0 {
          updateLeftDrawer(translation.x, state: pan.state)
        }
      case .RightDrawer:
        if translation.x < 0 {
          updateRightDrawer(translation.x, state: pan.state)
        }
      case .NoDrawer:
        break
      }
    }
  }

  // MARK: Update

  private func resetConstraints() {
    view.layoutIfNeeded()
    leftConstraint?.constant = 0
    rightConstraint?.constant = 0
    shadow?.apply(onLayer: contentViewShadow?.layer)
    UIView.animateWithDuration(0.2, animations: view.layoutIfNeeded)
  }

  private func updateLeftDrawer(translation: CGFloat, state: UIGestureRecognizerState) {
    let translationAmount = max(0, min(CGFloat(abs(Int32(translation))), leftValue))
    let amount = translationAmount / leftValue
    view.layoutIfNeeded()
    leftConstraint?.constant = leftValue * amount
    rightConstraint?.constant = shrinks ? 0 : leftValue * amount
    shadow?.apply(onLayer: contentViewShadow?.layer)
    UIView.animateWithDuration(0.1, animations: view.layoutIfNeeded)

    switch state {
    case .Began:
      delegate?.slideViewControllerDidBeginUpdateLeftDrawer?(self)
    case .Changed:
      delegate?.slideViewControllerDidUpdateLeftDrawer?(self, amount: amount)
    case .Cancelled, .Ended, .Failed:
      resetConstraints()
      if amount >= 1.0 - leftTrashold {
        delegate?.slideViewControllerDidSelectLeftDrawer?(self)
      } else {
        delegate?.slideViewControllerDidEndUpdateLeftDrawer?(self, amount: amount)
      }
    default:
      break
    }
  }

  private func updateRightDrawer(translation: CGFloat, state: UIGestureRecognizerState) {
    let translationAmount = max(0, min(CGFloat(abs(Int32(translation))), rightValue))
    let amount = translationAmount / rightValue
    view.layoutIfNeeded()
    rightConstraint?.constant = -rightValue * amount
    leftConstraint?.constant = shrinks ? 0 : -rightValue * amount
    shadow?.apply(onLayer: contentViewShadow?.layer)
    UIView.animateWithDuration(0.1, animations: view.layoutIfNeeded)

    switch state {
    case .Began:
      delegate?.slideViewControllerDidBeginUpdateRightDrawer?(self)
    case .Changed:
      delegate?.slideViewControllerDidUpdateRightDrawer?(self, amount: amount)
    case .Cancelled, .Ended, .Failed:
      resetConstraints()
      if amount >= 1.0 - rightTrashold {
        delegate?.slideViewControllerDidSelectRightDrawer?(self)
      } else {
        delegate?.slideViewControllerDidEndUpdateRightDrawer?(self, amount: amount)
      }
    default:
      break
    }
  }
}

//
//  Clock.swift
//  SwiftClock
//
//  Created by Joseph Daniels on 01/09/16.
//  Copyright © 2016 Joseph Daniels. All rights reserved.
//

import Foundation
import UIKit

@objc public  protocol SG_TenClockDelegate {
    //Executed for every touch.
    @objc optional func sg_timesUpdated(_ clock:SG_TenClock, startDate:Date,  endDate:Date  ) -> ()
    //Executed after the user lifts their finger from the control.
    @objc optional func sg_timesChanged(_ clock:SG_TenClock, startDate:Date,  endDate:Date  ) -> ()
}
func sg_medStepFunction(_ val: CGFloat, stepSize:CGFloat) -> CGFloat{
    let dStepSize = Double(stepSize)
    let dval  = Double(val)
    let nsf = floor(dval/dStepSize)
    let rest = dval - dStepSize * nsf
    return CGFloat(rest > dStepSize / 2 ? dStepSize * (nsf + 1) : dStepSize * nsf)
    
}

//XCPlaygroundPage.currentPage.needsIndefiniteExecution = true
//@IBDesignable
open class SG_TenClock : UIControl{
    
    @objc open var delegate:SG_TenClockDelegate?
    //overall inset. Controls all sizes.
    @IBInspectable var insetAmount: CGFloat = 40
    var internalShift: CGFloat = 5;
    var pathWidth:CGFloat = 54
    
    var timeStepSize: CGFloat = 5
    let gradientLayer = CAGradientLayer()
    let trackLayer = CAShapeLayer()
    let pathLayer = CAShapeLayer()
    let headLayer = CAShapeLayer()
    let tailLayer = CAShapeLayer()
    let topHeadLayer = CAShapeLayer()
    let topTailLayer = CAShapeLayer()
    let numeralsLayer = CALayer()
    let titleTextLayer = CATextLayer()
    let overallPathLayer = CALayer()
    let repLayer:CAReplicatorLayer = {
        var r = CAReplicatorLayer()
        r.instanceCount = 48
        r.instanceTransform =
            CATransform3DMakeRotation(
                CGFloat(2*Double.pi) / CGFloat(r.instanceCount),
                0,0,1)
        
        return r
    }()
    
    let repLayer2:CAReplicatorLayer = {
        var r = CAReplicatorLayer()
        r.instanceCount = 12
        r.instanceTransform =
            CATransform3DMakeRotation(
                CGFloat(2*Double.pi) / CGFloat(r.instanceCount),
                0,0,1)
        
        return r
    }()
    let twoPi =  CGFloat(2 * Double.pi)
    let fourPi =  CGFloat(4 * Double.pi)
    var headAngle: CGFloat = 0{
        didSet{
            if (headAngle > fourPi  +  CGFloat(Double.pi / 2)){
                headAngle -= fourPi
            }
            if (headAngle <  CGFloat(Double.pi / 2) ){
                headAngle += fourPi
            }
        }
    }
    
    var tailAngle: CGFloat = 0.7 * CGFloat(Double.pi) {
        didSet{
            if (tailAngle  > headAngle + fourPi){
                tailAngle -= fourPi
            } else if (tailAngle  < headAngle ){
                tailAngle += fourPi
            }
            
        }
    }
    
    open var shouldMoveHead = true
    open var shouldMoveTail = true
    
    
    open var numeralsColor:UIColor? = UIColor.darkGray
    open var minorTicksColor:UIColor? = UIColor.lightGray
    open var majorTicksColor:UIColor? = UIColor.blue
    open var centerTextColor:UIColor? = UIColor.darkGray
    
    open var titleColor = UIColor.lightGray
    open var titleGradientMask = false
    
    //disable scrol on closest superview for duration of a valid touch.
    var disableSuperviewScroll = false
    
    open var headBackgroundColor = UIColor.white.withAlphaComponent(0.8)
    open var tailBackgroundColor = UIColor.white.withAlphaComponent(0.8)
    
    open var headText: String = "Start"
    open var tailText: String = "End"
    
    open var headTextColor = UIColor.black
    open var tailTextColor = UIColor.black
    
    open var minorTicksEnabled:Bool = true
    open var majorTicksEnabled:Bool = true
    @objc open var disabled:Bool = false {
        didSet{
            sg_update()
        }
    }
    
    open var buttonInset:CGFloat = 2
    func sg_disabledFormattedColor(_ color:UIColor) -> UIColor{
        return disabled ? color.greyscale : color
    }
    
    
    
    
    var trackWidth:CGFloat {return pathWidth }
    func sg_proj(_ theta:Angle) -> CGPoint{
        let center = self.layer.center
        return CGPoint(x: center.x + trackRadius * cos(theta) ,
                       y: center.y - trackRadius * sin(theta) )
    }
    
    var sg_headPoint: CGPoint{
        return sg_proj(headAngle)
    }
    var sg_tailPoint: CGPoint{
        return sg_proj(tailAngle)
    }
    
    lazy internal var calendar = Calendar(identifier:Calendar.Identifier.gregorian)
    func sg_toDate(_ val:CGFloat)-> Date {
        //        var comps = DateComponents()
        //        comps.minute = Int(val)
        return calendar.date(byAdding: Calendar.Component.minute , value: Int(val), to: Date().startOfDay as Date)!
        //        return calendar.dateByAddingComponents(comps, sg_toDate: Date().startOfDay as Date, options: .init(rawValue:0))!
    }
    @objc open var startDate: Date{
        get{return sg_angleToTime(tailAngle) }
        set{ tailAngle = sg_timeToAngle(newValue) }
    }
    @objc open var endDate: Date{
        get{return sg_angleToTime(headAngle) }
        set{ headAngle = sg_timeToAngle(newValue) }
    }
    
    var internalRadius:CGFloat {
        return internalInset.height
    }
    var inset:CGRect{
        return self.layer.bounds.insetBy(dx: insetAmount, dy: insetAmount)
    }
    var internalInset:CGRect{
        let reInsetAmount = trackWidth / 2 + internalShift
        return self.inset.insetBy(dx: reInsetAmount, dy: reInsetAmount)
    }
    var numeralInset:CGRect{
        let reInsetAmount = trackWidth / 2 + internalShift + internalShift
        return self.inset.insetBy(dx: reInsetAmount, dy: reInsetAmount)
    }
    var titleTextInset:CGRect{
        let reInsetAmount = trackWidth.checked / 2 + 4 * internalShift
        return (self.inset).insetBy(dx: reInsetAmount, dy: reInsetAmount)
    }
    var trackRadius:CGFloat { return inset.height / 2}
    var buttonRadius:CGFloat { return /*44*/ pathWidth / 2 }
    var iButtonRadius:CGFloat { return /*44*/ buttonRadius - buttonInset }
    var strokeColor: UIColor {
        get {
            return UIColor(cgColor: trackLayer.strokeColor!)
        }
        set(strokeColor) {
            trackLayer.strokeColor = strokeColor.withAlphaComponent(0.1).cgColor
            pathLayer.strokeColor = strokeColor.cgColor
        }
    }
    
    
    // input a date, output: 0 to 4pi
    func sg_timeToAngle(_ date: Date) -> Angle{
        let units : Set<Calendar.Component> = [.hour, .minute]
        let components = self.calendar.dateComponents(units, from: date)
        let min = Double(  60 * components.hour! + components.minute! )
        
        return sg_medStepFunction(CGFloat(Double.pi / 2 - ( min / (12 * 60)) * 2 * Double.pi), stepSize: CGFloat( 2 * Double.pi / (12 * 60 / 5)))
    }
    
    // input an angle, output: 0 to 4pi
    func sg_angleToTime(_ angle: Angle) -> Date{
        let dAngle = Double(angle)
        let min = CGFloat(((Double.pi / 2 - dAngle) / (2 * Double.pi)) * (12 * 60))
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return self.calendar.date(byAdding: .minute, value: Int(sg_medStepFunction(min, stepSize: 5/* minute steps*/)), to: startOfToday)!
    }
    override open func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        sg_update()
    }
    @objc open func sg_update() {
        let mm = min(self.layer.bounds.size.height, self.layer.bounds.size.width)
        CATransaction.begin()
        self.layer.size = CGSize(width: mm, height: mm)
        
        strokeColor = sg_disabledFormattedColor(tintColor)
        overallPathLayer.occupation = layer.occupation
        gradientLayer.occupation = layer.occupation
        
        trackLayer.occupation = (inset.size, layer.center)
        
        pathLayer.occupation = (inset.size, overallPathLayer.center)
        repLayer.occupation = (internalInset.size, overallPathLayer.center)
        repLayer2.occupation  =  (internalInset.size, overallPathLayer.center)
        numeralsLayer.occupation = (numeralInset.size, layer.center)
        
        trackLayer.fillColor = UIColor.clear.cgColor
        pathLayer.fillColor = UIColor.clear.cgColor
        
        
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        sg_updateGradientLayer()
        sg_updateTrackLayerPath()
        sg_updatePathLayerPath()
        sg_updateHeadTailLayers()
        sg_updateWatchFaceTicks()
        sg_updateWatchFaceNumerals()
        sg_updateWatchFaceTitle()
        CATransaction.commit()
        
    }
    func sg_updateGradientLayer() {
        
        gradientLayer.colors =
            [tintColor,
             tintColor.modified(withAdditionalHue: -0.08, additionalSaturation: 0.15, additionalBrightness: 0.2)]
                .map(sg_disabledFormattedColor)
                .map{$0.cgColor}
        gradientLayer.mask = overallPathLayer
        gradientLayer.startPoint = CGPoint(x:0,y:0)
    }
    
    func sg_updateTrackLayerPath() {
        let circle = UIBezierPath(
            ovalIn: CGRect(
                origin:CGPoint(x: 0, y: 00),
                size: CGSize(width:trackLayer.size.width,
                             height: trackLayer.size.width)))
        trackLayer.lineWidth = pathWidth
        trackLayer.path = circle.cgPath
        
    }
    override open func layoutSubviews() {
        sg_update()
    }
    func sg_updatePathLayerPath() {
        let arcCenter = pathLayer.center
        pathLayer.fillColor = UIColor.clear.cgColor
        pathLayer.lineWidth = pathWidth
        //        print("start = \(headAngle / CGFloat(Double.pi)), end = \(tailAngle / CGFloat(Double.pi))")
        pathLayer.path = UIBezierPath(
            arcCenter: arcCenter,
            radius: trackRadius,
            startAngle: ( twoPi  ) -  ((tailAngle - headAngle) >= twoPi ? tailAngle - twoPi : tailAngle),
            endAngle: ( twoPi ) -  headAngle,
            clockwise: true).cgPath
    }
    
    
    func sg_tlabel(_ str:String, color:UIColor? = nil) -> CATextLayer{
        let f = UIDevice.current.userInterfaceIdiom == .pad ? UIFont.systemFont(ofSize: 14.0) : UIFont.systemFont(ofSize: 13.0)
        let cgFont = CTFontCreateWithName((f.fontName as CFString?)!, f.pointSize/2,nil)
        let l = CATextLayer()
        l.bounds.size = CGSize(width: 30, height: 15)
        l.fontSize = f.pointSize
        l.foregroundColor =  sg_disabledFormattedColor(color ?? tintColor).cgColor
        l.alignmentMode = kCAAlignmentCenter
        l.contentsScale = UIScreen.main.scale
        l.font = cgFont
        l.string = str
        
        return l
    }
    func sg_updateHeadTailLayers() {
        let size = CGSize(width: 2 * buttonRadius, height: 2 * buttonRadius)
        let iSize = CGSize(width: 2 * iButtonRadius, height: 2 * iButtonRadius)
        let circle = UIBezierPath(ovalIn: CGRect(origin: CGPoint(x: 0, y:0), size: size)).cgPath
        let iCircle = UIBezierPath(ovalIn: CGRect(origin: CGPoint(x: 0, y:0), size: iSize)).cgPath
        tailLayer.path = circle
        headLayer.path = circle
        tailLayer.size = size
        headLayer.size = size
        tailLayer.position = sg_tailPoint
        headLayer.position = sg_headPoint
        topTailLayer.position = sg_tailPoint
        topHeadLayer.position = sg_headPoint
        headLayer.fillColor = UIColor.yellow.cgColor
        tailLayer.fillColor = UIColor.green.cgColor
        topTailLayer.path = iCircle
        topHeadLayer.path = iCircle
        topTailLayer.size = iSize
        topHeadLayer.size = iSize
        topHeadLayer.fillColor = sg_disabledFormattedColor(headBackgroundColor).cgColor
        topTailLayer.fillColor = sg_disabledFormattedColor(tailBackgroundColor).cgColor
        topHeadLayer.sublayers?.forEach({$0.removeFromSuperlayer()})
        topTailLayer.sublayers?.forEach({$0.removeFromSuperlayer()})
        let stText = sg_tlabel(headText, color: sg_disabledFormattedColor(headTextColor))
        let endText = sg_tlabel(tailText, color: sg_disabledFormattedColor(tailTextColor))
        stText.position = topTailLayer.center
        endText.position = topHeadLayer.center
        topHeadLayer.addSublayer(endText)
        topTailLayer.addSublayer(stText)
    }
    
    
    func sg_updateWatchFaceNumerals() {
        numeralsLayer.sublayers?.forEach({$0.removeFromSuperlayer()})
        let f = UIFont.preferredFont(forTextStyle: UIFontTextStyle.caption2)
        let cgFont = CTFontCreateWithName((f.fontName as CFString?)!, f.pointSize/2,nil)
        let startPos = CGPoint(x: numeralsLayer.bounds.midX, y: 15)
        let origin = numeralsLayer.center
        let step = (2 * Double.pi) / 12
        for i in (1 ... 12){
            let l = CATextLayer()
            l.bounds.size = CGSize(width: i > 9 ? 18 : 8, height: 15)
            l.fontSize = f.pointSize
            l.alignmentMode = kCAAlignmentCenter
            l.contentsScale = UIScreen.main.scale
            //            l.foregroundColor
            l.font = cgFont
            l.string = "\(i)"
            l.foregroundColor = sg_disabledFormattedColor(numeralsColor ?? tintColor).cgColor
            l.position = CGVector(from:origin, to:startPos).rotate( CGFloat(Double(i) * step)).add(origin.vector).point.checked
            numeralsLayer.addSublayer(l)
        }
    }
    func sg_updateWatchFaceTitle(){
        var f: UIFont;
        if #available(iOS 9.0, *) {
            f = UIFont.preferredFont(forTextStyle: UIFontTextStyle.title1)
        } else {
            // Fallback on earlier versions
            f = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
            
        }
        let cgFont = CTFontCreateWithName((f.fontName as CFString?)!, f.pointSize/2,nil)
        //        let titleTextLayer = CATextLayer()
        titleTextLayer.bounds.size = CGSize( width: titleTextInset.size.width, height: 50)
        titleTextLayer.fontSize = f.pointSize
        titleTextLayer.alignmentMode = kCAAlignmentCenter
        titleTextLayer.foregroundColor = sg_disabledFormattedColor(centerTextColor ?? tintColor).cgColor
        titleTextLayer.contentsScale = UIScreen.main.scale
        titleTextLayer.font = cgFont
        //var computedTailAngle = tailAngle //+ (headAngle > tailAngle ? twoPi : 0)
        //computedTailAngle +=  (headAngle > computedTailAngle ? twoPi : 0)
        //        var fiveMinIncrements = Int( ((tailAngle - headAngle) / twoPi) * 12 /*hrs*/ * 12 /*5min increments*/)
        //        if fiveMinIncrements < 0 {
        //            print("tenClock:Err: is negative")
        //            fiveMinIncrements += (24 * (60/5))
        //        }
        //
        //        titleTextLayer.string = "\(fiveMinIncrements / 12)时 \((fiveMinIncrements % 12) * 5)分"
        var time = endDate.timeIntervalSince(startDate)
        if time < 0 {
            time += 60 * 24 * 60
        }
        let hour = Int(time / 3600)
        let min = Int((time - Double(hour * 3600)) / 60)
        titleTextLayer.string = "\(hour)时\(min)分"
        titleTextLayer.position = gradientLayer.center
        
    }
    func sg_tick() -> CAShapeLayer{
        let sg_tick = CAShapeLayer()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0,y: -3))
        path.addLine(to: CGPoint(x: 0,y: 3))
        sg_tick.path  = path.cgPath
        sg_tick.bounds.size = CGSize(width: 6, height: 6)
        return sg_tick
    }
    
    func sg_updateWatchFaceTicks() {
        repLayer.sublayers?.forEach({$0.removeFromSuperlayer()})
        let t = sg_tick()
        t.strokeColor = sg_disabledFormattedColor(minorTicksColor ?? tintColor).cgColor
        t.position = CGPoint(x: repLayer.bounds.midX, y: 10)
        repLayer.addSublayer(t)
        repLayer.position = self.bounds.center
        repLayer.bounds.size = self.internalInset.size
        
        repLayer2.sublayers?.forEach({$0.removeFromSuperlayer()})
        let t2 = sg_tick()
        t2.strokeColor = sg_disabledFormattedColor(majorTicksColor ?? tintColor).cgColor
        t2.lineWidth = 2
        t2.position = CGPoint(x: repLayer2.bounds.midX, y: 10)
        repLayer2.addSublayer(t2)
        repLayer2.position = self.bounds.center
        repLayer2.bounds.size = self.internalInset.size
    }
    var pointerLength:CGFloat = 0.0
    
    func sg_createSublayers() {
        layer.addSublayer(repLayer2)
        layer.addSublayer(repLayer)
        layer.addSublayer(numeralsLayer)
        layer.addSublayer(trackLayer)
        
        overallPathLayer.addSublayer(pathLayer)
        overallPathLayer.addSublayer(headLayer)
        overallPathLayer.addSublayer(tailLayer)
        overallPathLayer.addSublayer(titleTextLayer)
        layer.addSublayer(overallPathLayer)
        layer.addSublayer(gradientLayer)
        gradientLayer.addSublayer(topHeadLayer)
        gradientLayer.addSublayer(topTailLayer)
        sg_update()
        strokeColor = sg_disabledFormattedColor(tintColor)
    }
    override public init(frame: CGRect) {
        super.init(frame:frame)
        //        self.addConstraint(NSLayoutConstraint(item: self, attribute: .Width, relatedBy: .Equal, toItem: self    , attribute: .Height, multiplier: 1, constant: 0))
        // tintColor = UIColor ( red: 0.755, green: 0.0, blue: 1.0, alpha: 1.0 )
        backgroundColor = UIColor ( red: 0.1149, green: 0.115, blue: 0.1149, alpha: 0.0 )
        sg_createSublayers()
    }
    
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        
        //tintColor = UIColor ( red: 0.755, green: 0.0, blue: 1.0, alpha: 1.0 )
        backgroundColor = UIColor ( red: 0.1149, green: 0.115, blue: 0.1149, alpha: 0.0 )
        sg_createSublayers()
    }
    
    
    fileprivate var backingValue: Float = 0.0
    
    /** Contains the receiver’s current value. */
    var value: Float {
        get { return backingValue }
        set { setValue(newValue, animated: false) }
    }
    
    /** Sets the receiver’s current value, allowing you to animate the change visually. */
    func setValue(_ value: Float, animated: Bool) {
        if value != backingValue {
            backingValue = min(maximumValue, max(minimumValue, value))
        }
    }
    
    /** Contains the minimum value of the receiver. */
    var minimumValue: Float = 0.0
    
    /** Contains the maximum value of the receiver. */
    var maximumValue: Float = 1.0
    
    /** Contains a Boolean value indicating whether changes
     in the sliders value generate continuous sg_update events. */
    var continuous = true
    var valueChanged = false
    
    
    var pointMover:((CGPoint) ->())?
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !disabled  else {
            pointMover = nil
            return
        }
        
        //        touches.forEach { (touch) in
        let touch = touches.first!
        let pointOfTouch = touch.location(in: self)
        guard let layer = self.overallPathLayer.hitTest( pointOfTouch ) else { return }
        //         superview:UIView
        //        for superview in touch.gestureRecognizers!{
        //            guard let superview = superview as? UIPanGestureRecognizer else {  continue }
        //            superview.isEnabled = false
        //            superview.isEnabled = true
        //            break
        //        }
        
        var prev = pointOfTouch
        let pointerMoverProducer: (@escaping (CGPoint) -> Angle, @escaping (Angle)->()) -> (CGPoint) -> () = { g, s in
            return { p in
                let c = self.layer.center
                let computedP = CGPoint(x: p.x, y: self.layer.bounds.height - p.y)
                let v1 = CGVector(from: c, to: computedP)
                let v2 = CGVector(angle:g( p ))
                
                s(clockDescretization(CGVector.signedTheta(v1, vec2: v2)))
                self.sg_update()
            }
            
        }
        
        switch(layer){
        case headLayer:
            if (shouldMoveHead) {
                pointMover = pointerMoverProducer({ _ in self.headAngle}, {self.headAngle += $0; self.tailAngle += 0})
            } else {
                pointMover = nil
            }
        case tailLayer:
            if (shouldMoveHead) {
                pointMover = pointerMoverProducer({_ in self.tailAngle}, {self.headAngle += 0;self.tailAngle += $0})
            } else {
                pointMover = nil
            }
        case pathLayer:
            if (shouldMoveHead) {
                pointMover = pointerMoverProducer({ pt in
                    let x = CGVector(from: self.bounds.center,
                                     to:CGPoint(x: prev.x, y: self.layer.bounds.height - prev.y)).theta;
                    prev = pt;
                    return x
                }, {self.headAngle += $0; self.tailAngle += $0 })
            } else {
                pointMover = nil
            }
        default: break
        }
        
        
        
    }
    override open  func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        //        while var superview = self.superview{
        //            guard let superview = superview as? UIScrollView else {  continue }
        //            superview.scrollEnabled = true
        //            break
        //        }
    }
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        pointMover = nil
        //        while var superview = self.superview{
        //            guard let superview = superview as? UIScrollView else {  continue }
        //            superview.scrollEnabled = true
        //            break
        //        }
        //        do something
        //        valueChanged = false
        delegate?.sg_timesChanged?(self, startDate: self.startDate, endDate: endDate)
    }
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let pointMover = pointMover else { return }
        //        print(touch.locationInView(self))
        pointMover(touch.location(in: self))
        
        delegate?.sg_timesUpdated?(self, startDate: self.startDate, endDate: endDate)
        
        
    }
    
}

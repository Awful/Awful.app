//  Geometry.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

func - (lhs: CGPoint, rhs: CGSize) -> CGPoint {
    return CGPoint(x: lhs.x - rhs.width, y: lhs.y - rhs.height)
}

extension CGSize {
    /// Returns true if the size's area is 0.
    var isEmpty: Bool {
        return width == 0 || height == 0
    }
    
    func sizeByInsetting(insets: UIEdgeInsets) -> CGSize {
        return CGSize(width: width - insets.left - insets.right, height: height - insets.top - insets.bottom)
    }
    
    /// Returns a size that contains both this size and the other size.
    func sizeByUnion(other: CGSize) -> CGSize {
        return CGSize(width: max(width, other.width), height: max(height, other.height))
    }
}

func + (lhs: CGSize, rhs: CGSize) -> CGSize {
    return CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
}

func - (lhs: CGSize, rhs: CGSize) -> CGSize {
    return CGSize(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
}

func * (lhs: CGFloat, rhs: CGSize) -> CGSize {
    return CGSize(width: lhs * rhs.width, height: lhs * rhs.height)
}

func * (lhs: CGSize, rhs: CGFloat) -> CGSize {
    return rhs * lhs
}

func / (lhs: CGSize, rhs: CGFloat) -> CGSize {
    return CGSize(width: lhs.width / rhs, height: lhs.height / rhs)
}

extension CGRect {
    init(size: CGSize, centeredInRect enclosure: CGRect) {
        assert(enclosure.width >= size.width && enclosure.height >= size.height)
        
        origin = enclosure.center - size / 2
        self.size = size
    }
    
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
    
    func rectByInsetting(insets: UIEdgeInsets) -> CGRect {
        return UIEdgeInsetsInsetRect(self, insets)
    }
    
    /// Returns a new rectangle whose given edge is moved distance points towards its center.
    func rectByShrinking(distance: CGFloat, fromEdge edge: CGRectEdge) -> CGRect {
        switch edge {
        case .MinXEdge:
            return CGRect(x: minX + distance, y: minY, width: width - distance, height: height)
        case .MaxXEdge:
            return CGRect(x: minX, y: minY, width: width - distance, height: height)
        case .MinYEdge:
            return CGRect(x: minX, y: minY + distance, width: width, height: height - distance)
        case .MaxYEdge:
            return CGRect(x: minX, y: minY, width: width, height: height - distance)
        }
    }
    
    /**
    Returns two new rectangles: one called "slice" which includes the given edge and extends distance points beyond; and one called "remainder" that contains the remainder of the initial rectangle after leaving gap points between slice and remainder.
    
    If gap is 0, the return value is identical to that of rectsByDividing(_:fromEdge:).
    */
    func rectsByDividing(distance: CGFloat, fromEdge edge: CGRectEdge, withGap gap: CGFloat) -> (slice: CGRect, remainder: CGRect) {
        let (slice, ungappedRemainder) = rectsByDividing(distance, fromEdge: edge)
        return (slice: slice, remainder: ungappedRemainder.rectByShrinking(gap, fromEdge: edge))
    }
}

extension UIEdgeInsets {
    init(left: CGFloat, right: CGFloat) {
        self.left = left
        self.right = right
        top = 0
        bottom = 0
    }
    
    init(horizontal: CGFloat, vertical: CGFloat) {
        left = horizontal
        right = horizontal
        top = vertical
        bottom = vertical
    }
    
    var horizontal: CGFloat {
        return left + right
    }
    
    var vertical: CGFloat {
        return top + bottom
    }
}

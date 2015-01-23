/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASTextNodeTextKitHelpers.h"

#pragma mark - Convenience

CGSize ASTextKitComponentsSizeForConstrainedWidth(ASTextKitComponents components, CGFloat constrainedWidth)
{
  // If our text-view's width is already the constrained width, we can use our existing TextKit stack for this sizing calculation.
  // Otherwise, we create a temporary stack to size for `constrainedWidth`.
  if (CGRectGetWidth(components.textView.bounds) != constrainedWidth) {
    components = ASTextKitComponentsCreate(components.textStorage, CGSizeMake(constrainedWidth, FLT_MAX));
  }

  // Force glyph generation and layout, which may not have happened yet (and isn't triggered by -usedRectForTextContainer:).
  [components.layoutManager ensureLayoutForTextContainer:components.textContainer];
  CGSize textSize = [components.layoutManager usedRectForTextContainer:components.textContainer].size;

  return textSize;
}

ASTextKitComponents ASTextKitComponentsCreate(NSAttributedString *attributedSeedString, CGSize textContainerSize)
{
  ASTextKitComponents components;

  // Create the TextKit component stack with our default configuration.
  components.textStorage = (attributedSeedString ? [[NSTextStorage alloc] initWithAttributedString:attributedSeedString] : [[NSTextStorage alloc] init]);

  components.layoutManager = [[NSLayoutManager alloc] init];
  [components.textStorage addLayoutManager:components.layoutManager];

  components.textContainer = [[NSTextContainer alloc] initWithSize:textContainerSize];
  components.textContainer.lineFragmentPadding = 0.0; // We want the text laid out up to the very edges of the text-view.
  [components.layoutManager addTextContainer:components.textContainer];

  return components;
}

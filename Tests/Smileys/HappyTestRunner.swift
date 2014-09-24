//  HappyTestRunner.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/*
Without these two imports, the test runner fails with an error like:

  > The bundle “SmileyTests” couldn’t be loaded because it is damaged or missing necessary resources.
  > Library not loaded: @rpath/libswiftUIKit.dylib
*/
import CoreImage
import UIKit

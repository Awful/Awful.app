//  CommonSPM.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

// The CommonSPM framework exists so we can use SPM for dependencies that are used by multiple targets without any "class is defined in … and …" issues, so we simply re-export the relevant modules here.
// When the project has been broken up into Swift modules, this might not be useful anymore.
@_exported import HTMLReader
@_exported import PromiseKit

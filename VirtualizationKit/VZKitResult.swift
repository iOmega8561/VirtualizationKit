//
//  Copyright (C) Giuseppe Rocco - All Rights Reserved
//  Unauthorized copying, modification or distribution of this source code,
//  via any medium is strictly prohibited and penally persecutable
//
//  This project and its source code are PROPRIETARY AND CONFIDENTIAL
//  Written by Giuseppe Rocco <giusepperocco38@gmail.com>, May 2024
//
//  -----------------------------------------------------------------------
//
//  VZKitResult.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

public typealias VZKitResult<TemplateType: VZKitTemplate> = Result<VirtualMachine<TemplateType>, Error>

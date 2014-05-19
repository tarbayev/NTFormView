//
//  NTFormView.h
//  NTFormView
//
//  Created by Nickolay Tarbayev on 12.10.12.
//  Copyright (c) 2012 Tarbayev. All rights reserved.
//


@interface UIView (FindFirstResponder)
- (UIView *)findFirstResponder;
- (BOOL)switchToNextFirstResponder;
@end


@interface NTFormView : UIScrollView

@property(nonatomic) UIEdgeInsets editableInsets;

@end

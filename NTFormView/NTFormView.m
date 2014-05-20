//
//  NTFormView.m
//  NTFormView
//
//  Created by Nickolay Tarbayev on 12.10.12.
//  Copyright (c) 2012 Tarbayev. All rights reserved.
//

#import "NTFormView.h"

@implementation NSIndexPath (Extended)

- (NSIndexPath *)indexPathByAppendingIndexPath:(NSIndexPath *)indexPath {
    if (indexPath == nil)
        return self;
    
    NSUInteger length = self.length + indexPath.length;
    
    NSUInteger indexes[length];
    
    [self getIndexes:indexes];
    
    NSUInteger *appendingIndexes = &indexes[self.length];
    
    [indexPath getIndexes:appendingIndexes];
    
    NSIndexPath *result = [NSIndexPath indexPathWithIndexes:indexes length:length];
    
    return result;
}

- (NSIndexPath *)indexPathByRemovingFirstIndex {
    
    if (self.length == 0)
        return self;
    
    NSUInteger indexes[self.length];
    
    [self getIndexes:indexes];
    
    NSUInteger *resultIndexes = &indexes[1];
    
    NSIndexPath *result = [NSIndexPath indexPathWithIndexes:resultIndexes length:self.length - 1];
    
    return result;
}

@end


@implementation UIView (FindFirstResponder)

- (UIView *)findFirstResponder {
    return [self findFirstResponderIndex:NULL];
}

- (UIView *)findFirstResponderIndex:(NSIndexPath *__autoreleasing*)indexPath {
    if (self.isFirstResponder)
        return self;
    
    __block NSUInteger subviewIndex = NSNotFound;
    __block UIView *firstResponder = nil;
    __block NSIndexPath *subviewIndexPath = nil;
    
    [self.subviews enumerateObjectsUsingBlock:^(UIView *subView, NSUInteger idx, BOOL *stop) {
        NSIndexPath *indexPath;
        firstResponder = [subView findFirstResponderIndex:&indexPath];
        
        if (firstResponder != nil) {
            subviewIndex = idx;
            subviewIndexPath = indexPath;
            *stop = YES;
        }
    }];
    
    if (firstResponder && indexPath) {
        *indexPath = [[NSIndexPath indexPathWithIndex:subviewIndex] indexPathByAppendingIndexPath:subviewIndexPath];
    }
    
    return firstResponder;
}

- (BOOL)switchToNextFirstResponder {
    NSIndexPath *indexPath;
    [self findFirstResponderIndex:&indexPath];
    
    return [self _switchToNextFirstResponderFrom:indexPath];
}

- (BOOL)_switchToNextFirstResponderFrom:(NSIndexPath *)currentIndexPath {
    if (!self.isFirstResponder && self.becomeFirstResponder)
        return YES;
    
    __block BOOL result = NO;
    __block NSUInteger firstIndex = NSNotFound;
    __block NSUInteger lastIndex = NSNotFound;
    
    [self.subviews enumerateObjectsUsingBlock:^(UIView *subView, NSUInteger idx, BOOL *stop) {
        if ([subView _switchToNextFirstResponderFrom:[currentIndexPath indexPathByRemovingFirstIndex]]) {
            if (!result) {
                firstIndex = idx;
                result = YES;
            }
            
            lastIndex = idx;
            *stop = idx > [currentIndexPath indexAtPosition:0];
        }
    }];
    
    if (lastIndex != NSNotFound && lastIndex == [currentIndexPath indexAtPosition:0])
        [self.subviews[firstIndex] becomeFirstResponder];
    
    return result;
}

@end


@implementation UIView (SpecificClassDescendants)

- (NSArray *)descendantViewsOfClass:(Class)class {
    NSMutableArray *result = [NSMutableArray new];
    
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:class])
            [result addObject:subview];
        
        [result addObjectsFromArray:[subview descendantViewsOfClass:class]];
    }
    
    return result;
}

@end


@interface NTFormView () <UIGestureRecognizerDelegate, UITextFieldDelegate>

@end


@implementation NTFormView {
    CGRect _keyboardFrame;
    BOOL _fixedContentSize;
    
    UITapGestureRecognizer *_tapGestureRecognizer;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (!_fixedContentSize)
        [super setContentSize:self.bounds.size];
}

- (void)setEditableInsets:(UIEdgeInsets)editableInsets {
    _editableInsets = editableInsets;
    
    if ([self findFirstResponder])
        [self adjustForKeyboard:0];
}

- (void)setContentSize:(CGSize)contentSize {
    _fixedContentSize = YES;
    [super setContentSize:contentSize];
}

- (void)didMoveToWindow {
    if (self.window == nil)
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    else {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillShow:)
                                                     name:UIKeyboardWillShowNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillHide:)
                                                     name:UIKeyboardWillHideNotification
                                                   object:nil];
        
        for (UITextField *field in [self descendantViewsOfClass:[UITextField class]]) {
            if (!field.delegate)
                field.delegate = self;
        }
    }
}


#pragma mark - Private Methods

- (void)commonInit {
    _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(endEditing)];
    _tapGestureRecognizer.cancelsTouchesInView = NO;
    _tapGestureRecognizer.delegate = self;
    [self addGestureRecognizer:_tapGestureRecognizer];
}

- (void)setTransform:(CGAffineTransform)transform {
    [super setTransform:transform];
    
    if ([self findFirstResponder]) {
        [self adjustForKeyboard:0];
    }
}

- (void)adjustForKeyboard:(NSTimeInterval)animationDuration {
    CGRect keyboardFrame = [self convertRect:_keyboardFrame fromView:nil];
    keyboardFrame.origin.y -= self.bounds.origin.y;
    
    CGFloat bottomInset = MAX(self.bounds.size.height - keyboardFrame.origin.y, 0);
    bottomInset -= _editableInsets.bottom;
    
    dispatch_block_t adjustments = ^{
        CGFloat top = MIN(self.contentSize.height + bottomInset - self.bounds.size.height, _editableInsets.top);
        top = MAX(top, 0);
        
        self.contentInset = UIEdgeInsetsMake(-top, 0, bottomInset, 0);
        self.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, bottomInset, 0);
    };
    
    if (animationDuration == 0 || self.layer.animationKeys.count > 0)
        adjustments();
    else
        [UIView animateWithDuration:animationDuration animations:adjustments];
}


#pragma mark - UIGestureRecognizerDelegate Methods

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (gestureRecognizer == _tapGestureRecognizer)
        return ![touch.view isKindOfClass:[UIControl class]];
    
    return YES;
}


#pragma mark - UITextFieldDelegate Methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    if (textField.returnKeyType == UIReturnKeyDone) {
        [textField resignFirstResponder];
        return NO;
    }
    
    return ![self switchToNextFirstResponder];
}


#pragma mark - Action Methods

- (void)endEditing {
    [self endEditing:YES];
}


#pragma mark - Notification Methods

- (void)keyboardWillShow:(NSNotification *)notification {
    
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    _keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    UIView *firstResponder = [self findFirstResponder];
    
    CGRect firstResponderRect = [self convertRect:firstResponder.frame fromView:firstResponder.superview];
    
    firstResponderRect = CGRectInset(firstResponderRect, 0, -20);
    
    [self adjustForKeyboard:duration];
    
    [self scrollRectToVisible:firstResponderRect animated:YES];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    [UIView animateWithDuration:duration animations:^{
        self.contentInset = UIEdgeInsetsZero;
        self.scrollIndicatorInsets = UIEdgeInsetsZero;
    }];
}

@end

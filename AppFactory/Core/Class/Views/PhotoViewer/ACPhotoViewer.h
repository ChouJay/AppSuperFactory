//
//  ACPhotoViewer.h
//  AppFactory
//
//  Created by alan on 2021/5/25.
//  Copyright © 2021 alan. All rights reserved.
//

#import <UIKit/UIKit.h>

// Source code:
// https://github.com/huang-kun/AFTPhotoScroller

@class ACPhotoViewer;

@protocol ACPhotoViewerDelegate <NSObject>
@optional
- (void)photoViewer:(ACPhotoViewer *)photoViewer scrollToPageAtIndex:(NSUInteger)index;
- (void)photoViewer:(ACPhotoViewer *)photoViewer didShowPhotoAtIndex:(NSUInteger)index;
@end

@interface ACPhotoViewer : UIView

@property (nonatomic, weak) id <ACPhotoViewerDelegate> delegate;

- (id)initWithURLs:(NSArray *)urls;

- (NSInteger)currentIndex;
- (NSInteger)numberOfPages;

- (void)reloadData;
- (void)reloadWithUrls:(NSArray *)urls;
- (void)showPageAtIndex:(NSInteger)index; // no animation

@end


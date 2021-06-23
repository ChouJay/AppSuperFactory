//
//  ACPhotoViewer.m
//  AppFactory
//
//  Created by alan on 2021/5/25.
//  Copyright © 2021 alan. All rights reserved.
//

#import "ACPhotoViewer.h"
#import "AFTPagingScrollView.h"
#import "AFTImageScrollView.h"

#import "AppFactory.h"
#import "LibsHeader.h"

@interface ACPhotoViewer()<AFTPagingScrollViewDataSource, AFTPagingScrollViewDelegate>
@property (nonatomic, strong) UIImage *placeholderImage;
@property (nonatomic, strong) AFTPagingScrollView *mainScrollView;
@property (nonatomic, strong) NSArray *urls;
@property (nonatomic) BOOL isReloadDataReady;

@end

@implementation ACPhotoViewer

#pragma mark - Life Cycle

- (id)initWithURLs:(NSArray *)urls;
{
    ACPhotoViewer *v = [[[self class] alloc] initWithFrame:CGRectMake(0, 0, 320, 480) urls:urls];
    return v;
}

- (instancetype)initWithFrame:(CGRect)frame urls:(NSArray *)urls
{
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = YES;
        self.backgroundColor = [UIColor clearColor];
        self.urls = urls;

        [self addSubview:self.mainScrollView];
        [self.mainScrollView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
        self.mainScrollView.delegate = self;
        self.mainScrollView.dataSource = self;
        self.mainScrollView.paddingBetweenPages = 6;
        
        [self reloadData];
    }
    
    return self;
}

-(void)layoutSubviews{
    [super layoutSubviews];
}

#pragma mark - AFTPagingScrollViewDataSource

- (NSInteger)numberOfPagesInPagingScrollView:(AFTPagingScrollView *)pagingScrollView {
    return [self.urls count];
}

- (UIImage *)pagingScrollView:(AFTPagingScrollView *)pagingScrollView imageForPageAtIndex:(NSInteger)pageIndex {
    
//    NSLog(@"imageForPageAtIndex %zd",pageIndex);

    __weak __typeof(self) weakSelf = self;
    NSString *url = [self.urls safelyObjectAtIndex:pageIndex];
    if(!url){
        return self.placeholderImage;
    }
    UIImage *imageCached = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:url];

    if(imageCached){
        return imageCached;
    }else{
//        NSLog(@"Start to load image at index %zd",pageIndex);
        [self downloadImageAtPageIndex:pageIndex completion:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf showSpinnerAtPageIndex:pageIndex show:NO];
                if(success){
                    [weakSelf.mainScrollView reloadPageAtIndex:pageIndex];
                }
            });
        }];
    }
    

    return self.placeholderImage;
}

#pragma mark - AFTPagingScrollViewDelegate

- (void)pagingScrollView:(AFTPagingScrollView *)pagingScrollView didCreateImageScrollView:(UIScrollView *)imageScrollView
{
    if(![self.delegate respondsToSelector:@selector(pageCoverView)]){
        return;
    }
    
    UIView *coverView = [self.delegate pageCoverView];
    [imageScrollView addSubview:coverView];
    ((AFTImageScrollView *)imageScrollView).customCoverView = coverView;

    [coverView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(@0);
        make.top.equalTo(@0);
        make.height.equalTo(imageScrollView.mas_height);
        make.width.equalTo(imageScrollView.mas_width);
    }];
}

- (void)pagingScrollView:(AFTPagingScrollView *)pagingScrollView
         imageScrollView:(UIScrollView *)imageScrollView
    didReuseForPageIndex:(NSInteger)pageIndex
{
//    NSLog(@"didDisplayPageAtIndex %zd",pageIndex);
    
    [self configCustomCoverViewAtIndex:pageIndex-1];
    [self configCustomCoverViewAtIndex:pageIndex];
    [self configCustomCoverViewAtIndex:pageIndex+1];

    NSString *url = [self.urls safelyObjectAtIndex:pageIndex];
    if(url){
        UIImage *imageCached = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:url];
        if(!imageCached){
            [self showSpinnerAtPageIndex:pageIndex show:YES];
            return;
        }
    }
    
    [self showSpinnerAtPageIndex:pageIndex show:NO];
}

- (void)pagingScrollView:(AFTPagingScrollView *)pagingScrollView didDisplayPageAtIndex:(NSInteger)pageIndex
{
    [self configCustomCoverViewAtIndex:pageIndex-1];
    [self configCustomCoverViewAtIndex:pageIndex];
    [self configCustomCoverViewAtIndex:pageIndex+1];
    
    if(pageIndex >= 0 && [self.urls count] ){
        if([self.delegate respondsToSelector:@selector(photoViewer:didShowPhotoAtIndex:)]){
            [self.delegate photoViewer:self didShowPhotoAtIndex:pageIndex];
        }
    }
}

- (void)pagingScrollView:(AFTPagingScrollView *)pagingScrollView didScrollToPageAtIndex:(NSInteger)pageIndex
{
    [self configCustomCoverViewAtIndex:pageIndex-1];
    [self configCustomCoverViewAtIndex:pageIndex];
    [self configCustomCoverViewAtIndex:pageIndex+1];
    
    if(pageIndex >= 0 && [self.urls count] && self.isReloadDataReady){
        if([self.delegate respondsToSelector:@selector(photoViewer:scrollToPageAtIndex:)]){
            [self.delegate photoViewer:self scrollToPageAtIndex:pageIndex];
        }
    }
    
    if(!self.isReloadDataReady){
        self.isReloadDataReady = YES;
    }
}

#pragma mark - Private

- (void)configCustomCoverViewAtIndex:(NSInteger)pageIndex
{
    if( [self.urls count] == 0 || pageIndex > [self.urls count] || pageIndex < 0){
        return;
    }
    
    BOOL showCoverView = NO;
    if([self.delegate respondsToSelector:@selector(photoViewer:showCoverViewAtIndex:)]){
        showCoverView = [self.delegate photoViewer:self showCoverViewAtIndex:pageIndex];
    }
    
    AFTImageScrollView *page = [self.mainScrollView pageForIndex:pageIndex];
    if(!page){
        return;
    }
    
    page.customCoverView.hidden = !showCoverView;
    page.userInteractionEnabled = !showCoverView;
}

- (void)downloadImageAtPageIndex:(NSInteger)pageIndex completion:(void (^)(BOOL success))completion{
    
    NSString *urlStr = [self.urls safelyObjectAtIndex:pageIndex];
    if(!urlStr){
        if(completion)completion(NO);
        return;;
    }

    NSURL *url = [NSURL URLWithString:urlStr];
    [[SDWebImageManager sharedManager] loadImageWithURL:url options:SDWebImageRetryFailed progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, SDImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL)
    {
        if(image && !error){
            if(completion)completion(YES);
        }else{
            if(completion)completion(NO);
        }
    }];
}

- (void)showSpinnerAtPageIndex:(NSInteger)pageIndex show:(BOOL)show
{
    AFTImageScrollView *page = [self.mainScrollView pageForIndex:pageIndex];
    if(show){
        [page.af_spinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhite];
        [page bringSubviewToFront:page.af_spinner];
        [page.af_spinner startAnimating];
    }else{
        [page.af_spinner stopAnimating];
    }
}

#pragma mark - Public

- (void)reloadData
{
    self.isReloadDataReady = NO;
    [self.mainScrollView reloadData];
}

- (void)reloadWithUrls:(NSArray *)urls
{
    self.isReloadDataReady = NO;
    NSInteger i = [self currentIndex];
    self.urls = urls;
    [self.mainScrollView reloadData];
    [self showPageAtIndex:i];
}

- (void)showPageAtIndex:(NSInteger)index
{
    NSInteger count = [self.urls count];
    if (count== 0) {
        return;
    }
    index = MIN( MAX(0, index), count - 1);
    [self.mainScrollView displayPageAtIndex:index];
}

- (NSInteger)currentIndex
{
    return self.mainScrollView.currentPageIndex;
}

- (NSInteger)numberOfPages
{
    return self.mainScrollView.numberOfPages;
}

#pragma mark - Setter & Getter

-(AFTPagingScrollView *)mainScrollView
{
    if(!_mainScrollView){
        _mainScrollView = ({
            AFTPagingScrollView *v = [[AFTPagingScrollView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
            v;
        });
    }
    
    return _mainScrollView;
}
-(UIImage *)placeholderImage
{
    if(!_placeholderImage){
        _placeholderImage = ({
            CGRect rect = CGRectMake(0, 0, self.size.width, self.size.height);
            UIColor *bgColor = [UIColor blackColor];
            UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0);
            [bgColor setFill];
            UIRectFill(rect);
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            image;
        });
    }
    
    return _placeholderImage;
}


@end
//
//  QAImageBrowserViewController.m
//  TableView
//
//  Created by Avery An on 2020/4/30.
//  Copyright © 2020 Avery. All rights reserved.
//

#import "QAImageBrowserViewController.h"
#import "QAImageBrowserLayout.h"
#import "QAImageBrowserCell.h"
#import "QAImageBrowserDownloadManager.h"
#import "SDWebImageManager.h"

static void *CollectionContext = &CollectionContext;

@interface QAImageBrowserViewController () <UICollectionViewDelegate, UICollectionViewDataSource>
@property (nonatomic) UIView *blackBackgroundView;
@property (nonatomic) QAImageBrowserLayout *layout;
@property (nonatomic) UICollectionView *collectionView;
@property (nonatomic, copy) NSArray *images;
@property (nonatomic) QAImageBrowserDownloadManager *imageDownloadManager;
@property (nonatomic) NSMutableArray *preloadImages;
@property (nonatomic, assign) NSUInteger currentPosition;
@property (nonatomic, unsafe_unretained) YYAnimatedImageView *tapedImageView;
@property (nonatomic, unsafe_unretained) UIView *tapedSuperView;
@property (nonatomic) YYAnimatedImageView *currentShowingImageView;
@property (nonatomic) CGRect tapedImageViewRect;
@property (nonatomic, assign) CGFloat rectOffsetX;
@property (nonatomic, assign) CGFloat rectOffsetY;
@property (nonatomic, assign) CGFloat collectionOffsetX_began;
@property (nonatomic, assign) int collectionOffsetX_tmp;
@property (nonatomic) UIPanGestureRecognizer *panGestureRecognizer;
@property (nonatomic, unsafe_unretained) QAImageBrowserCell *currentImageBrowserCell;
@property (nonatomic, unsafe_unretained) QAImageBrowserCell *firstImageBrowserCell;
@property (nonatomic, unsafe_unretained) QAImageBrowserCell *previousImageBrowserCell;
@property (nonatomic) CGRect imageViewRectInCell;
@property (nonatomic) CGAffineTransform imageViewTransformInCell;
@property (nonatomic, copy) QAImageBrowserFinishedBlock finishedBlock;
@end

@implementation QAImageBrowserViewController

#pragma mark - Life Cycle -
- (void)dealloc {
    NSLog(@"%s", __func__);
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}


#pragma mark - Public Method -
- (void)showImageWithTapedObject:(UIImageView * _Nonnull)tapedImageView
                          images:(NSArray * _Nonnull)images
                        finished:(QAImageBrowserFinishedBlock _Nullable)finishedBlock {
    if (!tapedImageView || !images || ![images isKindOfClass:[NSArray class]] || images.count == 0) {
        NSLog(@"  tapedImageView: %@ 【 WTF 】!!!!!!!!", tapedImageView);
        return;
    }
    else if (images.count < 1) {
        return;
    }
    
    if (!self.imageDownloadManager) {
        self.imageDownloadManager = [[QAImageBrowserDownloadManager alloc] init];
    }
    self.finishedBlock = finishedBlock;
    self.tapedImageView = (YYAnimatedImageView *)tapedImageView;
    self.images = images;
    self.currentPosition = [self getTapedPosition];
    [self createImageBrowserBasicView];
    CGRect newRect = [self getTapedImageFrame];
    [self showImageBrowserViewWithFrame:newRect];
}


#pragma mark - Private Methods -
- (NSUInteger)getTapedPosition {
    NSUInteger result = 0;
    self.tapedSuperView = self.tapedImageView.superview;
    CGRect tapedRect = self.tapedImageView.frame;
    self.tapedImageViewRect = tapedRect;
    for (NSUInteger i = 0; i < self.images.count; i++) {
        NSDictionary *info = [self.images objectAtIndex:i];
        if ([info isKindOfClass:[NSDictionary class]]) {
            CGRect rect = [[info valueForKey:@"frame"] CGRectValue];
            if (CGRectEqualToRect(tapedRect, rect)) {   // NSDecimalNumber
                result = i;
                break;
            }
            else if (fabs(tapedRect.origin.x - rect.origin.x) <= 1 &&
                     fabs(tapedRect.origin.y - rect.origin.y) <= 1 &&
                     fabs(tapedRect.size.width - rect.size.width) <= 1 &&
                     fabs(tapedRect.size.height - rect.size.height) <= 1) {
                result = i;
                break;
            }
        }
        else {
            NSLog(@"QAImageBrowserManager - 传入参数有误!");
            break;
        }
    }
    return result;
}
- (CGRect)getTapedImageFrame {
    UIImage *image = self.tapedImageView.image;  // 缩略图的image
    CGRect rect = CGRectZero;
    if (image) {
        rect = [QAImageProcesser caculateOriginImageSize:image];
    }
    return rect;
}
- (void)createImageBrowserBasicView {
    if (!self.blackBackgroundView) {
        self.blackBackgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
        self.blackBackgroundView.backgroundColor = [UIColor blackColor];
    }
    self.blackBackgroundView.alpha = 0;
    [self.view addSubview:self.blackBackgroundView];

    [self addPanGestureRecognizer];

    [self.view addSubview:self.collectionView];
    CGFloat offsetX = self.currentPosition * self.collectionView.bounds.size.width;
    self.collectionOffsetX_began = offsetX;
    [self.collectionView setContentOffset:CGPointMake(offsetX, 0)];
    self.collectionView.hidden = YES;
}
- (void)removePanGestureRecognizer {
    if (self.view && self.panGestureRecognizer) {
        [self.view removeGestureRecognizer:self.panGestureRecognizer];
        self.panGestureRecognizer = nil;
    }
    else if (self.panGestureRecognizer) {
        UIWindow *window = [UIApplication sharedApplication].delegate.window;
        [window removeGestureRecognizer:self.panGestureRecognizer];
        self.panGestureRecognizer = nil;
    }
}
- (void)addPanGestureRecognizer {
    if (!self.panGestureRecognizer) {
        self.panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    }
    [self.view addGestureRecognizer:self.panGestureRecognizer];
}
- (void)showImageBrowserViewWithFrame:(CGRect)newFrame {
    CGRect rect = [self.tapedImageView convertRect:self.tapedSuperView.frame toView:self.view];
    self.rectOffsetX = rect.origin.x - self.tapedImageViewRect.origin.x;
    self.rectOffsetY = rect.origin.y - self.tapedImageViewRect.origin.y;
    self.tapedImageView.frame = CGRectMake(rect.origin.x, rect.origin.y, self.tapedImageViewRect.size.width, self.tapedImageViewRect.size.height);
    [self.view addSubview:self.tapedImageView];
    
    [UIView animateWithDuration:.25
                     animations:^{
        self.blackBackgroundView.alpha = 1;
        self.tapedImageView.frame = newFrame;
        
        /*
         [self.tapedImageView mas_remakeConstraints:^(MASConstraintMaker *make) {
             make.left.mas_equalTo(newFrame.origin.x);
             make.top.mas_equalTo(newFrame.origin.y);
             make.size.mas_equalTo(newFrame.size);
         }];
         [self.tapedImageView.superview layoutIfNeeded];
         */
    } completion:^(BOOL finished) {
        self.collectionView.hidden = NO;
        [self getCurrentShowingImageView:nil];
        [self.currentImageBrowserCell configImageView:self.tapedImageView defaultImage:self.tapedImageView.image];
        self.firstImageBrowserCell = self.currentImageBrowserCell;
    }];
}
- (void)panViewWithTransform:(CGAffineTransform)transform
                       alpha:(CGFloat)alpha
                      paning:(BOOL)paning {
    if (paning) {
        self.currentShowingImageView.transform = transform;
        self.blackBackgroundView.alpha = alpha;
    }
    else {
        [UIView animateWithDuration:0.2
                         animations:^{
            self.currentShowingImageView.transform = transform;
            self.blackBackgroundView.alpha = alpha;
        } completion:^(BOOL finished) {
            if (alpha == 1) {
                [self processQAImageBrowserCellAfterPanCanceled];
            }
        }];
    }
}
- (void)getCurrentShowingImageView:(QAImageBrowserCell *)imageBrowserCell {
    if (imageBrowserCell) {
        self.currentImageBrowserCell = imageBrowserCell;
    }
    else {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.currentPosition inSection:0];
        imageBrowserCell = (QAImageBrowserCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
        self.currentImageBrowserCell = imageBrowserCell;
    }
    
    YYAnimatedImageView *imageView = self.currentImageBrowserCell.currentShowImageView;
    self.currentShowingImageView = imageView;
}
- (void)processQAImageBrowserCellAfterPanCanceled {
    [self hideImageViewInCell:NO];
    
    UIImageView *imageView = self.currentShowingImageView;
    imageView.transform = self.imageViewTransformInCell;
    imageView.frame = self.imageViewRectInCell;
    [self.currentImageBrowserCell.scrollView addSubview:imageView];
}
- (void)processQAImageBrowserCellWhenPanBegan {
    [self getCurrentShowingImageView:nil];
    
    self.imageViewRectInCell = self.currentShowingImageView.frame;
    self.imageViewTransformInCell = self.currentShowingImageView.transform;
    CGRect imageNewFrame = CGRectMake(-self.currentImageBrowserCell.scrollView.contentOffset.x+self.imageViewRectInCell.origin.x, self.currentImageBrowserCell.scrollView.contentOffset.y+self.imageViewRectInCell.origin.y, self.imageViewRectInCell.size.width, self.imageViewRectInCell.size.height);
    self.currentShowingImageView.transform = CGAffineTransformIdentity;
    self.currentShowingImageView.frame = imageNewFrame;
    [self.view addSubview:self.currentShowingImageView];
}
- (void)hideImageViewInCell:(BOOL)hidden {
    NSDictionary *info = [self.images objectAtIndex:self.currentPosition];
    CGRect rect = [[info valueForKey:@"frame"] CGRectValue];
    for (UIImageView *imageView in self.tapedSuperView.subviews) {
        if (imageView && [imageView isKindOfClass:[UIImageView class]]) {
            if (CGRectEqualToRect(imageView.frame, rect)) {   // NSDecimalNumber
                imageView.hidden = hidden;
                break;
            }
            else if (fabs(imageView.frame.origin.x - rect.origin.x) <= 1 &&
                     fabs(imageView.frame.origin.y - rect.origin.y) <= 1 &&
                     fabs(imageView.frame.size.width - rect.size.width) <= 1 &&
                     fabs(imageView.frame.size.height - rect.size.height) <= 1) {
                imageView.hidden = hidden;
                break;
            }
        }
    }
}
- (CGRect)getOriginalFrameInTableViewAtIndex:(NSUInteger)index {
    CGRect rect = CGRectZero;
    if (index >= 0 && index < self.images.count) {
        NSDictionary *info = [self.images objectAtIndex:index];
        rect = [[info valueForKey:@"frame"] CGRectValue];
    }
    
    return rect;
}
- (void)quitImageBrowser {  // 退出图片浏览器
    [self hideImageViewInCell:YES];
    
    CGRect srcRectInTable = [self getOriginalFrameInTableViewAtIndex:self.currentPosition];  // 在tableView的cell中的坐标
    CGRect rectInWindow = CGRectZero;
    if (self.currentShowingImageView.superview == self.view) {
        rectInWindow = CGRectMake(srcRectInTable.origin.x + self.rectOffsetX, srcRectInTable.origin.y + self.rectOffsetY, srcRectInTable.size.width, srcRectInTable.size.height);
    }
    else {
        rectInWindow = CGRectMake(srcRectInTable.origin.x + self.rectOffsetX + self.currentImageBrowserCell.scrollView.contentOffset.x, srcRectInTable.origin.y + self.rectOffsetY + self.currentImageBrowserCell.scrollView.contentOffset.y, srcRectInTable.size.width, srcRectInTable.size.height);
    }
    [self moveView:self.currentImageBrowserCell toFrame:rectInWindow];
}
- (void)moveView:(QAImageBrowserCell *)imageBrowserCell toFrame:(CGRect)rectInWindow {
    [self removePanGestureRecognizer];
    imageBrowserCell.userInteractionEnabled = NO;
    
    [self quitAnimation:rectInWindow];
}
- (void)quitImageBrowser_directly {
    [self hideImageViewInCell:YES];
    
    [self getCurrentShowingImageView:nil];
    [self removePanGestureRecognizer];
    self.currentImageBrowserCell.userInteractionEnabled = NO;
    
    CGRect srcRect = [self getOriginalFrameInTableViewAtIndex:self.currentPosition];  // 在tableView的cell中的坐标
    CGRect rectInWindow = CGRectMake(srcRect.origin.x + self.rectOffsetX + self.currentImageBrowserCell.scrollView.contentOffset.x, srcRect.origin.y + self.rectOffsetY + self.currentImageBrowserCell.scrollView.contentOffset.y, srcRect.size.width, srcRect.size.height);
    
    [self quitAnimation:rectInWindow];
}
- (void)quitAnimation:(CGRect)rect {
    [UIView animateWithDuration:.2
                     animations:^{
        self.blackBackgroundView.alpha = 0;
        self.currentShowingImageView.frame = rect;
    } completion:^(BOOL finished) {
        [self cleanupTheBattlefield];
    }];
}
- (void)cleanupTheBattlefield {
    if (self.tapedImageView == self.currentShowingImageView) {   // 退出之前没有滑动collectionView去显示其它的imageView
        self.tapedImageView.transform = CGAffineTransformIdentity;
        [self.currentImageBrowserCell clearALLGesturesInView:self.tapedImageView];  // 删除在collectionView中添加的所有手势
        [self.tapedSuperView addSubview:self.tapedImageView];
        
        self.tapedImageView.frame = self.tapedImageViewRect;
        /*
         [self.tapedImageView mas_remakeConstraints:^(MASConstraintMaker *make) {
             make.left.mas_equalTo(self.tapedImageViewRect.origin.x);
             make.top.mas_equalTo(self.tapedImageViewRect.origin.y);
             make.size.mas_equalTo(self.tapedImageViewRect.size);
         }];
         */
    }
    else if (self.currentShowingImageView != self.tapedImageView) {
        int startPosition = self.collectionOffsetX_began / self.collectionView.bounds.size.width;
        NSUInteger difference = self.currentPosition - startPosition;
        long tag = self.tapedImageView.tag + difference;
        [[self.tapedSuperView viewWithTag:tag] removeFromSuperview];
        self.currentShowingImageView.tag = tag;
        
        CGRect srcRectInTable = [self getOriginalFrameInTableViewAtIndex:self.currentPosition];
        self.currentShowingImageView.transform = CGAffineTransformIdentity;
        [self.currentImageBrowserCell clearALLGesturesInView:self.tapedImageView];  // 删除在collectionView中添加的所有手势
        [self.tapedSuperView addSubview:self.currentShowingImageView];
        
        self.currentShowingImageView.frame = srcRectInTable;
        /*
         [self.currentShowingImageView mas_remakeConstraints:^(MASConstraintMaker *make) {
             make.left.mas_equalTo(srcRectInTable.origin.x);
             make.top.mas_equalTo(srcRectInTable.origin.y);
             make.size.mas_equalTo(srcRectInTable.size);
         }];
         */
    }
    
    /**
     [self.collectionView removeFromSuperview];
     self.collectionView = nil;
     [self.blackBackgroundView removeFromSuperview];
     self.blackBackgroundView = nil;
     */
    
    if (self.finishedBlock) {
        self.finishedBlock(self.currentPosition, self.currentShowingImageView);
    }
}
- (void)makeTapedImageViewBacktoOriginalStateWhenScroll {
    if (self.tapedImageView.superview != self.tapedSuperView) {
        [self makeTapedImageViewBacktoSrcTableView];
        [self.firstImageBrowserCell reprepareShowImageViewWithImageDownloadManager:self.imageDownloadManager];
    }
}
- (void)makeTapedImageViewBacktoSrcTableView {
    self.tapedImageView.transform = CGAffineTransformIdentity;
    self.tapedImageView.hidden = NO;
    [self.tapedSuperView addSubview:self.tapedImageView];
    
    self.tapedImageView.frame = self.tapedImageViewRect;
    /*
     [self.tapedImageView mas_remakeConstraints:^(MASConstraintMaker *make) {
         make.left.mas_equalTo(self.tapedImageViewRect.origin.x);
         make.top.mas_equalTo(self.tapedImageViewRect.origin.y);
         make.size.mas_equalTo(self.tapedImageViewRect.size);
     }];
     */
}
- (void)preloadImages:(NSInteger)position {
    if (!self.preloadImages) {
        self.preloadImages = [NSMutableArray arrayWithCapacity:2];
    }
    else {
        [self.preloadImages removeAllObjects];
    }

    if (position - 1 >= 0) {
        NSDictionary *dic = [self.images objectAtIndex:(position-1)];
        NSString *imageUrlString = [dic valueForKey:@"url"];
        if (imageUrlString) {
            [self.preloadImages addObject:[NSURL URLWithString:imageUrlString]];
        }
    }
    if (position + 1 < self.images.count) {
        NSDictionary *dic = [self.images objectAtIndex:(position+1)];
        NSString *imageUrlString = [dic valueForKey:@"url"];
        if (imageUrlString) {
            [self.preloadImages addObject:[NSURL URLWithString:imageUrlString]];
        }
    }
    
    [self.imageDownloadManager downloadImages:self.preloadImages];
}


#pragma mark - Gesture Actions -
- (void)singleTapAction:(QAImageBrowserCell *)imageBrowserCell {
    [self getCurrentShowingImageView:imageBrowserCell];
    [self quitImageBrowser];
}
- (void)longPressAction:(QAImageBrowserCell *)imageBrowserCell {
    NSLog(@"%s",__func__);
}
- (void)handlePan:(UIPanGestureRecognizer *)panGesture {
    CGPoint transPoint = [panGesture translationInView:self.view];
    CGPoint velocity = [panGesture velocityInView:self.view];
    CGPoint locationInView = [panGesture locationInView:self.view];

    switch (panGesture.state) {
        case UIGestureRecognizerStateBegan: {
            // 将cell中与其对应的imageView进行隐藏:
            [self hideImageViewInCell:YES];
            
            [self processQAImageBrowserCellWhenPanBegan];
        }
        break;

        case UIGestureRecognizerStateChanged: {
            [self.collectionView setScrollEnabled:NO];
            
            float alpha = 1 - fabs(transPoint.y) / self.view.bounds.size.height;
            alpha = MAX(alpha, 0.2);
            float scale = MAX(alpha, 0.6);
            CGFloat reduceValue = self.currentShowingImageView.bounds.size.width * (1-scale);
            reduceValue = ( (locationInView.x - self.currentShowingImageView.center.x ) / (self.currentShowingImageView.bounds.size.width/2) * reduceValue ) / 2;
            CGAffineTransform translationTransform = CGAffineTransformMakeTranslation(transPoint.x / scale + reduceValue, transPoint.y / scale);
            CGAffineTransform scaleTransform = CGAffineTransformMakeScale(scale, scale);
            CGAffineTransform totalTransform = CGAffineTransformConcat(translationTransform, scaleTransform);
            [self panViewWithTransform:totalTransform alpha:alpha paning:YES];
        }
        break;

        case UIGestureRecognizerStateEnded: {
            if (fabs(transPoint.y) > 160 || fabs(velocity.y) > 400) {
                [self quitImageBrowser];
            }
            else {
                [self panViewWithTransform:CGAffineTransformIdentity alpha:1 paning:NO];  // 返回到初始状态
            }

            [self.collectionView setScrollEnabled:YES];
        }
        break;

        case UIGestureRecognizerStateCancelled: {
            [self panViewWithTransform:CGAffineTransformIdentity alpha:1 paning:NO];  // 返回到初始状态
            [self.collectionView setScrollEnabled:YES];
        }
        break;

        default:{
            [self panViewWithTransform:CGAffineTransformIdentity alpha:1 paning:NO];  // 返回到初始状态
            [self.collectionView setScrollEnabled:YES];
        }
        break;
    }
}


#pragma mark - UICollectionView DataSource -
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.images.count;
}
//- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
//    if (kind == QAImageBrowser_headerIdentifier) {
//    }
//    else if (kind == QAImageBrowser_footerIdentifier) {
//    }
//
//    return nil;
//}
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    QAImageBrowserCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:QAImageBrowser_cellID forIndexPath:indexPath];
    
    __weak typeof(self) weakself = self;
    cell.gestureActionBlock = ^(QAImageBrowserViewAction action, QAImageBrowserCell * _Nullable imageBrowserCell) {
        __strong typeof(self) strongSelf = weakself;
        switch (action) {
            case QAImageBrowserViewAction_SingleTap: {
                [strongSelf singleTapAction:imageBrowserCell];
            }
                break;
            case QAImageBrowserViewAction_LongPress: {
                [strongSelf longPressAction:imageBrowserCell];
            }
                break;

            default:
                break;
        }
    };
    
    // 当前cell内容的绘制:
    NSDictionary *dic = [self.images objectAtIndex:indexPath.row];
    [cell configContent:dic defaultImage:nil contentMode:self.tapedImageView.contentMode withImageDownloadManager:self.imageDownloadManager];
    
    // 本cell临近位置的图片预加载:
    [self preloadImages:indexPath.row];
    
    return cell;
}


/*
#pragma mark - UICollectionViewDelegate -

// (when the touch begins)
// 1. -collectionView:shouldHighlightItemAtIndexPath:
// 2. -collectionView:didHighlightItemAtIndexPath:
//
// (when the touch lifts)
// 3. -collectionView:shouldSelectItemAtIndexPath: or -collectionView:shouldDeselectItemAtIndexPath:
// 4. -collectionView:didSelectItemAtIndexPath: or -collectionView:didDeselectItemAtIndexPath:
// 5. -collectionView:didUnhighlightItemAtIndexPath:

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"   didSelectItem (section - row) :  %ld - %ld", (long)indexPath.section, (long)indexPath.row);
}
- (BOOL)collectionView:(UICollectionView *)collectionView shouldDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}
- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"   didDeselectItem (section - row) :  %ld - %ld", (long)indexPath.section, (long)indexPath.row);
}
*/


#pragma mark - UIScrollView Delegate -
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.currentPosition inSection:0];
    self.previousImageBrowserCell = (QAImageBrowserCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (scrollView.contentOffset.x <= -80) {
        [self quitImageBrowser_directly];
    }
    else if (QAImageBrowserScreenWidth - (scrollView.contentSize.width - scrollView.contentOffset.x) >= 80) {
        [self quitImageBrowser_directly];
    }
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat pageWidth = self.collectionView.bounds.size.width;
    CGPoint offset = scrollView.contentOffset;
    
    NSUInteger currentPage = self.currentPosition;
    self.collectionOffsetX_tmp = self.currentPosition * pageWidth;
    if (offset.x - self.collectionOffsetX_tmp > 3) {
        if (fabs(offset.x - self.collectionOffsetX_tmp) - pageWidth >= 0) {
            currentPage = currentPage + 1;
        }
    }
    else if (offset.x - self.collectionOffsetX_tmp < -3) {
        if (fabs(offset.x - self.collectionOffsetX_tmp) - pageWidth >= 0) {
            currentPage = currentPage - 1;
        }
    }
    
    if (currentPage < 0 || currentPage >= self.images.count) {
        return;
    }
    else if (self.currentPosition == currentPage) {
        return;
    }
    
    self.currentPosition = currentPage;
    
    if (fabs(offset.x - self.collectionOffsetX_began) - pageWidth >= 0.) {
        // 将初次点击的imageView进行复位 (CollectionView.cell -> SRCTableView.cell)
        /** [self makeTapedImageViewBacktoOriginalStateWhenScroll]; */
        SEL makeTapedImageViewBacktoOriginalStateWhenScrollSelector = NSSelectorFromString(@"makeTapedImageViewBacktoOriginalStateWhenScroll");
        IMP makeTapedImageViewBacktoOriginalStateWhenScrollImp = [self methodForSelector:makeTapedImageViewBacktoOriginalStateWhenScrollSelector];
        void (*makeTapedImageViewBacktoOriginalStateWhenScroll)(id, SEL) = (void *)makeTapedImageViewBacktoOriginalStateWhenScrollImp;
        makeTapedImageViewBacktoOriginalStateWhenScroll(self, makeTapedImageViewBacktoOriginalStateWhenScrollSelector);
    }
    
    // 恢复初始状态 (处理放大或缩小图片的情况):
    [self.previousImageBrowserCell.scrollView setZoomScale:1];
}


#pragma mark - Property -
- (QAImageBrowserLayout *)layout {
    if (!_layout) {
        NSInteger itemCount = 1;
        CGFloat gap_left = 0;
        CGFloat gap_right = 0;
        NSInteger gap_lineSpace = 0;
        
        _layout = [[QAImageBrowserLayout alloc] init];
        _layout.itemWidth = QAImageBrowserScreenWidth;
        _layout.itemHeight = QAImageBrowserScreenHeight;
        _layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        _layout.itemCountsPerLine = itemCount;
        _layout.leftSpace = gap_left;
        _layout.rightSpace = gap_right;
        _layout.lineSpace = gap_lineSpace;
        _layout.topSpace = 0;
        _layout.bottomSpace = 0;
    }
    
    return _layout;
}
- (UICollectionView *)collectionView {
    if (!_collectionView) {
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, QAImageBrowserScreenWidth+PagesGap, QAImageBrowserScreenHeight) collectionViewLayout:self.layout];
        
        if (@available(iOS 11.0, *)) {
            if ([_collectionView respondsToSelector:@selector(setContentInsetAdjustmentBehavior:)]) {
                _collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
            }
        } else {
            // Fallback on earlier versions
        }
        
        _collectionView.backgroundColor = [UIColor clearColor];
        _collectionView.pagingEnabled = YES;
        _collectionView.showsVerticalScrollIndicator = NO;
        _collectionView.showsHorizontalScrollIndicator = NO;
        _collectionView.alwaysBounceVertical = NO;
        _collectionView.alwaysBounceHorizontal = YES;
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        
        // 注册cell:
        [_collectionView registerClass:[QAImageBrowserCell class] forCellWithReuseIdentifier:QAImageBrowser_cellID];
        
        /*
         // 注册header:
         [_collectionView registerClass:[HeaderReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:QAImageBrowser_headerIdentifier];

         // 注册footer:
         [_collectionView registerClass:[FooterReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:QAImageBrowser_footerIdentifier];
         */
    }
    
    return _collectionView;
}



/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end

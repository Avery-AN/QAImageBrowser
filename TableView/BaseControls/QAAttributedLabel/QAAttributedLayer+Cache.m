//
//  QAAttributedLayer+Cache.m
//  TableView
//
//  Created by Avery An on 2019/12/22.
//  Copyright © 2019 Avery. All rights reserved.
//

#import "QAAttributedLayer+Cache.h"
#import "QAAttributedLabelConfig.h"
#import "QAAttributedLabel.h"
#import "QAFastImageDiskCache.h"
#import "QAFastImageDiskCacheConfig.h"

static int CountLimit = 15;
static NSCache *_imageCache = nil;
static __weak QAAttributedLabel *currentLabel = nil;
static __weak QAAttributedLayer *selfClass = nil;
static void QARunLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    
//    UITableView *tableView = (UITableView *)currentLabel.superview.superview.superview;
//    NSArray *visibleCells = tableView.visibleCells;
//    NSLog(@"visibleCells: %@",visibleCells);
//    for (UITableViewCell *cell in visibleCells) {
//        for (QAAttributedLabel *label in cell.contentView.subviews) {
//            if ([label isKindOfClass:[QAAttributedLabel class]] && label.srcAttributedString) {
//                QAAttributedLayer *layer = (QAAttributedLayer *)label.layer;
//                [layer drawTextBackgroundWithAttributedString:label.attributedString];
//            }
//        }
//    }
    
    
    /*
     NSRunLoopMode currentMode = [NSRunLoop currentRunLoop].currentMode;
     if (currentMode == UITrackingRunLoopMode) {   // 正在滑动...
         UITableView *tableView = (UITableView *)label.superview.superview.superview;
         NSLog(@"tableView.contentOffset.y: %f",tableView.contentOffset.y);
     }
     else {  // 没有滑动
         
     }
    */
}
static void QAAttributedLayerCacheSetup() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _imageCache = [[NSCache alloc] init];
        [_imageCache setCountLimit:CountLimit];  // 设置最多缓存个数
        
        CFRunLoopRef cfRunloopRef = CFRunLoopGetMain();   // 获取当前线程的cfRunloopRef
        CFRunLoopObserverRef observer = CFRunLoopObserverCreate(CFAllocatorGetDefault(),
                                           kCFRunLoopExit,
                                           true,        // is repeat
                                           (2000000-1), // 设定观察者的优先级  CATransaction(2000000)
                                           QARunLoopObserverCallBack,
                                           NULL);
        CFRunLoopAddObserver(cfRunloopRef, observer, kCFRunLoopCommonModes);
        CFRelease(observer);
    });
}

@interface QAAttributedLayer ()
//@property
@end

@implementation QAAttributedLayer (Cache)

- (void)cacheImage:(UIImage * _Nonnull)image
    withIdentifier:(NSMutableAttributedString * _Nonnull)identifier {
    if (!image || !identifier) {
        return;
    }
    
    if (!_imageCache) {
        QAAttributedLayerCacheSetup();
    }
    selfClass = self;
    currentLabel = (QAAttributedLabel *)selfClass.delegate;
    
    NSString *key = identifier.string;
    
    /*
     [_imageCache setObject:image forKey:key];  // 缓存到内存
     */
    
    // 缓存到磁盘:
    [[QAFastImageDiskCache sharedImageCache] cacheImage:image
                                             identifier:key
                                            formatStyle:QAImageFormatStyle_32BitBGRA];
}

- (void)getCacheWithIdentifier:(NSMutableAttributedString * _Nonnull)identifier
                      finished:(void (^)(NSMutableAttributedString * _Nonnull identifier, UIImage * _Nullable image))finishedBlock {
    if (!_imageCache) {
        QAAttributedLayerCacheSetup();
    }
    selfClass = self;
    currentLabel = (QAAttributedLabel *)selfClass.delegate;

    NSString *key = identifier.string;
    
    /** 内存
     UIImage *image = [_imageCache objectForKey:key];
     if (image && finishedBlock) {
         finishedBlock(identifier, image);
     }
     else if (finishedBlock) {
         finishedBlock(identifier, nil);
     }
     */

    // 磁盘:
    [[QAFastImageDiskCache sharedImageCache] requestDiskCachedImage:key
                                                         completion:^(UIImage * _Nullable image) {

        NSLog(@"[NSThread currentThread] (2): %@",[NSThread currentThread]);

        if (image && finishedBlock) {
            NSLog(@"   +++++++++++ 0  image: %@",image);
            finishedBlock(identifier, image);
        }
        else if (finishedBlock) {
            NSLog(@"   +++++++++++ 1  image: %@",image);
            finishedBlock(identifier, nil);
        }
    } failed:^(NSString * _Nonnull identifierString, NSError * _Nullable error) {

        NSLog(@"[NSThread currentThread] (3): %@",[NSThread currentThread]);

        if (finishedBlock) {
            NSLog(@"   +++++++++++ 2  image");
            finishedBlock(identifier, nil);
        }
    }];
}

@end

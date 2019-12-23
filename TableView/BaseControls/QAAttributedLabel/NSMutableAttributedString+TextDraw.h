//
//  NSMutableAttributedString+TextDraw.h
//  TableView
//
//  Created by Avery An on 2019/12/23.
//  Copyright © 2019 Avery. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSMutableAttributedString (TextDraw)

/**
 存储高亮文本(换行) (key:range - value:数组、存储换行的highlightText信息、数组中元素的个数代表highlightText在绘制过程中所占用的行数)
 */
@property (nonatomic, strong) NSMutableDictionary *textNewlineDic;

/**
 保存高亮文案所处位置对应的frame (key:range - value:CGRect)
 */
@property (nonatomic, strong) NSMutableDictionary *highlightFrameDic;

/**
 根据size的大小在context里绘制文本attributedString
 */
- (void)drawAttributedTextWithContext:(CGContextRef)context
                          contentSize:(CGSize)size;

/**
 根据size的大小在context里绘制文本attributedString
 
 @param wordSpace 字间距、处理自定义的Emoji时使用
 @param maxNumberOfLines 展示文案时最多展示的行数 (用户设定的numberoflines)
 @param saveHighlightText 是否需要保存attributedString中highllight文案的相关信息、值为YES时表示需要保存 (目前只是保存了需要交互的高亮文本)
 */
- (int)drawAttributedTextWithContext:(CGContextRef)context
                         contentSize:(CGSize)size
                           wordSpace:(CGFloat)wordSpace
                    maxNumberOfLines:(NSInteger)maxNumberOfLines
                       textAlignment:(NSTextAlignment)textAlignment
                      truncationText:(NSDictionary *)truncationTextInfo
                   saveHighlightText:(BOOL)saveHighlightText;

@end

NS_ASSUME_NONNULL_END
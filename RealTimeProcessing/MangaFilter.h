#import <Foundation/Foundation.h>

/**
 画像を漫画風に加工する
 */
@interface MangaFilter : NSObject

/**
 フィルター処理
 
 @param     image      フィルター前の画像
 @return    フィルター後の画像
 */
+ (UIImage *)doFilter:(UIImage *)image;

@end
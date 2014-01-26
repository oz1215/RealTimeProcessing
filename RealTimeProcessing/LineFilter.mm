#import "LineFilter.h"
#import "OpenCVUtil.h"

@implementation LineFilter

+ (UIImage *)doFilter:(UIImage *)image
{
    UIImage *lineImage = [LineFilter lineFilter:image];
    
    CGRect imageRect = CGRectMake(0.0f, 0.0f, lineImage.size.width, lineImage.size.height);
    
    // オフスクリーン描画のためのグラフィックスコンテキストを用意
    UIGraphicsBeginImageContext(lineImage.size);
    
    // 輪郭画像をコンテキストに描画
    [lineImage drawInRect:imageRect];
    
    // 4-4.合成画像をコンテキストから取得
    UIImage *margedImage = UIGraphicsGetImageFromCurrentImageContext();
    
    // 4-5.オフスクリーン描画を終了
    UIGraphicsEndImageContext();
    
    return margedImage;
}

+ (UIImage *)lineFilter:(UIImage *)image
{
    // CGImageからIplImageを作成
    IplImage *srcImage       = [OpenCVUtil IplImageFromUIImage:image];
    
    IplImage *grayscaleImage = cvCreateImage(cvGetSize(srcImage), IPL_DEPTH_8U, 1);
    IplImage *edgeImage      = cvCreateImage(cvGetSize(srcImage), IPL_DEPTH_8U, 1);
    IplImage *dstImage       = cvCreateImage(cvGetSize(srcImage), IPL_DEPTH_8U, 3);
    
    // グレースケール画像に変換
    cvCvtColor(srcImage, grayscaleImage, CV_BGR2GRAY);
    
    // グレースケール画像を平滑化
    cvSmooth(grayscaleImage, grayscaleImage, CV_GAUSSIAN, 3, 0, 0);
    
    // エッジ検出画像を作成
    cvCanny(grayscaleImage, edgeImage, 20, 120);
    
    // エッジ検出画像色を反転
    cvNot(edgeImage, edgeImage);
    
    // CGImage用にBGRに変換
    cvCvtColor(edgeImage, dstImage, CV_GRAY2BGR);
    
    // IplImageからCGImageを作成
    UIImage *effectedImage = [OpenCVUtil UIImageFromIplImage:dstImage];
    
    cvReleaseImage(&srcImage);
    cvReleaseImage(&grayscaleImage);
    cvReleaseImage(&edgeImage);
    cvReleaseImage(&dstImage);
    
    // 白色の部分を透過する
    const float colorMasking[6] = {255, 255, 255, 255, 255, 255};
    CGImageRef imageRef = CGImageCreateWithMaskingColors(effectedImage.CGImage, colorMasking);
    UIImage *lineImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    return lineImage;
}

@end
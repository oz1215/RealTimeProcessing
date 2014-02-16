#import "LineFilter.h"
#import "OpenCVUtil.h"
#import <AudioToolbox/AudioServices.h>
#import "AppDelegate.h"

@implementation LineFilter

double _previous_area = 0;

+ (UIImage *)doFilter:(UIImage *)image
{
    //UIImage *lineImage = [LineFilter lineFilter:image];
    UIImage *lineImage = redFilter(image);
    
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

UIImage* redFilter(UIImage* image)
{
    int LOW_HUE = 170;           //hueの下限
    int UP_HUE = 10;            //hueの上限
    int LOW_SATURATION = 80;    //saturation（彩度）の下限
    int LOW_VALUE = 200;         //value（明度）の下限
    
    IplImage *srcImage = [OpenCVUtil IplImageFromUIImage:image];
    cv::Mat hsv, frame, blur, hue, hue1, hue2, saturation, value, hue_saturation, image_black_white;
    frame = cv::cvarrToMat(srcImage);
    medianBlur(frame, blur, 9);
    cv::cvtColor(blur, hsv, CV_BGR2HSV);
    std::vector<cv::Mat> singlechannels;
    cv::split(hsv, singlechannels);
    cv::threshold(singlechannels[0], hue1, LOW_HUE, 255, CV_THRESH_BINARY);
    cv::threshold(singlechannels[0], hue2, UP_HUE, 255, CV_THRESH_BINARY_INV);
    cv::threshold(singlechannels[1], saturation, LOW_SATURATION, 255, CV_THRESH_BINARY);
    cv::threshold(singlechannels[2], value, LOW_VALUE, 255, CV_THRESH_BINARY);
    cv::bitwise_or(hue1, hue2, hue);
    cv::bitwise_and(hue, saturation, hue_saturation);
    cv::bitwise_and(hue_saturation, value, image_black_white);
    double areas = 0;
    std::vector<std::vector<cv::Point> > contours;
    findContours(image_black_white, contours, CV_RETR_EXTERNAL, CV_CHAIN_APPROX_SIMPLE);
    for ( int i = 0; i< contours.size(); i++ ) {
        cv::Rect rect = cv::boundingRect(contours[i]);
        //cv::drawContours(frame, contours, i, cv::Scalar(255,255,0), 2, 8);
        cv::rectangle(frame, rect, cv::Scalar(255,255,0));
        areas += cv::contourArea(contours[i]);
    }
    AppDelegate* appDelegate = [[UIApplication sharedApplication] delegate];
    if(areas*2 < _previous_area && appDelegate.isStationary){
        AudioServicesPlaySystemSound(1010);
    }
    _previous_area = areas;
    IplImage dstImg = frame;
    UIImage *resultImage = [OpenCVUtil UIImageFromIplImage:&dstImg];
    cvReleaseImage(&srcImage);
    return resultImage;
}
@end

#import "LineFilter.h"
#import "OpenCVUtil.h"
#import <AudioToolbox/AudioServices.h>
#import "AppDelegate.h"

@implementation LineFilter

double _previous_area = 0;

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
    
//    IplImage *grayscaleImage = cvCreateImage(cvGetSize(srcImage), IPL_DEPTH_8U, 1);
//    IplImage *edgeImage      = cvCreateImage(cvGetSize(srcImage), IPL_DEPTH_8U, 1);
//    IplImage *dstImage       = cvCreateImage(cvGetSize(srcImage), IPL_DEPTH_8U, 3);
//    
//    // グレースケール画像に変換
//    cvCvtColor(srcImage, grayscaleImage, CV_BGR2GRAY);
//    
//    // グレースケール画像を平滑化
//    cvSmooth(grayscaleImage, grayscaleImage, CV_GAUSSIAN, 3, 0, 0);
//    
//    // エッジ検出画像を作成
//    cvCanny(grayscaleImage, edgeImage, 20, 120);
//    
//    // エッジ検出画像色を反転
//    cvNot(edgeImage, edgeImage);
//    
//    // CGImage用にBGRに変換
//    cvCvtColor(edgeImage, dstImage, CV_GRAY2BGR);
    
    cv::Mat dstMat = cv::cvarrToMat(srcImage);
    std::vector<std::vector<cv::Point> > squares;
    [LineFilter findSquares:dstMat andOut:squares];
    dstMat = debugSquares(squares, dstMat);
    IplImage dstImg = dstMat;
    
    // IplImageからCGImageを作成
    UIImage *effectedImage = [OpenCVUtil UIImageFromIplImage:&dstImg];
    
    cvReleaseImage(&srcImage);
//    cvReleaseImage(&grayscaleImage);
//    cvReleaseImage(&edgeImage);
//    cvReleaseImage(&dstImage);
    
    // 白色の部分を透過する
    const float colorMasking[6] = {255, 255, 255, 255, 255, 255};
    CGImageRef imageRef = CGImageCreateWithMaskingColors(effectedImage.CGImage, colorMasking);
    UIImage *lineImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    return lineImage;
}

+ (double)angle:(cv::Point)pt1 and2:(cv::Point)pt2 and0:(cv::Point)pt0
{
    double dx1 = pt1.x - pt0.x;
    double dy1 = pt1.y - pt0.y;
    double dx2 = pt2.x - pt0.x;
    double dy2 = pt2.y - pt0.y;
    return (dx1*dx2 + dy1*dy2)/sqrt((dx1*dx1 + dy1*dy1)*(dx2*dx2 + dy2*dy2) + 1e-10);
}

+ (void)findSquares:(cv::Mat&)image andOut:(std::vector<std::vector<cv::Point> >&)squares
{
    // blur will enhance edge detection
    cv::Mat blurred(image);
    //medianBlur(image, blurred, 9);
    
    cv::Mat gray0(blurred.size(), CV_8U), gray;
    std::vector<std::vector<cv::Point> > contours;
    
    // find squares in every color plane of the image
    for (int c = 0; c < 3; c++)
    {
        int ch[] = {c, 0};
        mixChannels(&blurred, 1, &gray0, 1, ch, 1);
        
        // try several threshold levels
        const int threshold_level = 2;
        for (int l = 0; l < threshold_level; l++)
        {
            // Use Canny instead of zero threshold level!
            // Canny helps to catch squares with gradient shading
            if (l == 0)
            {
                Canny(gray0, gray, 10, 20, 3); //
                
                // Dilate helps to remove potential holes between edge segments
                dilate(gray, gray, cv::Mat(), cv::Point(-1,-1));
            }
            else
            {
                gray = gray0 >= (l+1) * 255 / threshold_level;
            }
            
            // Find contours and store them in a list
            findContours(gray, contours, CV_RETR_LIST, CV_CHAIN_APPROX_SIMPLE);
            
            std::vector<double> areas;
            // Test contours
            std::vector<cv::Point> approx;
            for (size_t i = 0; i < contours.size(); ++i)
            {
                // approximate contour with accuracy proportional
                // to the contour perimeter
                approxPolyDP(cv::Mat(contours[i]), approx, arcLength(cv::Mat(contours[i]), true)*0.02, true);
                
                // Note: absolute value of an area is used because
                // area may be positive or negative - in accordance with the
                // contour orientation
                double area = fabs(contourArea(cv::Mat(approx)));
                if (approx.size() == 4 &&
                    100 < area && area < 1000 &&
                    isContourConvex(cv::Mat(approx)))
                {
                    double maxCosine = 0;
                    
                    for (int j = 2; j < 5; j++)
                    {
                        double cosine = fabs([LineFilter angle:approx[j%4] and2:approx[j-2] and0:approx[j-1]]);
                        maxCosine = MAX(maxCosine, cosine);
                    }
                    
                    if (maxCosine < 0.3){
                        cv::Rect rect = boundingRect(approx);
                        double ratio = rect.width/rect.height;
                        if(1.50 < ratio && ratio < 2.50) {
                            squares.push_back(approx);
                            areas.push_back(area);
                        }
                    }
                }
            }
            if(areas.size() != 0) {
                AppDelegate* appDelegate = [[UIApplication sharedApplication] delegate];
                double current_area = *max_element(areas.begin(), areas.end());
//                if(appDelegate.isStationary && current_area < _previous_area){
//                    AudioServicesPlaySystemSound(1010);
//                }
                if(current_area < _previous_area){
                    AudioServicesPlaySystemSound(1010);
                }
                _previous_area = current_area;
                int i = 3;
                i;
            }
        }
    }
}

cv::Mat debugSquares( std::vector<std::vector<cv::Point> > squares, cv::Mat image )
{
    for ( int i = 0; i< squares.size(); i++ ) {
        // draw contour
        cv::drawContours(image, squares, i, cv::Scalar(255,0,0), 1, 8, std::vector<cv::Vec4i>(), 0, cv::Point());
        
        // draw bounding rect
        cv::Rect rect = boundingRect(cv::Mat(squares[i]));
        cv::rectangle(image, rect.tl(), rect.br(), cv::Scalar(0,255,0), 2, 8, 0);
        
        // draw rotated rect
        cv::RotatedRect minRect = minAreaRect(cv::Mat(squares[i]));
        cv::Point2f rect_points[4];
        minRect.points( rect_points );
        for ( int j = 0; j < 4; j++ ) {
            cv::line( image, rect_points[j], rect_points[(j+1)%4], cv::Scalar(0,0,255), 1, 8 ); // blue
        }
    }
    
    return image;
}
@end
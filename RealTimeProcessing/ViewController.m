#import "ViewController.h"
#import "AVFoundationUtil.h"
#import "LineFilter.h"
#import "Toast+UIView.h"
#import "AppDelegate.h"

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (strong, nonatomic) AVCaptureVideoDataOutput *videoDataOutput;
@property (strong, nonatomic) AVCaptureSession *session;
@property (assign, nonatomic) BOOL isUsingFrontFacingCamera;
@property (nonatomic) dispatch_queue_t videoDataOutputQueue;
@property (strong, nonatomic) CALayer *previewLayer;
@property AppDelegate* appDelegate;

@end

@implementation ViewController

#pragma mark - UIViewController lifecycle methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // 端末のスリープ設定をOFFにします。起動中にスリープモードになりません。
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    [self startUpdatingActivity];
    _appDelegate = [[UIApplication sharedApplication] delegate];
    _appDelegate.isStationary = NO;
    
    // プレビュー表示用レイヤー
    self.previewLayer = [CALayer layer];
    self.previewLayer.frame = self.view.bounds;
    self.previewLayer.contentsGravity = kCAGravityResizeAspectFill;
    [self.view.layer addSublayer:self.previewLayer];

    // 撮影ボタンを配置したツールバーを生成
    UIToolbar *toolbar = [[UIToolbar alloc]
                          initWithFrame:CGRectMake(0.0f,
                                                   self.view.bounds.size.height - 44.0f,
                                                   self.view.bounds.size.width,
                                                   44.0f)];
    
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                      target:nil
                                      action:nil];
    
    UIBarButtonItem *takePhotoButton = [[UIBarButtonItem alloc]
                                        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                        target:self
                                        action:@selector(changeCamera:)];
    
    toolbar.items = @[flexibleSpace, takePhotoButton, flexibleSpace];
    [self.view addSubview:toolbar];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // 撮影開始
    [self setupAVCapture:AVCaptureDevicePositionBack];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [_activityManager stopActivityUpdates];
    
    // 端末のスリープ設定をONにします。起動中にスリープモードになります。
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    
    // 撮影終了
    [self teardownAVCapture];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Action methods

- (void)startUpdatingActivity
{
    if (![CMMotionActivityManager isActivityAvailable])
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                        message:@"CMMotionActivityManager is unavailable."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    // ブロックによる循環参照の回避
    __weak typeof(self) weakSelf = self;
    
    _activityManager = [[CMMotionActivityManager alloc] init];
    [_activityManager startActivityUpdatesToQueue:[NSOperationQueue mainQueue]
                                      withHandler:^(CMMotionActivity *activity) {
                                          _appDelegate.isStationary = activity.stationary;
                                          NSString *msg;
                                          if(activity.walking){
                                              msg = @"歩行中";
                                          } else if (activity.stationary && activity.automotive) {
                                              msg = @"停車中";
                                          } else if (!activity.stationary && activity.automotive) {
                                              msg = @"運転中";
                                          } else if (activity.stationary) {
                                              msg = @"静止中";
                                          } else if (activity.unknown) {
                                              msg = @"不明";
                                          }
                                          if(msg != nil){
                                              [self.view makeToast:msg];
                                          }
                                      }];
}

- (void)takePhoto:(id)sender
{
    // シャッター音を鳴らす
    AudioServicesPlaySystemSound(1108);

    dispatch_async(dispatch_get_main_queue(), ^{
        // プレビュー表示中のレイヤーを画像にして保存する
        UIGraphicsBeginImageContext(self.previewLayer.bounds.size);
        [self.previewLayer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        // アルバムに画像を保存
        UIImageWriteToSavedPhotosAlbum(image, self, nil, nil);
    });

}

- (void)changeCamera:(id)sender
{
    // シャッター音を鳴らす
    AudioServicesPlaySystemSound(1108);
    // 撮影終了
    [self teardownAVCapture];
    
    // 撮影開始
    if (self.isUsingFrontFacingCamera) {
        self.isUsingFrontFacingCamera = !self.isUsingFrontFacingCamera;
        [self setupAVCapture:AVCaptureDevicePositionBack];
    } else {
        self.isUsingFrontFacingCamera = !self.isUsingFrontFacingCamera;
        [self setupAVCapture:AVCaptureDevicePositionFront];
    }
}

#pragma mark - Private methods

- (void)setupAVCapture:(AVCaptureDevicePosition)avCaptureDevicePosition
{
    // 入力と出力からキャプチャーセッションを作成
    self.session = [[AVCaptureSession alloc] init];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        self.session.sessionPreset = AVCaptureSessionPreset640x480;
	} else {
        self.session.sessionPreset = AVCaptureSessionPresetPhoto;
	}
    
    // カメラからの入力を作成
    AVCaptureDevice *device;
    
    // カメラを検索
	for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
		if ([d position] == avCaptureDevicePosition) {
			device = d;
            self.isUsingFrontFacingCamera = avCaptureDevicePosition == AVCaptureDevicePositionFront;
			break;
		}
	}
    
    // カメラからの入力を作成
    NSError *error = nil;
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    
    if (error) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:
                                  [NSString stringWithFormat:@"Failed with error %d", (int)[error code]]
                                                            message:[error localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:@"Dismiss"
                                                  otherButtonTitles:nil];
		[alertView show];
		[self teardownAVCapture];
        return;
    }
    
    // キャプチャーセッションに追加
    if ([self.session canAddInput:deviceInput]) {
        [self.session addInput:deviceInput];
    }
    
    // 画像への出力を作成
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    self.videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
    
    // ビデオへの出力の画像は、BGRAで出力
    self.videoDataOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
    
    // ビデオ出力のキャプチャの画像情報のキューを設定
    self.videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [self.videoDataOutput setSampleBufferDelegate:self queue:self.videoDataOutputQueue];
    
    // キャプチャーセッションに追加
    if ([self.session canAddOutput:self.videoDataOutput]) {
        [self.session addOutput:self.videoDataOutput];
    }
    
    // ビデオ入力のAVCaptureConnectionを取得
    AVCaptureConnection *videoConnection = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    videoConnection.videoOrientation = [AVFoundationUtil videoOrientationFromDeviceOrientation:[UIDevice currentDevice].orientation];
    
    // 1秒あたり24回画像をキャプチャ
    videoConnection.videoMinFrameDuration = CMTimeMake(1, 1);
    
    // 開始
    [self.session startRunning];
}

// キャプチャー情報をクリーンアップ
- (void)teardownAVCapture
{
	self.videoDataOutput = nil;
	if (self.videoDataOutputQueue) {
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
		dispatch_release(self.videoDataOutputQueue);
#endif
    }
}

// 画像の加工処理
- (void)process:(UIImage *)image
{
    // 画像を白黒に加工
    //UIImage *processedImage = [MonochromeFilter doFilter:image];
    UIImage *processedImage = [LineFilter doFilter:image];
    
    // 加工した画像をプレビューレイヤーに追加
    self.previewLayer.contents = (__bridge id)(processedImage.CGImage);

    // フロントカメラの場合は左右反転
    if (self.isUsingFrontFacingCamera) {
        self.previewLayer.affineTransform = CGAffineTransformMakeScale(-1.0f, 1.0f);
    }else{
        self.previewLayer.affineTransform = CGAffineTransformMakeScale(1.0f, 1.0f);
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate methods

// AVCaptureVideoDataOutputSampleBufferDelegateプロトコルのメソッド。
// 新しいキャプチャの情報が追加されたときに呼び出される。
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    // キャプチャしたフレームからCGImageを作成
    UIImage *image = [AVFoundationUtil imageFromSampleBuffer:sampleBuffer];
    
    // 画像を画面に表示
    dispatch_async(dispatch_get_main_queue(), ^{
        [self process:image];
    });
}

@end
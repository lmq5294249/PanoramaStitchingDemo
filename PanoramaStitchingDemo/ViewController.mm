//
//  ViewController.m
//  PanoramaStitchingDemo
//
//  Created by lin on 2020/12/3.
//

#import "ViewController.h"
#import <opencv2/stitching.hpp>
#import <opencv2/imgcodecs/ios.h>
#include <vector>

using namespace std;
using namespace cv;

bool try_use_gpu = false;
int thresh = 100;
int max_thresh = 255;
RNG rng(12345);

typedef NS_ENUM(NSUInteger, StitchImagesType) {
    StitchImagesTypePanoramaNormal,
    StitchImagesTypeFisheye,
};

@interface ViewController ()

@property (nonatomic,strong) UIImageView *showView;
@property (nonatomic,strong) UIImageView *resultView;

@property (nonatomic,strong) NSMutableArray *imageArray;

@property (nonatomic,assign) BOOL isUnderStitchingNow;

@end

@implementation ViewController

@synthesize imageArray;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _showView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 150, self.view.frame.size.width, 200)];
    [self.view addSubview:_showView];
    _showView.backgroundColor = [UIColor orangeColor];
    
    _resultView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 400, self.view.frame.size.width, 200)];
    [self.view addSubview:_resultView];
    _resultView.backgroundColor = [UIColor purpleColor];
    
    
    imageArray = [[NSMutableArray alloc] init];
    for (int i = 1; i < 5; i++) {
        UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"VCAM_0046_S04_0%d.JPG",i]];
        [imageArray addObject:image];
    }
    
    
    // Do any additional setup after loading the view.
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    //展示需要拼接的四幅图
    UIImageView *imageView_1 = [[UIImageView alloc] initWithFrame:CGRectMake(50, 5, 90, 60)];
    [imageView_1 setImage:imageArray[0]];
    UIImageView *imageView_2 = [[UIImageView alloc] initWithFrame:CGRectMake(170, 5, 90, 60)];
    [imageView_2 setImage:imageArray[1]];
    UIImageView *imageView_3 = [[UIImageView alloc] initWithFrame:CGRectMake(50, 70, 90, 60)];
    [imageView_3 setImage:imageArray[2]];
    UIImageView *imageView_4 = [[UIImageView alloc] initWithFrame:CGRectMake(170, 70, 90, 60)];
    [imageView_4 setImage:imageArray[3]];
    [self.view addSubview:imageView_1];
    [self.view addSubview:imageView_2];
    [self.view addSubview:imageView_3];
    [self.view addSubview:imageView_4];
    
    UIButton *stitchBtn = [[UIButton alloc] initWithFrame:CGRectMake(280, 15, 90, 40)];
    [stitchBtn setTitle:@"全景拼接" forState:UIControlStateNormal];
    [stitchBtn setTitle:@"拼接中..." forState:UIControlStateSelected];
    stitchBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    stitchBtn.titleLabel.textColor = [UIColor whiteColor];
    [stitchBtn setBackgroundColor:[UIColor blackColor]];
    stitchBtn.layer.cornerRadius = 5;
    stitchBtn.layer.masksToBounds = YES;
    [stitchBtn addTarget:self action:@selector(panoramaStitchType:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:stitchBtn];
    
    UIButton *fisheyeBtn = [[UIButton alloc] initWithFrame:CGRectMake(280, 75, 90, 40)];
    [fisheyeBtn setTitle:@"鱼眼拼接" forState:UIControlStateNormal];
    [fisheyeBtn setTitle:@"拼接中..." forState:UIControlStateSelected];
    fisheyeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    fisheyeBtn.titleLabel.textColor = [UIColor whiteColor];
    [fisheyeBtn setBackgroundColor:[UIColor blueColor]];
    fisheyeBtn.layer.cornerRadius = 5;
    fisheyeBtn.layer.masksToBounds = YES;
    [fisheyeBtn addTarget:self action:@selector(fisheyeStitchType:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:fisheyeBtn];
}

-(void)viewDidAppear:(BOOL)animated
{
    
    [super viewWillAppear:animated];
//    __weak typeof(self) weakSelf = self;
//    dispatch_async(dispatch_get_global_queue(0, 0), ^{
//        [weakSelf stitchImage:weakSelf.imageArray];
//    });
    
}

-(void)panoramaStitchType:(id)sender
{
    UIButton *btn = sender;
    btn.selected = !btn.selected;
    if (btn.selected) {
        if (_isUnderStitchingNow == YES) {
            return;
        }
        
        [_showView setImage:nil];
        [_resultView setImage:nil];
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            weakSelf.isUnderStitchingNow = YES;
            [weakSelf stitchImage:weakSelf.imageArray witchStitchType:StitchImagesTypePanoramaNormal];
            weakSelf.isUnderStitchingNow = NO;
        });
    }
    
}

-(void)fisheyeStitchType:(id)sender
{
    UIButton *btn = sender;
    btn.selected = !btn.selected;
    if (btn.selected) {
        if (_isUnderStitchingNow == YES) {
            return;
        }
        
        [_showView setImage:nil];
        [_resultView setImage:nil];
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            weakSelf.isUnderStitchingNow = YES;
            [weakSelf stitchImage:weakSelf.imageArray witchStitchType:StitchImagesTypeFisheye];
            weakSelf.isUnderStitchingNow = NO;
        });
    }
    
}

#pragma mark - 全景图片拼接
//MARK:占用内存过高问题!!!!最后测试时由于showView 和 resuketView显示图片导致，图片在内存中占用超过150M内存，释放view后正常。
-(void)stitchImage:(NSArray*)images witchStitchType:(StitchImagesType)type{
    
    //MARK:开始拼接时间
    NSDate* tmpStartData = [NSDate date];
    
    vector<cv::Mat> imgs;
    
    for (int i = 0; i < images.count; i++) {
        Mat image;
        UIImageToMat(images[i], image);
        cvtColor(image, image, CV_RGBA2RGB);
        imgs.push_back(image);
    }
    
    Mat pano;
    Stitcher::Status status;
    
    if (type == StitchImagesTypeFisheye) {
        /*
         //MARK:鱼眼效果测试
         拼接运行时间>>>>>>>>>>cost time = 26984.598041 ms
         剪切运行时间>>>>>>>>>>cost time = 16845.719099 ms
         测试结果是：超级耗时,基于原图片不完全的操作。
         */
        cv::Ptr<Stitcher> stitcher = Stitcher::create();//4.0
        cv::Ptr<FisheyeWarper> fisheye_warper = makePtr<cv::FisheyeWarper>();
        stitcher->setWarper(fisheye_warper);
        status = stitcher->stitch(imgs, pano);
    }
    else if (type == StitchImagesTypePanoramaNormal)
    {
        Stitcher stitcher = Stitcher::createDefault(false);
        status = stitcher.stitch(imgs, pano);//拼接
    }
    
    if (status != Stitcher::OK) {
        NSLog(@"拼接出错!!!!!!!!!!!!!!!!!!!!!");
    }
    
    //MARK:结束拼接时间
    double deltaTime = [[NSDate date] timeIntervalSinceDate:tmpStartData];
    NSLog(@"拼接运行时间>>>>>>>>>>cost time = %f ms", deltaTime*1000);
    //tmpStartData = [NSDate date];
    
    UIImage *targerImage = MatToUIImage(pano);
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.showView setImage:targerImage];
        UIImageWriteToSavedPhotosAlbum(targerImage, self, nil, nil);
    });
    
    //在全景图四周各添加10像素宽的黑色边框，以确保能够找到全景图的完整轮廓：
    Mat stitched;//黑色边框轮廓图
    copyMakeBorder(pano, stitched, 10, 10, 10, 10, cv::BORDER_CONSTANT, true);
    //全景图转换灰度图，并将不为0的像素全置为255
      //作为前景，其他像素灰度值为0，作为背景。
    Mat gray;
    cv::cvtColor(stitched, gray, cv::COLOR_BGR2GRAY);

    //中值滤波，去除黑色边际中可能含有的噪声干扰
      cv::medianBlur(gray, gray, 7);
    
    //白色剪影与黑色背景
      Mat tresh;
      threshold(gray, tresh, 0, 255, THRESH_BINARY);
    
    const int scale = 2;
    //resize 缩小一半处理
     resize(tresh, tresh,
             cv::Size(tresh.cols / scale, tresh.rows / scale),
             tresh.cols / 2,
             tresh.rows / 2, INTER_LINEAR);
    
    //现在有了全景图的二值图，再应用轮廓检测，找到最大轮廓的边界框，
    vector<vector<cv::Point>> contours; //contours:包含图像中所有轮廓的python列表（三维数组）,每个轮廓是包含边界所有坐标点(x, y)的Numpy数组。
    vector<Vec4i> hierarchy = vector<cv::Vec4i>();//vec4i是一种用于表示具有4个维度的向量的结构，每个值都小于cc>
      findContours(tresh.clone(), contours, hierarchy, RETR_TREE, CHAIN_APPROX_SIMPLE);//传入参数不一样
      //计算最大轮廓的边界框
      int index = getMaxContour(contours);
      if (index == -1) {
          
          NSLog(@"计算最大轮廓的边界框出错!!!!!!!!!!!!!");
          
      }
    vector<cv::Point> cnt = contours[index];
    drawContours(tresh, contours, index, Scalar(255,0,0));
    
    //蒙板
      Mat mask = Mat::zeros(tresh.rows, tresh.cols, CV_8UC1); // 0矩阵
      //依赖轮廓创建矩形
      cv::Rect cntRect = cv::boundingRect(cnt);
      rectangle(mask, cntRect, cv::Scalar(255, 0, 0), -1);

      Mat minRect = mask.clone();//minRect的白色区域会慢慢缩小，直到它刚好可以完全放入全景图内部。
      Mat sub = mask.clone();//sub用于确定minRect是否需要继续减小，以得到满足要求的矩形区域。
    
    //开始while循环，直到sub中不再有前景像素
      while (cv::countNonZero(sub) > 0) {
      //        int zero = cv::countNonZero(sub);
      //        printf("剩余前景像素 %d \n",zero);
          cv::erode(minRect, minRect, Mat());
          cv::subtract(minRect, tresh, sub);
      }
    
    //第二次循环
    cv::Mat minRectClone = minRect.clone();
    
    cv::resize(minRectClone, minRectClone,
                 cv::Size(minRectClone.cols * scale, minRectClone.rows * scale),
                 (float)minRect.cols / 2, (float)minRect.rows / 2,INTER_LINEAR);
    
    std::vector<std::vector<cv::Point> > cnts;
    vector<Vec4i> hierarchyA = vector<cv::Vec4i>();
    findContours(minRectClone, cnts, hierarchyA, RETR_TREE, CHAIN_APPROX_SIMPLE);
    int idx = getMaxContour(cnts);
    if (idx == -1) {
        NSLog(@"第二次循环获取失败!!!!!!!!!!!!!!!");
    }
    cv::Rect finalRect = cv::boundingRect(cnts[idx]);
    
    Mat outputMat;
    outputMat = Mat(stitched, finalRect).clone();
    
    //MARK:剪辑图片时间
    double deltaTime2 = [[NSDate date] timeIntervalSinceDate:tmpStartData];
    NSLog(@"剪切运行时间>>>>>>>>>>cost time = %f ms", deltaTime2 * 1000);
    
    //更新到界面
    UIImage *resultImage = MatToUIImage(outputMat);
    NSLog(@"resultImage 宽 = %f, 高 = %f",resultImage.size.width,resultImage.size.height);
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.resultView setImage:resultImage];
        UIImageWriteToSavedPhotosAlbum(resultImage, self, nil, nil);
    });
    
    //资源释放解决内存过度占用的问题:
    pano.release();
    stitched.release();
    gray.release();
    tresh.release();
    mask.release();
    minRect.release();
    sub.release();
    minRectClone.release();
    outputMat.release();

}

//循环最大的轮廓边框
int getMaxContour(std::vector<vector<cv::Point>> contours){
  double max_area = 0;
  int index = -1;
  for (int i = 0; i < contours.size(); i++) {
     double tempArea = contourArea(contours[i]);
     if (tempArea > max_area) {
         max_area = tempArea;
         index = i;
     }
  }
  return index;
}


@end

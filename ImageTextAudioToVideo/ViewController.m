//
//  ViewController.m
//  ImageTextAudioToVideo
//
//  Created by Md. Milan Mia on 11/19/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//
@import AVFoundation;
@import Foundation;
@import AssetsLibrary;

#import "ViewController.h"

#define maxAudio 10

@interface ViewController (){
    AVAsset *anAsset;
    NSMutableArray *imageArray;
    NSArray *subtitleArray;
    NSURL *assetUrl;
    CMTime frameTime;
    AVAssetWriter *assetWriter;
    AVAssetWriterInput *assetWriterInput;
    AVAssetWriterInputPixelBufferAdaptor *adaptor;
    NSDictionary *settings;
    NSString *subtitle;
    int imgcnt;
    __weak IBOutlet UIImageView *imageView;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    subtitleArray = @[@"Subtitle 1",@"Subtitle 2", @"Subtitle 3", @"Subtitle 4", @"Subtitle 5", @"Subtitle 6", @"Subtitle 7", @"Subtitle 8", @"Subtitle 9", @"Subtitle 10"];
}
- (UIImage*)image:(UIImage*)image withText:(NSString*)text atPoint:(CGPoint)point {
    CGSize size = CGSizeMake(640, 480);
    CGRect rect = CGRectMake(0, 0, size.width, size.height);
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 1.0);
    [image drawInRect:rect];
    
   // NSDictionary *attributes = @{NSFontAttributeName           : [UIFont boldSystemFontOfSize:26],
   //                              NSStrokeWidthAttributeName    : @(-3.0),
   //                              NSStrokeColorAttributeName    : [UIColor yellowColor]};
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont fontWithName:@"Helvetica-Bold" size:36.0f],
                                NSForegroundColorAttributeName : [UIColor redColor],
                                NSStrokeColorAttributeName : [UIColor whiteColor],
                                NSStrokeWidthAttributeName : [NSNumber numberWithFloat:-2.0]};
    
    [text drawAtPoint:CGPointMake(size.height/2, size.width/2) withAttributes:attributes];
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    newImage = [UIImage imageWithCGImage:newImage.CGImage scale:1.0 orientation:UIImageOrientationRight];
    UIGraphicsEndImageContext();
    return newImage;
}
-(void) initialization {
    //Settings for video
    settings = [self videoSettingsWithCodec:AVVideoCodecH264 withWidth:640 andHeight:480];
    NSError *error;
    
    //Get a temp path to save video
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    NSString *tempPath = [documentsDirectory stringByAppendingFormat:@"/temp_01.mov"];
    
    //If already exits a video with same name remove
    if ([[NSFileManager defaultManager] fileExistsAtPath:tempPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:tempPath error:&error];
        if (error) {
            NSLog(@"Error: %@", error.debugDescription);
        }
    }

    //Initialize asset url and assetwriter
    assetUrl = [NSURL fileURLWithPath:tempPath];
    assetWriter = [[AVAssetWriter alloc]initWithURL:assetUrl fileType:AVFileTypeQuickTimeMovie error:&error];
    if (error) {
        NSLog(@"Error: %@", error.debugDescription);
    }
    
    //Set permissions
    NSParameterAssert(assetWriter);
    assetWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                          outputSettings:settings];
    NSParameterAssert(assetWriterInput);
    NSParameterAssert([assetWriter canAddInput:assetWriterInput]);
    [assetWriter addInput:assetWriterInput];
    
    //Set buffer attributes
    NSDictionary *bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
    adaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:assetWriterInput sourcePixelBufferAttributes:bufferAttributes];
    //Set frameTime
    frameTime = CMTimeMake(10, 1);
}

-(void)createAndSaveVideo {
    [assetWriter startWriting];
    [assetWriter startSessionAtSourceTime:kCMTimeZero];
    dispatch_queue_t mediaInputQueue = dispatch_queue_create("media input Queue", NULL);
    
    NSInteger frameNumber = 11;
    __block NSInteger imageIndex = 1, cnt=1; __block CMTime presentTime = kCMTimeZero;
    [assetWriterInput requestMediaDataWhenReadyOnQueue:mediaInputQueue usingBlock:^{
        while (true) {
            if(imageIndex>=frameNumber){
                break;
            }
            if(assetWriterInput.isReadyForMoreMediaData){
                NSString *tempName = [NSString stringWithFormat:@"%li", (long)imageIndex];
                UIImage* image = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:tempName ofType:@"jpg"]];
                NSString *text = [subtitleArray objectAtIndex:imageIndex-1];
                NSLog(text);
                CGPoint point = CGPointMake(320, 240);
                UIImage *convImage;
                CVPixelBufferRef buffer;
                @autoreleasepool {
                    convImage = [self image:image withText:text atPoint:point];
                    buffer = [self newPixelBufferFromCGImage:[convImage CGImage]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        imageView.image = convImage;
                    });
                    convImage = nil;
                }
                if(buffer){
                    if(imageIndex == 1){
                        [adaptor appendPixelBuffer:buffer withPresentationTime:presentTime];
                    }
                    else{
                        CMTime lastTime = CMTimeAdd(presentTime, frameTime);
                        presentTime = lastTime;
                        [adaptor appendPixelBuffer:buffer withPresentationTime:presentTime];
                    }
                    CFRelease(buffer);
                    imageIndex++;
                    cnt++;
                }
            }
            
        }
        [assetWriterInput markAsFinished];
        [assetWriter finishWritingWithCompletionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self addMultipleAudioToVideo];
            });
        }];
    }];
    
}
- (CVPixelBufferRef)newPixelBufferFromCGImage:(CGImageRef)image {
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    
    CVPixelBufferRef pxbuffer = NULL;
    
    CGFloat frameWidth = [[settings objectForKey:AVVideoWidthKey] floatValue];
    CGFloat frameHeight = [[settings objectForKey:AVVideoHeightKey] floatValue];
    
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          frameWidth,
                                          frameHeight,
                                          kCVPixelFormatType_32ARGB,
                                          (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate(pxdata,
                                                 frameWidth,
                                                 frameHeight,
                                                 8,
                                                 4 * frameWidth,
                                                 rgbColorSpace,
                                                 (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    CGContextConcatCTM(context, CGAffineTransformIdentity);
    CGContextDrawImage(context, CGRectMake(0,
                                           0,
                                           CGImageGetWidth(image),
                                           CGImageGetHeight(image)),
                       image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

- (void)exportDidFinish:(AVAssetExportSession*)session {
    if (session.status == AVAssetExportSessionStatusCompleted) {
        NSURL *outputURL = session.outputURL;
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:outputURL]) {
            [library writeVideoAtPathToSavedPhotosAlbum:outputURL completionBlock:^(NSURL *assetURL, NSError *error){
                //NSLog(@"%@ Here To Save", outputURL);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error) {
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Saving Failed"
                                                                       delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        [alert show];
                    } else {
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Video Saved" message:@"Saved To Photo Album"
                                                                       delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        [alert show];
                    }
                });
            }];
        }
    }
    else if(session.status == AVAssetExportSessionStatusFailed){
        NSLog(@"Error: %@", session.error);
    }
}
-(void)addMultipleAudioToVideo {
    //NSString *bundleDirectory = [[NSBundle mainBundle] bundlePath];
    // audio input file...
    //UIImage* image = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:tempName ofType:@"png"]];
    //NSString *audio_inputFilePath = [bundleDirectory stringByAppendingPathComponent:@"Prapty.mp3"];
    NSString *audio_inputFilePath[maxAudio];
    NSURL    *audio_inputFileUrl[maxAudio];
    AVMutableCompositionTrack *compositionAudioTrack[maxAudio];
    AVURLAsset* audioAsset[maxAudio];
    AVAssetTrack *audioAssetTrack[maxAudio];
    
    // this is the video file that was just written above, full path to file is in --> videoOutputPath
    NSURL    *video_inputFileUrl = assetUrl;
    
    // create the final video output file as MOV file - may need to be MP4, but this works so far...
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *myPathDocs =  [documentsDirectory stringByAppendingPathComponent:
                             [NSString stringWithFormat:@"FinalVideo-%d.mov",arc4random() % 1000]];
    NSURL *outputFileUrl = [NSURL fileURLWithPath:myPathDocs];
    
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    //Video And Audio Composition track
    AVMutableCompositionTrack *a_compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    
    //Video and Audio Asset
    AVURLAsset* videoAsset = [[AVURLAsset alloc]initWithURL:video_inputFileUrl options:nil];

    // Get the first video track from each asset.
    AVAssetTrack *videoAssetTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
  
    //Get time duration
    CMTimeRange video_timeRange = CMTimeRangeMake(kCMTimeZero,CMTimeMake(100, 1));
    CMTimeRange audio_timeRange = CMTimeRangeMake(kCMTimeZero, frameTime);
    CMTime nextClipStartTime = kCMTimeZero;
    
    [a_compositionVideoTrack insertTimeRange:video_timeRange ofTrack:videoAssetTrack atTime:kCMTimeZero error:nil];
    
    //Loop to add 10 audio files to video
    for(int audioTrackIndex = 0; audioTrackIndex<maxAudio; audioTrackIndex++){
        NSString *tempName = [NSString stringWithFormat:@"audio%li", (long)audioTrackIndex+1];
        audio_inputFilePath[audioTrackIndex] = [[NSBundle mainBundle] pathForResource:tempName ofType:@"mp3"];
        audio_inputFileUrl[audioTrackIndex] = [NSURL fileURLWithPath:audio_inputFilePath[audioTrackIndex]];
        compositionAudioTrack[audioTrackIndex] = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        audioAsset[audioTrackIndex] = [[AVURLAsset alloc]initWithURL:audio_inputFileUrl[audioTrackIndex] options:nil];
        audioAssetTrack[audioTrackIndex] = [[audioAsset[audioTrackIndex] tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
        [compositionAudioTrack[audioTrackIndex] insertTimeRange:audio_timeRange ofTrack:audioAssetTrack[audioTrackIndex] atTime:nextClipStartTime error:nil];
        nextClipStartTime = CMTimeAdd(nextClipStartTime, frameTime);
    }
    
    //Export Session
    AVAssetExportSession* _assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
    
    //Export
    _assetExport.outputURL=outputFileUrl;
    _assetExport.outputFileType = AVFileTypeQuickTimeMovie;
    _assetExport.shouldOptimizeForNetworkUse = YES;
    [_assetExport exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self exportDidFinish:_assetExport];
        });
    }];
}

-(void)addAudioToVideo {
    NSString *bundleDirectory = [[NSBundle mainBundle] bundlePath];
    // audio input file...
    NSString *audio_inputFilePath = [bundleDirectory stringByAppendingPathComponent:@"Prapty.mp3"];
    NSURL    *audio_inputFileUrl = [NSURL fileURLWithPath:audio_inputFilePath];
    
    // this is the video file that was just written above, full path to file is in --> videoOutputPath
    NSURL    *video_inputFileUrl = assetUrl;
    
    // create the final video output file as MOV file - may need to be MP4, but this works so far...
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *myPathDocs =  [documentsDirectory stringByAppendingPathComponent:
                             [NSString stringWithFormat:@"FinalVideo-%d.mov",arc4random() % 1000]];
    NSURL *outputFileUrl = [NSURL fileURLWithPath:myPathDocs];
    
    CMTime nextClipStartTime = kCMTimeZero;
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    //Video And Audio Composition track
    AVMutableCompositionTrack *a_compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *b_compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    //Video and Audio Asset
    AVURLAsset* videoAsset = [[AVURLAsset alloc]initWithURL:video_inputFileUrl options:nil];
    AVURLAsset* audioAsset = [[AVURLAsset alloc]initWithURL:audio_inputFileUrl options:nil];
   
    // Get the first video track from each asset.
    AVAssetTrack *videoAssetTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    AVAssetTrack *audioAssetTrack = [[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
   
    //Get time duration
    CMTimeRange video_timeRange = CMTimeRangeMake(kCMTimeZero,videoAsset.duration);

    [a_compositionVideoTrack insertTimeRange:video_timeRange ofTrack:videoAssetTrack atTime:nextClipStartTime error:nil];
    [b_compositionAudioTrack insertTimeRange:video_timeRange ofTrack:audioAssetTrack atTime:nextClipStartTime error:nil];

    //instructions
    AVMutableVideoCompositionInstruction *mainInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruction.timeRange = video_timeRange;
    
    //Instruction Layer
    AVMutableVideoCompositionLayerInstruction *videolayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:a_compositionVideoTrack];
    
    UIImageOrientation videoAssetOrientation_  = UIImageOrientationUp;
    BOOL isVideoAssetPortrait_  = NO;
    CGAffineTransform videoTransform = videoAssetTrack.preferredTransform;
    if (videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0) {
        videoAssetOrientation_ = UIImageOrientationRight;
        isVideoAssetPortrait_ = YES;
    }
    if (videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0) {
        videoAssetOrientation_ =  UIImageOrientationLeft;
        isVideoAssetPortrait_ = YES;
    }
    if (videoTransform.a == 1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == 1.0) {
        videoAssetOrientation_ =  UIImageOrientationUp;
    }
    if (videoTransform.a == -1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == -1.0) {
        videoAssetOrientation_ = UIImageOrientationDown;
    }
    //CMTime subTime = CMTimeAdd(kCMTimeZero, frameTime);
    [videolayerInstruction setTransform:videoAssetTrack.preferredTransform atTime:kCMTimeZero];

    [videolayerInstruction setOpacity:0.0 atTime:videoAsset.duration];
    
    mainInstruction.layerInstructions = [NSArray arrayWithObjects:videolayerInstruction,nil];
    
    AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];
    
    CGSize naturalSize;
    if(isVideoAssetPortrait_){
        naturalSize = CGSizeMake(videoAssetTrack.naturalSize.height, videoAssetTrack.naturalSize.width);
    } else {
        naturalSize = videoAssetTrack.naturalSize;
    }
    
    float renderWidth, renderHeight;
    renderWidth = naturalSize.width;
    renderHeight = naturalSize.height;
    mainCompositionInst.renderSize = CGSizeMake(renderWidth, renderHeight);
    mainCompositionInst.instructions = [NSArray arrayWithObject:mainInstruction];
    mainCompositionInst.frameDuration = CMTimeMake(1, 4);
    
    //Export Session
    AVAssetExportSession* _assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
    
    //Export
    _assetExport.outputURL=outputFileUrl;
    _assetExport.outputFileType = AVFileTypeQuickTimeMovie;
    _assetExport.shouldOptimizeForNetworkUse = YES;
    _assetExport.videoComposition = mainCompositionInst;
    [_assetExport exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self exportDidFinish:_assetExport];
        });
    }];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
- (IBAction)createAndSave:(UIButton *)sender {
    [self initialization];
    [self createAndSaveVideo];
}
- (NSDictionary *)videoSettingsWithCodec:(NSString *)codec withWidth:(CGFloat)width andHeight:(CGFloat)height {
    if ((int)width % 16 != 0 ) {
        NSLog(@"Warning: video settings width must be divisible by 16.");
    }
    NSDictionary *videoSettings = @{AVVideoCodecKey : AVVideoCodecH264,
                                    AVVideoWidthKey : [NSNumber numberWithInt:(int)width],
                                    AVVideoHeightKey : [NSNumber numberWithInt:(int)height]};
    return videoSettings;
}
@end

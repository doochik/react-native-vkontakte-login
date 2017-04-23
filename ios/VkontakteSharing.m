#import <React/RCTBridge.h>
#import <React/RCTConvert.h>
#import <React/RCTUtils.h>
#import <React/RCTImageLoader.h>
#import <React/RCTImageSource.h>

#import "VkontakteSharing.h"
#import "VKSdk.h"

#ifdef DEBUG
#define DMLog(...) NSLog(@"[VKSharing] %s %@", __PRETTY_FUNCTION__, [NSString stringWithFormat:__VA_ARGS__])
#else
#define DMLog(...) do { } while (0)
#endif

@implementation VkontakteSharing

@synthesize bridge = _bridge;

- (void)openShareDlg:(VKShareDialogController *) dialog resolver: (RCTPromiseResolveBlock) resolve rejecter:(RCTPromiseRejectBlock) reject {
  UIViewController *root = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
  [dialog setCompletionHandler:^(VKShareDialogController *dialog, VKShareDialogControllerResult result) {
    if (result == VKShareDialogControllerResultDone) {
      DMLog(@"onVkShareComplete");
      resolve(dialog.postId);
      // done
    } else if (result == VKShareDialogControllerResultCancelled) {
      DMLog(@"onVkShareCancel");
      reject(RCTErrorUnspecified, nil, RCTErrorWithMessage(@"canceled"));
    }
  }];

  [root presentViewController:dialog animated:YES completion:nil];
}

RCT_EXPORT_MODULE();

- (dispatch_queue_t)methodQueue {
  return dispatch_get_main_queue();
}

RCT_EXPORT_METHOD(wallPost: (NSDictionary *) data resolver: (RCTPromiseResolveBlock) resolve rejecter:(RCTPromiseRejectBlock) reject) {
  DMLog(@"Open Share Dialog");
  if (![VKSdk initialized]){
    reject(RCTErrorUnspecified, nil, RCTErrorWithMessage(@"VK SDK must be initialized first"));
    return;
  }

  NSArray *permissions = @[VK_PER_WALL];
  VKSdk *sdk = [VKSdk instance];
  if (![sdk hasPermissions:permissions]){
    reject(RCTErrorUnspecified, nil, RCTErrorWithMessage(@"Access denied: no permission 'wall' to call this method"));
    return;
  }

  VKRequest *postReq = [[VKApi wall] post:@{
                                            VK_API_ATTACHMENTS : [RCTConvert NSString:data[@"link"]],
                                            VK_API_MESSAGE : [RCTConvert NSString:data[@"text"]]
                                            }];
  postReq.attempts = 5;

  [postReq executeWithResultBlock:^(VKResponse *response) {
    DMLog(@"wallPost JSON result: %@", response.json);
    resolve(response.json);
  } errorBlock:^(NSError * error) {
    if (error.code != VK_API_ERROR) {
      [error.vkError.request repeat];
    } else {
      DMLog(@"wallPost VK error: %@", error);

      NSString *errMessage = [NSString stringWithFormat:@"%@", [error localizedDescription]];
      reject(RCTErrorUnspecified, nil, RCTErrorWithMessage(errMessage));
    }
  }];
}

RCT_EXPORT_METHOD(share: (NSDictionary *) data resolver: (RCTPromiseResolveBlock) resolve rejecter:(RCTPromiseRejectBlock) reject) {
  DMLog(@"Open Share Dialog");
  if (![VKSdk initialized]){
    reject(RCTErrorUnspecified, nil, RCTErrorWithMessage(@"VK SDK must be initialized first"));
    return;
  }

  NSString *imagePath = data[@"image"];
  NSMutableArray *permissions = @[VK_PER_WALL];
  if (imagePath != nil && imagePath.length){
    permissions = [permissions arrayByAddingObject:VK_PER_PHOTOS];
  }
  VKSdk *sdk = [VKSdk instance];
  if (![sdk hasPermissions:permissions]){
    reject(RCTErrorUnspecified, nil, RCTErrorWithMessage(@"Access denied: no access to call this method"));
    return;
  }

  VKShareDialogController * shareDialog = [VKShareDialogController new];
  shareDialog.text = [RCTConvert NSString:data[@"description"]];
  shareDialog.shareLink = [[VKShareLink alloc] initWithTitle:[RCTConvert NSString:data[@"linkText"]]
                                               link:[NSURL URLWithString:[RCTConvert NSString:data[@"linkUrl"]]]];
  shareDialog.dismissAutomatically = YES;

  if (imagePath.length && _bridge.imageLoader) {
    RCTImageSource *source = [RCTConvert RCTImageSource:data[@"image"]];

    [_bridge.imageLoader loadImageWithURLRequest:source.request callback:^(NSError *error, UIImage *image) {
      if (image == nil) {
        NSLog(@"Failed to load image");
      } else {
        VKUploadImage *VKImage = [[VKUploadImage alloc] init];
        VKImage.sourceImage = image;
        shareDialog.uploadImages = @[VKImage];
      }
      [self openShareDlg:shareDialog resolver:resolve rejecter:reject];
    }];
  } else {
    [self openShareDlg:shareDialog resolver:resolve rejecter:reject];
  }
}

@end

//
// Created by Matthew Smith on 11/7/17.
//

#import "BarcodeScannerViewController.h"
#import <MTBBarcodeScanner/MTBBarcodeScanner.h>
#import "ScannerOverlay.h"


@interface BarcodeScannerViewController()
  @property(nonatomic, retain) UILabel *textLabel;
@end

@implementation BarcodeScannerViewController {

}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    CGRect bounds = CGRectMake(0, 0, size.width, size.height);
    self.previewView.bounds = bounds;
    self.previewView.frame = bounds;
    [self.scanRect stopAnimating];
    [self.scanRect removeFromSuperview];
    [self.textLabel removeFromSuperview];
    [self setupScanRect:bounds];
    [self setupText:bounds];
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (void)setupScanRect:(CGRect)bounds {
    self.scanRect = [[ScannerOverlay alloc] initWithFrame:bounds];
    self.scanRect.translatesAutoresizingMaskIntoConstraints = NO;
    self.scanRect.backgroundColor = UIColor.clearColor;
    [self.view addSubview:_scanRect];
    [self.view addConstraints:[NSLayoutConstraint
                               constraintsWithVisualFormat:@"V:[scanRect]"
                               options:NSLayoutFormatAlignAllBottom
                               metrics:nil
                               views:@{@"scanRect": _scanRect}]];
    [self.view addConstraints:[NSLayoutConstraint
                               constraintsWithVisualFormat:@"H:[scanRect]"
                               options:NSLayoutFormatAlignAllBottom
                               metrics:nil
                               views:@{@"scanRect": _scanRect}]];
    [_scanRect startAnimating];
}

- (void)setupText:(CGRect)bounds {
    const float textPadding = 16;
    CGRect textBounds = CGRectMake(textPadding, textPadding,
        bounds.size.width-textPadding-textPadding, 0);
    self.textLabel = [[UILabel alloc] initWithFrame:textBounds];
    self.textLabel.textColor = [UIColor whiteColor];
    self.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.textLabel.numberOfLines = 0;
    self.textLabel.textAlignment = NSTextAlignmentCenter;
    self.textLabel.text = self.text;
    [self.textLabel sizeToFit];
    self.textLabel.frame = CGRectMake(
        (bounds.size.width - self.textLabel.frame.size.width) / 2, 16,
        self.textLabel.frame.size.width, self.textLabel.frame.size.height);
    [self.view addSubview:self.textLabel];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.previewView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.previewView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_previewView];
    [self.view addConstraints:[NSLayoutConstraint
            constraintsWithVisualFormat:@"V:[previewView]"
                                options:NSLayoutFormatAlignAllBottom
                                metrics:nil
                                  views:@{@"previewView": _previewView}]];
    [self.view addConstraints:[NSLayoutConstraint
            constraintsWithVisualFormat:@"H:[previewView]"
                                options:NSLayoutFormatAlignAllBottom
                                metrics:nil
                                  views:@{@"previewView": _previewView}]];

    [self setupScanRect:self.view.bounds];
    [self setupText:self.view.bounds];

    self.scanner = [[MTBBarcodeScanner alloc] initWithPreviewView:_previewView];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"close"]
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(cancel)];
    
    [self updateFlashButton];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.scanner.isScanning) {
        [self.scanner stopScanning];
    }
    [MTBBarcodeScanner requestCameraPermissionWithSuccess:^(BOOL success) {
        if (success) {
            [self startScan];
        } else {
            [self.delegate barcodeScannerViewController:self didFailWithErrorCode:@"PERMISSION_NOT_GRANTED"];
            [self dismissViewControllerAnimated:NO completion:nil];
        }
    }];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self.scanner stopScanning];
    [super viewWillDisappear:animated];
    if ([self isFlashOn]) {
        [self toggleFlash:NO];
    }
}

- (void)startScan {
    NSError *error;
    [self.scanner startScanningWithCamera:self.useFrontCamera ? MTBCameraFront : MTBCameraBack
                              resultBlock:^(NSArray<AVMetadataMachineReadableCodeObject *> *codes) {
        [self.scanner stopScanning];
        AVMetadataMachineReadableCodeObject *code = codes.firstObject;
        if (code) {
            [self.delegate barcodeScannerViewController:self didScanBarcodeWithResult:code.stringValue];
            [self dismissViewControllerAnimated:NO completion:nil];
        }
    } error:&error];
}

- (void)cancel {
    [self.delegate barcodeScannerViewController:self didFailWithErrorCode:@"USER_CANCELED"];
    [self dismissViewControllerAnimated:true completion:nil];
}

- (void)updateFlashButton {
    if (!self.hasTorch) {
        return;
    }
    if (self.isFlashOn) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"flash-off"]
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(toggle)];
    } else {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"flash-on"]
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(toggle)];
    }
}

- (void)toggle {
    [self toggleFlash:!self.isFlashOn];
    [self updateFlashButton];
}

- (BOOL)isFlashOn {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (device) {
        return device.torchMode == AVCaptureFlashModeOn || device.torchMode == AVCaptureTorchModeOn;
    }
    return NO;
}

- (BOOL)hasTorch {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (device) {
        return device.hasTorch;
    }
    return false;
}

- (void)toggleFlash:(BOOL)on {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!device) return;
    
    NSError *err;
    if (device.hasFlash && device.hasTorch) {
        [device lockForConfiguration:&err];
        if (err != nil) return;
        if (on) {
            device.flashMode = AVCaptureFlashModeOn;
            device.torchMode = AVCaptureTorchModeOn;
        } else {
            device.flashMode = AVCaptureFlashModeOff;
            device.torchMode = AVCaptureTorchModeOff;
        }
        [device unlockForConfiguration];
    }
}


@end

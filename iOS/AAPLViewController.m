/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of our iOS view controller
*/

#import "AAPLViewController.h"
#import "AAPLRenderer.h"

@interface AAPLViewController ()

@property (nonatomic, retain) IBOutlet MTKView * subview;

@end

@implementation AAPLViewController
{
    //MTKView *_subview;

    AAPLRenderer *_renderer;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Set the view to use the default device
    //_subview = (MTKView *)self.subview;
    NSAssert(self.subview, @"subview");
  
    self.subview.frame = CGRectMake(
                                  self.view.frame.size.width / 2,
                                  self.view.frame.size.height / 2,
                                  300, 300);
  
    self.subview.device = MTLCreateSystemDefaultDevice();

    if(!self.subview.device)
    {
        NSLog(@"Metal is not supported on this device");
        self.view = [[UIView alloc] initWithFrame:self.view.frame];
    }

    _renderer = [[AAPLRenderer alloc] initWithMetalKitView:self.subview];

    if(!_renderer)
    {
        NSLog(@"Renderer failed initialization");
        return;
    }

    [_renderer mtkView:self.subview drawableSizeWillChange:self.subview.drawableSize];

    self.subview.delegate = _renderer;
}

@end

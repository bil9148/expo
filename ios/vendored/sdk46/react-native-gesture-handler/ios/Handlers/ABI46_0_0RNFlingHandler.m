#import "ABI46_0_0RNFlingHandler.h"

@interface ABI46_0_0RNBetterSwipeGestureRecognizer : UISwipeGestureRecognizer

- (id)initWithGestureHandler:(ABI46_0_0RNGestureHandler*)gestureHandler;

@end

@implementation ABI46_0_0RNBetterSwipeGestureRecognizer {
  __weak ABI46_0_0RNGestureHandler* _gestureHandler;
  CGPoint _lastPoint; // location of the most recently updated touch, relative to the view
  bool _hasBegan; // whether the `BEGAN` event has been sent
}

- (id)initWithGestureHandler:(ABI46_0_0RNGestureHandler *)gestureHandler
{
  if ((self = [super initWithTarget:gestureHandler action:@selector(handleGesture:)])) {
    _gestureHandler = gestureHandler;
    _lastPoint = CGPointZero;
    _hasBegan = NO;
  }
  return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  _lastPoint = [[[touches allObjects] objectAtIndex:0] locationInView:_gestureHandler.recognizer.view];
  [_gestureHandler reset];
  [super touchesBegan:touches withEvent:event];

  // self.numberOfTouches doesn't work for this because in case than one finger is required,
  // when holding one finger on the screen and tapping with the second one, numberOfTouches is equal
  // to 2 only for the first tap but 1 for all the following ones
  if (!_hasBegan) {
    [self triggerAction];
    _hasBegan = YES;
  }

  [_gestureHandler.pointerTracker touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  _lastPoint = [[[touches allObjects] objectAtIndex:0] locationInView:_gestureHandler.recognizer.view];
  [super touchesMoved:touches withEvent:event];
  [_gestureHandler.pointerTracker touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  _lastPoint = [[[touches allObjects] objectAtIndex:0] locationInView:_gestureHandler.recognizer.view];
  [super touchesEnded:touches withEvent:event];
  [_gestureHandler.pointerTracker touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  _lastPoint = [[[touches allObjects] objectAtIndex:0] locationInView:_gestureHandler.recognizer.view];
  [super touchesCancelled:touches withEvent:event];
  [_gestureHandler.pointerTracker touchesCancelled:touches withEvent:event];
}

- (void)triggerAction
{
  [_gestureHandler handleGesture:self];
}

- (void)reset
{
  [self triggerAction];
  [_gestureHandler.pointerTracker reset];
  _hasBegan = NO;
  [super reset];
}

- (CGPoint)getLastLocation {
  // I think keeping the location of only one touch is enough since it would be used to determine the direction
  // of the movement, and if it's wrong the recognizer fails anyway.
  // In case the location of all touches is required, touch events are the way to go
  return _lastPoint;
}

@end

@implementation ABI46_0_0RNFlingGestureHandler

- (instancetype)initWithTag:(NSNumber *)tag
{
  if ((self = [super initWithTag:tag])) {
    _recognizer = [[ABI46_0_0RNBetterSwipeGestureRecognizer alloc] initWithGestureHandler:self];
  }
  return self;
}
- (void)resetConfig
{
  [super resetConfig];
  UISwipeGestureRecognizer *recognizer = (UISwipeGestureRecognizer *)_recognizer;
  recognizer.direction = UISwipeGestureRecognizerDirectionRight;
#if !TARGET_OS_TV
  recognizer.numberOfTouchesRequired = 1;
#endif
}

- (void)configure:(NSDictionary *)config
{
    [super configure:config];
    UISwipeGestureRecognizer *recognizer = (UISwipeGestureRecognizer *)_recognizer;

    id prop = config[@"direction"];
    if (prop != nil) {
        recognizer.direction = [ABI46_0_0RCTConvert NSInteger:prop];
    }
    
#if !TARGET_OS_TV
    prop = config[@"numberOfPointers"];
    if (prop != nil) {
        recognizer.numberOfTouchesRequired = [ABI46_0_0RCTConvert NSInteger:prop];
    }
#endif
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    ABI46_0_0RNGestureHandlerState savedState = _lastState;
    BOOL shouldBegin = [super gestureRecognizerShouldBegin:gestureRecognizer];
    _lastState = savedState;
    
    return shouldBegin;
}

- (ABI46_0_0RNGestureHandlerEventExtraData *)eventExtraData:(id)_recognizer
{
    // For some weird reason [recognizer locationInView:recognizer.view.window] returns (0, 0).
    // To calculate the correct absolute position, first calculate the absolute position of the
    // view inside the root view controller (https://stackoverflow.com/a/7448573) and then
    // add the relative touch position to it.
    
    ABI46_0_0RNBetterSwipeGestureRecognizer *recognizer = (ABI46_0_0RNBetterSwipeGestureRecognizer *)_recognizer;
    
    CGPoint viewAbsolutePosition = [recognizer.view convertPoint:recognizer.view.bounds.origin toView:[UIApplication sharedApplication].keyWindow.rootViewController.view];
    CGPoint locationInView = [recognizer getLastLocation];
    
    return [ABI46_0_0RNGestureHandlerEventExtraData
            forPosition:locationInView
            withAbsolutePosition:CGPointMake(viewAbsolutePosition.x + locationInView.x, viewAbsolutePosition.y + locationInView.y)
            withNumberOfTouches:recognizer.numberOfTouches];
}

@end


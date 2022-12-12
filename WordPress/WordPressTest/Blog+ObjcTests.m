#import <XCTest/XCTest.h>
#import "WordPressTest-Swift.h"

@interface Blog_ObjcTests : XCTestCase
@property (strong, nonatomic) ContextManager *contextManager;
@end

@implementation Blog_ObjcTests

- (void)setUp {
    self.contextManager = [ContextManager forTesting];
    [super setUp];
}

- (void)testThatNilBlogIDDoesNotCrashWhenCreatingPredicate {
    NSNumber *number = nil;
    Blog *blog = [Blog lookupWithID:number in:self.contextManager.mainContext];
    XCTAssertNil(blog);
}

@end

// Copyright (c) 2014-present, Facebook, Inc. All rights reserved.
//
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Facebook.
//
// As with any software that integrates with the Facebook platform, your use of
// this software is subject to the Facebook Developer Principles and Policies
// [http://developers.facebook.com/policy/]. This copyright notice shall be
// included in all copies or substantial portions of the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>

#import "FBSDKAccessToken.h"
#import "FBSDKAppEvents.h"
#import "FBSDKAppEventsState.h"
#import "FBSDKAppEventsUtility.h"
#import "FBSDKApplicationDelegate.h"
#import "FBSDKConstants.h"
#import "FBSDKGraphRequest+Internal.h"
#import "FBSDKGraphRequest.h"
#import "FBSDKUtility.h"

static NSString *const _mockAppID = @"mockAppID";

// An extension that redeclares a private method so that it can be mocked
@interface FBSDKApplicationDelegate ()
- (void)_logSDKInitialize;
@end

@interface FBSDKAppEvents ()
@property (nonatomic, copy) NSString *pushNotificationsDeviceTokenString;
- (void)checkPersistedEvents;
- (void)publishInstall;
- (void)flushForReason:(FBSDKAppEventsFlushReason)flushReason;
- (void)fetchServerConfiguration:(FBSDKCodeBlock)callback;
+ (FBSDKAppEvents *)singleton;

+ (void)logInternalEvent:(FBSDKAppEventName)eventName
              parameters:(NSDictionary *)parameters
      isImplicitlyLogged:(BOOL)isImplicitlyLogged;

@end

@interface FBSDKAppEventsTests : XCTestCase
{
  id _mockAppEvents;
}
@end

@implementation FBSDKAppEventsTests

- (void)setUp
{
  _mockAppEvents = [OCMockObject niceMockForClass:[FBSDKAppEvents class]];
  [FBSDKAppEvents setLoggingOverrideAppID:_mockAppID];
}

- (void)tearDown
{
  [_mockAppEvents stopMocking];
}

- (void)testLogPurchase
{
  double mockPurchaseAmount = 1.0;
  NSString *mockCurrency = @"USD";

  id partialMockAppEvents = [OCMockObject partialMockForObject:[FBSDKAppEvents singleton]];

  [[partialMockAppEvents expect] logEvent:FBSDKAppEventNamePurchased valueToSum:@(mockPurchaseAmount) parameters:[OCMArg any] accessToken:[OCMArg any]];
  [[partialMockAppEvents expect] flushForReason:FBSDKAppEventsFlushReasonEagerlyFlushingEvent];

  OCMStub([partialMockAppEvents flushBehavior]).andReturn(FBSDKAppEventsFlushReasonEagerlyFlushingEvent);

  [FBSDKAppEvents logPurchase:mockPurchaseAmount currency:mockCurrency];

  [partialMockAppEvents verify];
}

- (void)testLogProductItemNonNil
{
  NSDictionary<NSString *, NSString *> *expectedDict = @{
                                 @"fb_product_availability":@"IN_STOCK",
                                 @"fb_product_brand":@"PHILZ",
                                 @"fb_product_condition":@"NEW",
                                 @"fb_product_description":@"description",
                                 @"fb_product_gtin":@"BLUE MOUNTAIN",
                                 @"fb_product_image_link":@"https://www.sample.com",
                                 @"fb_product_item_id":@"F40CEE4E-471E-45DB-8541-1526043F4B21",
                                 @"fb_product_link":@"https://www.sample.com",
                                 @"fb_product_mpn":@"BLUE MOUNTAIN",
                                 @"fb_product_price_amount":@"1.000",
                                 @"fb_product_price_currency":@"USD",
                                 @"fb_product_title":@"title",
                                 };
  [[_mockAppEvents expect] logEvent:@"fb_mobile_catalog_update"
                         parameters:expectedDict];

  [FBSDKAppEvents logProductItem:@"F40CEE4E-471E-45DB-8541-1526043F4B21"
                    availability:FBSDKProductAvailabilityInStock
                       condition:FBSDKProductConditionNew
                     description:@"description"
                       imageLink:@"https://www.sample.com"
                            link:@"https://www.sample.com"
                           title:@"title"
                     priceAmount:1.0
                        currency:@"USD"
                            gtin:@"BLUE MOUNTAIN"
                             mpn:@"BLUE MOUNTAIN"
                           brand:@"PHILZ"
                      parameters:@{}];

  [_mockAppEvents verify];
}

- (void)testLogProductItemNilGtinMpnBrand
{
  NSDictionary<NSString *, NSString *> *expectedDict = @{
                                                         @"fb_product_availability":@"IN_STOCK",
                                                         @"fb_product_condition":@"NEW",
                                                         @"fb_product_description":@"description",
                                                         @"fb_product_image_link":@"https://www.sample.com",
                                                         @"fb_product_item_id":@"F40CEE4E-471E-45DB-8541-1526043F4B21",
                                                         @"fb_product_link":@"https://www.sample.com",
                                                         @"fb_product_price_amount":@"1.000",
                                                         @"fb_product_price_currency":@"USD",
                                                         @"fb_product_title":@"title",
                                                         };
  [[_mockAppEvents reject] logEvent:@"fb_mobile_catalog_update"
                         parameters:expectedDict];

  [FBSDKAppEvents logProductItem:@"F40CEE4E-471E-45DB-8541-1526043F4B21"
                    availability:FBSDKProductAvailabilityInStock
                       condition:FBSDKProductConditionNew
                     description:@"description"
                       imageLink:@"https://www.sample.com"
                            link:@"https://www.sample.com"
                           title:@"title"
                     priceAmount:1.0
                        currency:@"USD"
                            gtin:nil
                             mpn:nil
                           brand:nil
                      parameters:@{}];

  [_mockAppEvents verify];
}

- (void)testSetAndClearUserData
{
  NSString *mockEmail= @"test_em";
  NSString *mockFirstName = @"test_fn";
  NSString *mockLastName = @"test_ln";
  NSString *mockPhone = @"123";

  [FBSDKAppEvents setUserEmail:mockEmail
                     firstName:mockFirstName
                      lastName:mockLastName
                         phone:mockPhone
                   dateOfBirth:nil
                        gender:nil
                          city:nil
                         state:nil
                           zip:nil
                       country:nil];

  NSDictionary<NSString *, NSString *> *expectedHashedDict = @{@"em":[FBSDKUtility SHA256Hash:mockEmail],
                                                               @"fn":[FBSDKUtility SHA256Hash:mockFirstName],
                                                               @"ln":[FBSDKUtility SHA256Hash:mockLastName],
                                                               @"ph":[FBSDKUtility SHA256Hash:mockPhone],
                                                               };
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:expectedHashedDict
                                                     options:0
                                                       error:nil];
  NSString *expectedUserData = [[NSString alloc] initWithData:jsonData
                                 encoding:NSUTF8StringEncoding];
  NSString *userData = [FBSDKAppEvents getUserData];
  XCTAssertEqualObjects(userData, expectedUserData);

  [FBSDKAppEvents clearUserData];
  NSString *clearedUserData = [FBSDKAppEvents getUserData];
  XCTAssertEqualObjects(clearedUserData, @"{}");
}

- (void)testSetAndClearUserID
{
  NSString *mockUserId = @"1";
  [FBSDKAppEvents setUserID:mockUserId];
  XCTAssertEqualObjects([FBSDKAppEvents userID], mockUserId);
  [FBSDKAppEvents clearUserID];
  XCTAssertNil([FBSDKAppEvents userID]);
}

- (void)testSetLoggingOverrideAppID
{
  NSString *mockOverrideAppID = @"2";
  [FBSDKAppEvents setLoggingOverrideAppID:mockOverrideAppID];
  XCTAssertEqualObjects([FBSDKAppEvents loggingOverrideAppID], mockOverrideAppID);
}

- (void)testSetPushNotificationsDeviceTokenString
{
  NSString *mockDeviceTokenString = @"testDeviceTokenString";

  [[_mockAppEvents expect] logEvent:@"fb_mobile_obtain_push_token"];

  [FBSDKAppEvents setPushNotificationsDeviceTokenString:mockDeviceTokenString];

  [_mockAppEvents verify];

  XCTAssertEqualObjects([FBSDKAppEvents singleton].pushNotificationsDeviceTokenString, mockDeviceTokenString);
}

- (void)testLogInitialize
{
  FBSDKApplicationDelegate *delegate = [FBSDKApplicationDelegate sharedInstance];
  id delegateMock = OCMPartialMock(delegate);

  [[_mockAppEvents expect] logInternalEvent:@"fb_sdk_initialize"
                                 parameters:[OCMArg any]
                         isImplicitlyLogged:NO];

  [delegateMock _logSDKInitialize];

  [_mockAppEvents verify];
}

- (void)testActivateApp
{
  id partialMockAppEvents = [OCMockObject partialMockForObject:[FBSDKAppEvents singleton]];
  [[partialMockAppEvents expect] publishInstall];
  [[partialMockAppEvents expect] fetchServerConfiguration:NULL];

  [FBSDKAppEvents activateApp];

  [partialMockAppEvents verify];
}

- (void)testLogPushNotificationOpen
{
  NSDictionary <NSString *, NSString *> *mockFacebookPayload = @{@"campaign" : @"testCampaign"};
  NSDictionary <NSString *, NSDictionary<NSString *, NSString*> *> *mockPayload = @{@"fb_push_payload" : mockFacebookPayload};

  NSDictionary <NSString *, NSString *> *expectedParams = @{
                                                            @"fb_push_campaign":@"testCampaign",
                                                            };

  [[_mockAppEvents expect] logEvent:@"fb_mobile_push_opened" parameters:expectedParams];

  [FBSDKAppEvents logPushNotificationOpen:mockPayload];

  [_mockAppEvents verify];
}

- (void)testLogPushNotificationOpenEmptyCampaign
{
  NSDictionary <NSString *, NSString *> *mockFacebookPayload = @{@"campaign" : @""};
  NSDictionary <NSString *, NSDictionary<NSString *, NSString*> *> *mockPayload = @{@"fb_push_payload" : mockFacebookPayload};

  [[_mockAppEvents reject] logEvent:@"fb_mobile_push_opened" parameters:[OCMArg any]];

  [FBSDKAppEvents logPushNotificationOpen:mockPayload];

  [_mockAppEvents verify];
}

- (void)testLogPushNotificationOpenWithNonEmptyAction
{
  NSDictionary <NSString *, NSString *> *mockFacebookPayload = @{@"campaign" : @"testCampaign"};
  NSDictionary <NSString *, NSDictionary<NSString *, NSString*> *> *mockPayload = @{@"fb_push_payload" : mockFacebookPayload};

  NSDictionary <NSString *, NSString *> *expectedParams = @{
                                                            @"fb_push_action":@"testAction",
                                                            @"fb_push_campaign":@"testCampaign",
                                                            };

  [[_mockAppEvents expect] logEvent:@"fb_mobile_push_opened" parameters:expectedParams];

  [FBSDKAppEvents logPushNotificationOpen:mockPayload action:@"testAction"];

  [_mockAppEvents verify];
}

- (void)testLogPushNotificationOpenWithEmptyPayload
{
  [[_mockAppEvents reject] logEvent:@"fb_mobile_push_opened" parameters:[OCMArg any]];

  [FBSDKAppEvents logPushNotificationOpen:@{}];

  [_mockAppEvents verify];
}

- (void)testSetFlushBehavior
{
  [FBSDKAppEvents setFlushBehavior:FBSDKAppEventsFlushBehaviorAuto];
  XCTAssertEqual(FBSDKAppEventsFlushBehaviorAuto, FBSDKAppEvents.flushBehavior);

  [FBSDKAppEvents setFlushBehavior:FBSDKAppEventsFlushBehaviorExplicitOnly];
  XCTAssertEqual(FBSDKAppEventsFlushBehaviorExplicitOnly, FBSDKAppEvents.flushBehavior);
}

- (void)testCheckPersistedEventsCalledWhenLogEvent
{
  double mockPurchaseAmount = 1.0;

  id partialMockAppEvents = [OCMockObject partialMockForObject:[FBSDKAppEvents singleton]];

  [[partialMockAppEvents expect] checkPersistedEvents];

  OCMStub([partialMockAppEvents flushBehavior]).andReturn(FBSDKAppEventsFlushReasonEagerlyFlushingEvent);

  [FBSDKAppEvents logEvent:FBSDKAppEventNamePurchased valueToSum:@(mockPurchaseAmount) parameters:@{} accessToken:nil];

  [partialMockAppEvents verify];
}

- (void)testRequestForCustomAudienceThirdPartyIDWithAccessToken
{
  id mockAccessToken = [OCMockObject niceMockForClass:[FBSDKAccessToken class]];

  NSString *tokenString = [FBSDKAppEventsUtility tokenStringToUseFor:mockAccessToken];
  NSString *graphPath = [NSString stringWithFormat:@"%@/custom_audience_third_party_id", _mockAppID];
  FBSDKGraphRequest *expectedRequest = [[FBSDKGraphRequest alloc] initWithGraphPath:graphPath
                                                                         parameters:@{}
                                                                        tokenString:tokenString
                                                                         HTTPMethod:nil
                                                                              flags:FBSDKGraphRequestFlagDoNotInvalidateTokenOnError | FBSDKGraphRequestFlagDisableErrorRecovery];

  OCMStub([FBSDKAppEventsUtility advertisingTrackingStatus] == FBSDKAdvertisingTrackingDisallowed ).andReturn(@YES);
  FBSDKGraphRequest *request = [FBSDKAppEvents requestForCustomAudienceThirdPartyIDWithAccessToken:mockAccessToken];

  XCTAssertEqualObjects(expectedRequest.graphPath, request.graphPath);
  XCTAssertEqualObjects(expectedRequest.HTTPMethod, request.HTTPMethod);
  XCTAssertEqualObjects(expectedRequest.parameters, expectedRequest.parameters);
}

- (void)testPublishInstall
{
  id partialMockAppEvents = [OCMockObject partialMockForObject:[FBSDKAppEvents singleton]];
  [[partialMockAppEvents expect] fetchServerConfiguration:[OCMArg any]];

  [[FBSDKAppEvents singleton] publishInstall];

  [partialMockAppEvents verify];
}

@end

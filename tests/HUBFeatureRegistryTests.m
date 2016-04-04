#import <XCTest/XCTest.h>

#import "HUBFeatureRegistryImplementation.h"
#import "HUBFeatureConfiguration.h"
#import "HUBFeatureRegistration.h"
#import "HUBContentProviderFactoryMock.h"
#import "HUBViewURIQualifierMock.h"

@interface HUBFeatureRegistryTests : XCTestCase

@property (nonatomic, strong) HUBFeatureRegistryImplementation *registry;

@end

@implementation HUBFeatureRegistryTests

#pragma mark - XCTestCase

- (void)setUp
{
    [super setUp];
    self.registry = [HUBFeatureRegistryImplementation new];
}

#pragma mark - Tests

- (void)testConfigurationPropertyAssignment
{
    NSString * const featureIdentifier = @"Awesome feature";
    NSURL * const rootViewURI = [NSURL URLWithString:@"spotify:hub:framework"];
    HUBContentProviderFactoryMock * const contentProviderFactory = [[HUBContentProviderFactoryMock alloc] initWithContentProviders:@[]];
    
    id<HUBFeatureConfiguration> const configuration = [self.registry createConfigurationForFeatureWithIdentifier:featureIdentifier
                                                                                                     rootViewURI:rootViewURI
                                                                                        contentProviderFactories:@[contentProviderFactory]];
    
    XCTAssertEqualObjects(configuration.featureIdentifier, featureIdentifier);
    XCTAssertEqualObjects(configuration.rootViewURI, rootViewURI);
    XCTAssertEqualObjects(configuration.contentProviderFactories, @[contentProviderFactory]);
}

- (void)testConflictingRootViewURIsTriggerAssert
{
    NSURL * const rootViewURI = [NSURL URLWithString:@"spotify:hub:framework"];
    id<HUBContentProviderFactory> const contentProviderFactory = [[HUBContentProviderFactoryMock alloc] initWithContentProviders:@[]];
    
    id<HUBFeatureConfiguration> const configurationA = [self.registry createConfigurationForFeatureWithIdentifier:@"featureA"
                                                                                                      rootViewURI:rootViewURI
                                                                                         contentProviderFactories:@[contentProviderFactory]];
    
    id<HUBFeatureConfiguration> const configurationB = [self.registry createConfigurationForFeatureWithIdentifier:@"featureB"
                                                                                                      rootViewURI:rootViewURI
                                                                                         contentProviderFactories:@[contentProviderFactory]];
    
    [self.registry registerFeatureWithConfiguration:configurationA];
    XCTAssertThrows([self.registry registerFeatureWithConfiguration:configurationB]);
}

- (void)testConflictingIdentifiersTriggerAssert
{
    NSString * const identifier = @"identifier";
    
    NSURL * const rootViewURIA = [NSURL URLWithString:@"spotify:hub:framework:a"];
    NSURL * const rootViewURIB = [NSURL URLWithString:@"spotify:hub:framework:b"];
    id<HUBContentProviderFactory> const contentProviderFactory = [[HUBContentProviderFactoryMock alloc] initWithContentProviders:@[]];
    
    id<HUBFeatureConfiguration> const configurationA = [self.registry createConfigurationForFeatureWithIdentifier:identifier
                                                                                                      rootViewURI:rootViewURIA
                                                                                         contentProviderFactories:@[contentProviderFactory]];
    
    id<HUBFeatureConfiguration> const configurationB = [self.registry createConfigurationForFeatureWithIdentifier:identifier
                                                                                                      rootViewURI:rootViewURIB
                                                                                         contentProviderFactories:@[contentProviderFactory]];
    
    [self.registry registerFeatureWithConfiguration:configurationA];
    XCTAssertThrows([self.registry registerFeatureWithConfiguration:configurationB]);
}

- (void)testRegistrationAndConfigurationMatch
{
    NSURL * const rootViewURI = [NSURL URLWithString:@"spotify:hub:framework"];
    id<HUBContentProviderFactory> const contentProviderFactory = [[HUBContentProviderFactoryMock alloc] initWithContentProviders:@[]];
    
    id<HUBFeatureConfiguration> const configuration = [self.registry createConfigurationForFeatureWithIdentifier:@"feature"
                                                                                                     rootViewURI:rootViewURI
                                                                                        contentProviderFactories:@[contentProviderFactory]];
    
    configuration.customJSONSchemaIdentifier = @"custom schema";
    configuration.viewURIQualifier = [[HUBViewURIQualifierMock alloc] initWithDisqualifiedViewURIs:@[]];
    [self.registry registerFeatureWithConfiguration:configuration];
    
    HUBFeatureRegistration * const registration = [self.registry featureRegistrationForViewURI:rootViewURI];
    XCTAssertEqualObjects(registration.featureIdentifier, configuration.featureIdentifier);
    XCTAssertEqualObjects(registration.rootViewURI, configuration.rootViewURI);
    XCTAssertEqualObjects(registration.contentProviderFactories, configuration.contentProviderFactories);
    XCTAssertEqualObjects(registration.customJSONSchemaIdentifier, configuration.customJSONSchemaIdentifier);
    XCTAssertEqual(registration.viewURIQualifier, configuration.viewURIQualifier);
}

- (void)testSubviewMatch
{
    NSURL * const rootViewURI = [NSURL URLWithString:@"spotify:hub:framework"];
    id<HUBContentProviderFactory> const contentProviderFactory = [[HUBContentProviderFactoryMock alloc] initWithContentProviders:@[]];
    
    id<HUBFeatureConfiguration> const configuration = [self.registry createConfigurationForFeatureWithIdentifier:@"feature"
                                                                                                     rootViewURI:rootViewURI
                                                                                        contentProviderFactories:@[contentProviderFactory]];
    
    [self.registry registerFeatureWithConfiguration:configuration];
    
    NSURL * const subviewURI = [NSURL URLWithString:[NSString stringWithFormat:@"%@:subview", rootViewURI.absoluteString]];
    XCTAssertEqualObjects([self.registry featureRegistrationForViewURI:subviewURI].rootViewURI, rootViewURI);
}

- (void)testDisqualifyingRootViewURI
{
    NSURL * const rootViewURI = [NSURL URLWithString:@"spotify:hub:framework"];
    id<HUBContentProviderFactory> const contentProviderFactory = [[HUBContentProviderFactoryMock alloc] initWithContentProviders:@[]];
    
    id<HUBFeatureConfiguration> const configuration = [self.registry createConfigurationForFeatureWithIdentifier:@"feature"
                                                                                                     rootViewURI:rootViewURI
                                                                                        contentProviderFactories:@[contentProviderFactory]];
    
    configuration.viewURIQualifier = [[HUBViewURIQualifierMock alloc] initWithDisqualifiedViewURIs:@[rootViewURI]];
    [self.registry registerFeatureWithConfiguration:configuration];
    
    XCTAssertNil([self.registry featureRegistrationForViewURI:rootViewURI]);
    
    NSURL * const subviewURI = [NSURL URLWithString:[NSString stringWithFormat:@"%@:subview", rootViewURI.absoluteString]];
    XCTAssertEqualObjects([self.registry featureRegistrationForViewURI:subviewURI].rootViewURI, rootViewURI);
}

- (void)testDisqualifyingSubviewURI
{
    NSURL * const rootViewURI = [NSURL URLWithString:@"spotify:hub:framework"];
    NSURL * const subviewURI = [NSURL URLWithString:[NSString stringWithFormat:@"%@:subview", rootViewURI.absoluteString]];
    id<HUBContentProviderFactory> const contentProviderFactory = [[HUBContentProviderFactoryMock alloc] initWithContentProviders:@[]];
    
    id<HUBFeatureConfiguration> const configuration = [self.registry createConfigurationForFeatureWithIdentifier:@"feature"
                                                                                                     rootViewURI:rootViewURI
                                                                                        contentProviderFactories:@[contentProviderFactory]];
    
    configuration.viewURIQualifier = [[HUBViewURIQualifierMock alloc] initWithDisqualifiedViewURIs:@[subviewURI]];
    [self.registry registerFeatureWithConfiguration:configuration];
    
    XCTAssertEqualObjects([self.registry featureRegistrationForViewURI:rootViewURI].rootViewURI, configuration.rootViewURI);
    XCTAssertNil([self.registry featureRegistrationForViewURI:subviewURI]);
}

- (void)testUnregisteringFeature
{
    NSString * const identifier = @"Awesome feature";
    NSURL * const rootViewURI = [NSURL URLWithString:@"spotify:hub:framework"];
    id<HUBContentProviderFactory> const contentProviderFactory = [[HUBContentProviderFactoryMock alloc] initWithContentProviders:@[]];
    
    id<HUBFeatureConfiguration> const configuration = [self.registry createConfigurationForFeatureWithIdentifier:identifier
                                                                                                     rootViewURI:rootViewURI
                                                                                        contentProviderFactories:@[contentProviderFactory]];
    
    [self.registry registerFeatureWithConfiguration:configuration];
    [self.registry unregisterFeatureWithIdentifier:identifier];
    [self.registry registerFeatureWithConfiguration:configuration];
}

@end

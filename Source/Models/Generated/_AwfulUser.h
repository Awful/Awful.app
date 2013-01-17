// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulUser.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulUserAttributes {
	__unsafe_unretained NSString *aboutMe;
	__unsafe_unretained NSString *administrator;
	__unsafe_unretained NSString *aimName;
	__unsafe_unretained NSString *avatarURL;
	__unsafe_unretained NSString *customTitle;
	__unsafe_unretained NSString *gender;
	__unsafe_unretained NSString *homepageURL;
	__unsafe_unretained NSString *icqName;
	__unsafe_unretained NSString *interests;
	__unsafe_unretained NSString *lastPost;
	__unsafe_unretained NSString *location;
	__unsafe_unretained NSString *moderator;
	__unsafe_unretained NSString *occupation;
	__unsafe_unretained NSString *postCount;
	__unsafe_unretained NSString *postRate;
	__unsafe_unretained NSString *profilePictureURL;
	__unsafe_unretained NSString *regdate;
	__unsafe_unretained NSString *userID;
	__unsafe_unretained NSString *username;
	__unsafe_unretained NSString *yahooName;
} AwfulUserAttributes;

extern const struct AwfulUserRelationships {
	__unsafe_unretained NSString *posts;
	__unsafe_unretained NSString *privateMessages;
	__unsafe_unretained NSString *threads;
} AwfulUserRelationships;

extern const struct AwfulUserFetchedProperties {
} AwfulUserFetchedProperties;

@class AwfulPost;
@class AwfulPrivateMessage;
@class AwfulThread;






















@interface AwfulUserID : NSManagedObjectID {}
@end

@interface _AwfulUser : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulUserID*)objectID;





@property (nonatomic, strong) NSString* aboutMe;



//- (BOOL)validateAboutMe:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSNumber* administrator;



@property BOOL administratorValue;
- (BOOL)administratorValue;
- (void)setAdministratorValue:(BOOL)value_;

//- (BOOL)validateAdministrator:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* aimName;



//- (BOOL)validateAimName:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* avatarURL;



//- (BOOL)validateAvatarURL:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* customTitle;



//- (BOOL)validateCustomTitle:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* gender;



//- (BOOL)validateGender:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* homepageURL;



//- (BOOL)validateHomepageURL:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* icqName;



//- (BOOL)validateIcqName:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* interests;



//- (BOOL)validateInterests:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSDate* lastPost;



//- (BOOL)validateLastPost:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* location;



//- (BOOL)validateLocation:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSNumber* moderator;



@property BOOL moderatorValue;
- (BOOL)moderatorValue;
- (void)setModeratorValue:(BOOL)value_;

//- (BOOL)validateModerator:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* occupation;



//- (BOOL)validateOccupation:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSNumber* postCount;



@property int32_t postCountValue;
- (int32_t)postCountValue;
- (void)setPostCountValue:(int32_t)value_;

//- (BOOL)validatePostCount:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* postRate;



//- (BOOL)validatePostRate:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* profilePictureURL;



//- (BOOL)validateProfilePictureURL:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSDate* regdate;



//- (BOOL)validateRegdate:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* userID;



//- (BOOL)validateUserID:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* username;



//- (BOOL)validateUsername:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* yahooName;



//- (BOOL)validateYahooName:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSSet *posts;

- (NSMutableSet*)postsSet;




@property (nonatomic, strong) NSSet *privateMessages;

- (NSMutableSet*)privateMessagesSet;




@property (nonatomic, strong) NSSet *threads;

- (NSMutableSet*)threadsSet;





@end

@interface _AwfulUser (CoreDataGeneratedAccessors)

- (void)addPosts:(NSSet*)value_;
- (void)removePosts:(NSSet*)value_;
- (void)addPostsObject:(AwfulPost*)value_;
- (void)removePostsObject:(AwfulPost*)value_;

- (void)addPrivateMessages:(NSSet*)value_;
- (void)removePrivateMessages:(NSSet*)value_;
- (void)addPrivateMessagesObject:(AwfulPrivateMessage*)value_;
- (void)removePrivateMessagesObject:(AwfulPrivateMessage*)value_;

- (void)addThreads:(NSSet*)value_;
- (void)removeThreads:(NSSet*)value_;
- (void)addThreadsObject:(AwfulThread*)value_;
- (void)removeThreadsObject:(AwfulThread*)value_;

@end

@interface _AwfulUser (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveAboutMe;
- (void)setPrimitiveAboutMe:(NSString*)value;




- (NSNumber*)primitiveAdministrator;
- (void)setPrimitiveAdministrator:(NSNumber*)value;

- (BOOL)primitiveAdministratorValue;
- (void)setPrimitiveAdministratorValue:(BOOL)value_;




- (NSString*)primitiveAimName;
- (void)setPrimitiveAimName:(NSString*)value;




- (NSString*)primitiveAvatarURL;
- (void)setPrimitiveAvatarURL:(NSString*)value;




- (NSString*)primitiveCustomTitle;
- (void)setPrimitiveCustomTitle:(NSString*)value;




- (NSString*)primitiveGender;
- (void)setPrimitiveGender:(NSString*)value;




- (NSString*)primitiveHomepageURL;
- (void)setPrimitiveHomepageURL:(NSString*)value;




- (NSString*)primitiveIcqName;
- (void)setPrimitiveIcqName:(NSString*)value;




- (NSString*)primitiveInterests;
- (void)setPrimitiveInterests:(NSString*)value;




- (NSDate*)primitiveLastPost;
- (void)setPrimitiveLastPost:(NSDate*)value;




- (NSString*)primitiveLocation;
- (void)setPrimitiveLocation:(NSString*)value;




- (NSNumber*)primitiveModerator;
- (void)setPrimitiveModerator:(NSNumber*)value;

- (BOOL)primitiveModeratorValue;
- (void)setPrimitiveModeratorValue:(BOOL)value_;




- (NSString*)primitiveOccupation;
- (void)setPrimitiveOccupation:(NSString*)value;




- (NSNumber*)primitivePostCount;
- (void)setPrimitivePostCount:(NSNumber*)value;

- (int32_t)primitivePostCountValue;
- (void)setPrimitivePostCountValue:(int32_t)value_;




- (NSString*)primitivePostRate;
- (void)setPrimitivePostRate:(NSString*)value;




- (NSString*)primitiveProfilePictureURL;
- (void)setPrimitiveProfilePictureURL:(NSString*)value;




- (NSDate*)primitiveRegdate;
- (void)setPrimitiveRegdate:(NSDate*)value;




- (NSString*)primitiveUserID;
- (void)setPrimitiveUserID:(NSString*)value;




- (NSString*)primitiveUsername;
- (void)setPrimitiveUsername:(NSString*)value;




- (NSString*)primitiveYahooName;
- (void)setPrimitiveYahooName:(NSString*)value;





- (NSMutableSet*)primitivePosts;
- (void)setPrimitivePosts:(NSMutableSet*)value;



- (NSMutableSet*)primitivePrivateMessages;
- (void)setPrimitivePrivateMessages:(NSMutableSet*)value;



- (NSMutableSet*)primitiveThreads;
- (void)setPrimitiveThreads:(NSMutableSet*)value;


@end

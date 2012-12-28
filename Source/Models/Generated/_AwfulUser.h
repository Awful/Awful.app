// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulUser.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulUserAttributes {
	__unsafe_unretained NSString *administrator;
	__unsafe_unretained NSString *avatarURL;
	__unsafe_unretained NSString *customTitle;
	__unsafe_unretained NSString *moderator;
	__unsafe_unretained NSString *regdate;
	__unsafe_unretained NSString *userID;
	__unsafe_unretained NSString *username;
} AwfulUserAttributes;

extern const struct AwfulUserRelationships {
	__unsafe_unretained NSString *posts;
	__unsafe_unretained NSString *threads;
} AwfulUserRelationships;

extern const struct AwfulUserFetchedProperties {
} AwfulUserFetchedProperties;

@class AwfulPost;
@class AwfulThread;









@interface AwfulUserID : NSManagedObjectID {}
@end

@interface _AwfulUser : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulUserID*)objectID;





@property (nonatomic, strong) NSNumber* administrator;



@property BOOL administratorValue;
- (BOOL)administratorValue;
- (void)setAdministratorValue:(BOOL)value_;

//- (BOOL)validateAdministrator:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* avatarURL;



//- (BOOL)validateAvatarURL:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* customTitle;



//- (BOOL)validateCustomTitle:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSNumber* moderator;



@property BOOL moderatorValue;
- (BOOL)moderatorValue;
- (void)setModeratorValue:(BOOL)value_;

//- (BOOL)validateModerator:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSDate* regdate;



//- (BOOL)validateRegdate:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* userID;



//- (BOOL)validateUserID:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* username;



//- (BOOL)validateUsername:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSSet *posts;

- (NSMutableSet*)postsSet;




@property (nonatomic, strong) NSSet *threads;

- (NSMutableSet*)threadsSet;





@end

@interface _AwfulUser (CoreDataGeneratedAccessors)

- (void)addPosts:(NSSet*)value_;
- (void)removePosts:(NSSet*)value_;
- (void)addPostsObject:(AwfulPost*)value_;
- (void)removePostsObject:(AwfulPost*)value_;

- (void)addThreads:(NSSet*)value_;
- (void)removeThreads:(NSSet*)value_;
- (void)addThreadsObject:(AwfulThread*)value_;
- (void)removeThreadsObject:(AwfulThread*)value_;

@end

@interface _AwfulUser (CoreDataGeneratedPrimitiveAccessors)


- (NSNumber*)primitiveAdministrator;
- (void)setPrimitiveAdministrator:(NSNumber*)value;

- (BOOL)primitiveAdministratorValue;
- (void)setPrimitiveAdministratorValue:(BOOL)value_;




- (NSString*)primitiveAvatarURL;
- (void)setPrimitiveAvatarURL:(NSString*)value;




- (NSString*)primitiveCustomTitle;
- (void)setPrimitiveCustomTitle:(NSString*)value;




- (NSNumber*)primitiveModerator;
- (void)setPrimitiveModerator:(NSNumber*)value;

- (BOOL)primitiveModeratorValue;
- (void)setPrimitiveModeratorValue:(BOOL)value_;




- (NSDate*)primitiveRegdate;
- (void)setPrimitiveRegdate:(NSDate*)value;




- (NSString*)primitiveUserID;
- (void)setPrimitiveUserID:(NSString*)value;




- (NSString*)primitiveUsername;
- (void)setPrimitiveUsername:(NSString*)value;





- (NSMutableSet*)primitivePosts;
- (void)setPrimitivePosts:(NSMutableSet*)value;



- (NSMutableSet*)primitiveThreads;
- (void)setPrimitiveThreads:(NSMutableSet*)value;


@end

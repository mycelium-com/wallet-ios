#import <FMDB/FMDatabase.h>
#import <FMDB/FMDatabaseAdditions.h>

/**
 * This notification is posted after -[MYCDatabase inDatabase:] and
 * -[MYCDatabase inTransaction:], if the invocation of any of those methods
 * actually changes the database:
 *
 *   -[MYCDatabaseRecord updateInDatabase:]
 *   -[MYCDatabaseRecord insertInDatabase:]
 *   -[MYCDatabaseRecord saveInDatabase:]
 *   -[MYCDatabaseRecord deleteFromDatabase:]
 *   +[MYCDatabaseRecord deleteAllFromDatabase:]
 *
 * It is posted in the same thread as the invocation of
 * -[MYCDatabase inDatabase:] and -[MYCDatabase inTransaction:].
 *
 * The key PChangedModelTableNamesKey of userInfo is set to the NSSet of
 * changed table names.
 *
 * Objects who change the database by some other mean should call
 * -[MYCDatabase tableDidChange:] after their update/insert/delete, whenever
 * -[FMDatabase changes] is not zero:
 *
 *     if ([db executeUpdate:@"UPDATE <table> ..."]) {
 *         if (db.changes > 0) {
 *             [MYCDatabase tableDidChange:@"<table>"];
 *         }
 *     }
 */
extern NSString* const MYCDatabaseDidChangeNotification;
extern NSString* const PChangedModelTableNamesKey;   // NSSet of the names of changed tables

@interface MYCDatabase : NSObject

@property (nonatomic, readonly) NSURL *URL;

+ (void)setSharedModelDatabase:(MYCDatabase *)sharedModelDatabase;
+ (instancetype)sharedModelDatabase;

// 1. Create database
- (id)initWithURL:(NSURL *)URL;

// 2. Register migrations
// If You return NO from the block, you can set outError, or leave it nil. In this case, db.lastError is assumed.
- (void)registerMigration:(NSString *)name withBlock:(BOOL(^)(FMDatabase *db, NSError **outError))block;

// 3. Open
- (BOOL)open:(NSError **)error;   // This method may take some time: it opens underlying FMDatabase, and applies registered migrations.

// 4. Access database
- (void)inDatabase:(void(^)(FMDatabase *db))block;
- (void)inTransaction:(void(^)(FMDatabase *db, BOOL *rollback))block;

// 5. Close
- (void)close;

// Support for MYCDatabaseDidChangeNotification
// This method MUST be called in a inDatabase or inTransaction block.
// It should be called if and only if -[FMDatabase changes] is not zero.
+ (void)tableDidChange:(NSString *)tableName;
@end



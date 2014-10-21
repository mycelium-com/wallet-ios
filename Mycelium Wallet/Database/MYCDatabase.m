#import <FMDB/FMDatabaseQueue.h>
#import "MYCDatabase.h"

#ifdef MYCDatabase_DEBUG
#warning DEBUG: Verbose MYCDatabase
#endif


// =============================================================================
#pragma mark - MYCDatabaseMigrator

@interface MYCDatabaseMigrator : NSObject
- (id)initWithDatabaseQueue:(FMDatabaseQueue*)databaseQueue;
- (void)registerMigration:(NSString*)name withBlock:(BOOL (^)(FMDatabase *db, NSError **outError))aBlock;
- (BOOL)migrateDatabase:(MYCDatabase*)db error:(NSError **)outError;
@end


// =============================================================================
#pragma mark - MYCDatabase

NSString* const MYCDatabaseDidChangeNotification = @"MYCDatabaseDidChangeNotification";
NSString* const PChangedModelTableNamesKey = @"PChangedModelTableNames";

static NSMutableSet *MYCDatabaseChangedTableNames;

@interface MYCDatabase()
@property(nonatomic) NSURL *URL;
@property(nonatomic) FMDatabaseQueue *dbQueue;
@property(nonatomic) MYCDatabaseMigrator *migrator;
@property(nonatomic) NSMutableSet *changedTableNames;
@end

@implementation MYCDatabase


// =============================================================================
#pragma mark - Shared Model Database

static MYCDatabase *sharedModelDatabase;

+ (instancetype)sharedModelDatabase
{
    @synchronized(self) {
        return sharedModelDatabase;
    }
}

+ (void)setSharedModelDatabase:(MYCDatabase *)modelDatabase
{
    @synchronized(self) {
        sharedModelDatabase = modelDatabase;
    }
}


// =============================================================================
#pragma mark - Database initialization & configuration

- (id)initWithURL:(NSURL *)URL
{
    NSAssert(URL, @"Missing databaseURL");
    self = [super init];
    if (self)
    {
        self.URL = URL;
        self.dbQueue = [FMDatabaseQueue databaseQueueWithPath:[self.URL absoluteString]];
        self.migrator = [[MYCDatabaseMigrator alloc] initWithDatabaseQueue:self.dbQueue];
    }
    return self;
}

- (void)registerMigration:(NSString *)name withBlock:(BOOL(^)(FMDatabase *db, NSError **outError))block
{
    [self.migrator registerMigration:name withBlock:block];
}


// =============================================================================
#pragma mark - FMDatabase

- (BOOL)open:(NSError **)outError
{
    // enable foreign keys
    __block BOOL success;
    __block NSError *databaseError;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        success = [db executeUpdate:@"PRAGMA foreign_keys = ON;"];
        if (!success) {
            databaseError = db.lastError;
        }
    }];
    if (!success) {
        if (outError)
            *outError = databaseError;
        return NO;
    }
    
    // migrate
    if (![self.migrator migrateDatabase:self error:outError]) {
        return NO;
    }
    
    return YES;
}

- (void)close
{
    [_dbQueue inDatabase:^(FMDatabase *db) {
        [db close];
    }];
}

- (void)inDatabase:(void (^)(FMDatabase *db))block
{
    __block NSSet *changedTableNames = nil;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        
#ifdef MYCDatabase_DEBUG
        // Debug configuration: verbose database
        db.traceExecution = YES;
#endif
        
        // Setup changed table names
        MYCDatabaseChangedTableNames = [NSMutableSet set];
        
        block(db);
        changedTableNames = [MYCDatabaseChangedTableNames copy];
        
        // clean up changed table names
        MYCDatabaseChangedTableNames = nil;
    }];
    
    if (changedTableNames.count > 0) {
#ifdef MYCDatabase_DEBUG
        MYCLog(@"MYCDatabaseDidChangeNotification: %@", changedTableNames);
#endif
        [[NSNotificationCenter defaultCenter] postNotificationName:MYCDatabaseDidChangeNotification object:self userInfo:@{ PChangedModelTableNamesKey: changedTableNames }];
    }
}

- (void)inTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block
{
    __block NSSet *changedTableNames = nil;
    [_dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
#ifdef MYCDatabase_DEBUG
        // Debug configuration: verbose database
        db.traceExecution = YES;
#endif
        
        // Setup changed table names
        MYCDatabaseChangedTableNames = [NSMutableSet set];
        
        block(db, rollback);
        if (*rollback == NO) {
            changedTableNames = [MYCDatabaseChangedTableNames copy];
        }
        
        // clean up changed table names
        MYCDatabaseChangedTableNames = nil;
    }];
    
    if (changedTableNames.count > 0) {
#ifdef MYCDatabase_DEBUG
        MYCLog(@"MYCDatabaseDidChangeNotification: %@", changedTableNames);
#endif
        [[NSNotificationCenter defaultCenter] postNotificationName:MYCDatabaseDidChangeNotification object:self userInfo:@{ PChangedModelTableNamesKey: changedTableNames }];
    }
}


// =============================================================================
#pragma mark - MYCDatabaseDidChangeNotification

+ (void)tableDidChange:(NSString *)tableName
{
    if (MYCDatabaseChangedTableNames == nil) {
        [NSException raise:NSInternalInconsistencyException format:@"-[%@ %@] must be called inside a inTransaction: or inDatabase: block.", self, NSStringFromSelector(_cmd)];
        return;
    }
    
    [MYCDatabaseChangedTableNames addObject:tableName];
}

@end



// =============================================================================
#pragma mark - MYCDatabaseMigrator


@interface MYCDatabaseMigrator()
@property(nonatomic) FMDatabaseQueue* databaseQueue;
@property(nonatomic) NSMutableArray* migrationNames;
@property(nonatomic) NSMutableDictionary* migrations;
- (void)setupMigratorBackend;
@end

@implementation MYCDatabaseMigrator

- (id)initWithDatabaseQueue:(FMDatabaseQueue*)databaseQueue
{
    self = [super init];
    if (self)
    {
        self.databaseQueue = databaseQueue;
        self.migrationNames = [[NSMutableArray alloc] initWithCapacity:16];
        self.migrations = [[NSMutableDictionary alloc] initWithCapacity:16];
        [self setupMigratorBackend];
    }
    return self;
}

- (void)registerMigration:(NSString*)name withBlock:(BOOL (^)(FMDatabase *db, NSError **outError))aBlock
{
    if ([_migrationNames containsObject:name])
    {
        [[NSException exceptionWithName:@"DuplicateMigration" reason:[NSString stringWithFormat:@"migration '%@' already exists.", name] userInfo:nil] raise];
    }
    else
    {
        [_migrationNames addObject:name];
        _migrations[name] = aBlock;
    }
}

- (BOOL)migrateDatabase:(MYCDatabase*)mycdb error:(NSError **)outError
{
    if (!_migrationNames) {
        // no registered migrations: nothing to do
        return YES;
    }
    
    __block BOOL success = YES;
    __block NSError *databaseError;
    NSMutableArray *appliedMigrations = [[NSMutableArray alloc] initWithCapacity:16];
    [mycdb inDatabase:^(FMDatabase *db) {
        FMResultSet* rs = [db executeQuery:@"SELECT identifier FROM db_migrations ORDER BY position;"];
        if (!rs) {
            databaseError = db.lastError;
            success = NO;
            return;
        }
        while ([rs next])
        {
            [appliedMigrations addObject:[rs stringForColumnIndex:0]];
        }
    }];
    if (!success) {
        if (outError) {
            *outError = databaseError;
        }
        return NO;
    }
    
    NSMutableOrderedSet* migrationNamesToApply = [[NSMutableOrderedSet alloc] initWithCapacity:[_migrationNames count]];
    [migrationNamesToApply addObjectsFromArray:_migrationNames];
    [migrationNamesToApply removeObjectsInArray:appliedMigrations];
    
    if (migrationNamesToApply.count == 0) {
        // all migrations are applied: nothing to do
        return YES;
    }
    
    __block NSInteger migrationNumber = [appliedMigrations count];
    
    for (NSString* migrationName in migrationNamesToApply)
    {
        [mycdb inTransaction:^(FMDatabase *db, BOOL *rollback) {
#ifdef MYCDatabase_DEBUG
            // Debug configuration: verbose database
            db.traceExecution = YES;
#endif
            
            BOOL (^migrationBlock)(FMDatabase *db, NSError **outError) = [_migrations objectForKey:migrationName];
            success = (migrationBlock != nil);
            if (!success)
            {
                *rollback = YES;
                databaseError = [NSError errorWithDomain:NSStringFromClass([self class]) code:2 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"no block registered for migration %@", migrationName]}];
                return;
            }
            
            databaseError = nil;
            success = migrationBlock(db, &databaseError);
            if (!success) {
                *rollback = YES;
                if (!databaseError) {
                    databaseError = db.lastError;
                }
                return;
            }
            
            success = [db executeUpdate:@"INSERT INTO db_migrations (identifier, position) VALUES (?, ?);" withArgumentsInArray:@[migrationName, @(++migrationNumber)]];
            if (!success) {
                *rollback = YES;
                databaseError = db.lastError;
                return;
            }
        }];
        
        if (!success)
        {
            if (outError) {
                *outError = databaseError;
            }
            return NO;
        }
    }
    
    return YES;
}

- (void)setupMigratorBackend
{
    [_databaseQueue inDatabase:^(FMDatabase *db) {
        if ([db tableExists:@"db_migrations"] == NO)
        {
            [db executeUpdate:@"CREATE TABLE db_migrations ("
             "identifier VARCHAR(128) PRIMARY KEY NOT NULL,"
             "position INT);"];
        }
    }];
}

@end

#import <FMDB/FMDatabase.h>
#import "MYCDatabaseRecord.h"
#import "MYCDatabase.h"

NSString* const MYCDatabaseRecordErrorDomain = @"MYCDatabaseRecordErrorDomain";
NSString* const MYCDatabaseRecordColumnKey = @"MYCDatabaseRecordColumn";

static NSString * const MYCDatabaseRecordMethodKey = @"MYCDatabaseRecordMethod";


// =============================================================================
#pragma mark - MYCDatabaseRecord

@interface MYCDatabaseRecord()
@property (nonatomic) MYCDatabase *modelDatabase;
@end


@implementation MYCDatabaseRecord {
    BOOL _existingRecord;
}

+ (NSString*)tableName
{
    return nil;
}

+ (id) primaryKeyName
{
    return @"id";
}

+ (NSArray*) internalPrimaryKeyNames
{
    id pk = [self primaryKeyName];
    if (!pk) return nil;
    if ([pk isKindOfClass:[NSString class]])
    {
        return @[ pk ];
    }
    return pk;
}

+ (NSArray*)columnNames
{
    return nil;
}

- (instancetype)initWithDictionary:(NSDictionary*)dict
{
    self = [super init];
    if (self) {
        [self updateFromDictionary:dict];
    }
    return self;
}

- (BOOL) isNewRecord
{
    return !_existingRecord;
}

- (void) didLoadFromDatabase:(FMDatabase*)db
{
}

- (NSString*)description
{
    NSMutableString* d = [NSMutableString stringWithFormat:@"<%@ ", NSStringFromClass([self class])];
    
    for (NSString* col in [[self class] columnNames])
    {
        id val = [self valueForKey:col];
        if (val)
        {
            [d appendFormat:@"%@=%@; ", col, val];
        }
    }
    [d appendFormat:@"%p>", self];
    return d;
}

- (void)updateFromDictionary:(NSDictionary*)dict
{
    NSNull *nullObj = [NSNull null];
    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString* setterName = [NSString stringWithFormat:@"set%@%@:", [[key substringToIndex:1] uppercaseString], [key substringFromIndex:1]];
        if ([self respondsToSelector:NSSelectorFromString(setterName)])
        {
            [self setValue:(obj == nullObj ? nil : obj) forKey:key];
        }
#if !defined(NS_BLOCK_ASSERTIONS)
        else
        {
            MYCLog(@"[%@ %@] Ignore unknown key %@", [self class], NSStringFromSelector(_cmd), key);
        }
#endif
    }];
}

- (id)copyWithZone:(NSZone *)zone
{
    MYCDatabaseRecord* res = [[self class] allocWithZone:zone];
    NSDictionary* kv = [self dictionaryWithValuesForKeys:[[self class] columnNames]];
    [res updateFromDictionary:kv];
    return res;
}

+ (NSString*) conditionForPrimaryKey:(NSArray*)pkNames
{
    NSMutableArray* arr = [NSMutableArray array];
    for (NSString* pk in pkNames)
    {
        [arr addObject:[NSString stringWithFormat:@"%@ = :%@", pk, pk]];
    }
    return [arr componentsJoinedByString:@" AND "];
}

- (NSString*) conditionForPrimaryKey:(NSArray*)pkNames
{
    return [[self class] conditionForPrimaryKey:pkNames];
}

- (NSString*) setterForPrimaryKey:(NSArray*)pkNames
{
    NSMutableArray* arr = [NSMutableArray array];
    for (NSString* pk in pkNames)
    {
        [arr addObject:[NSString stringWithFormat:@"%@ = :%@", pk, pk]];
    }
    return [arr componentsJoinedByString:@", "];
}

- (NSArray*) valuesForPrimaryKey:(NSArray*)pkNames
{
    NSMutableArray* arr = [NSMutableArray array];
    for (NSString* pk in pkNames)
    {
        id val = [self valueForKey:pk];
        if (!val)
        {
            [NSException raise:NSInternalInconsistencyException format:@"Primary key %@ is not set", pk];
            return nil;
        }
        [arr addObject:val];
    }
    return arr;
}

- (NSDictionary*) valuesDictionaryForPrimaryKey:(NSArray*)pkNames
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    for (NSString* pk in pkNames)
    {
        id val = [self valueForKey:pk];
        if (!val)
        {
            [NSException raise:NSInternalInconsistencyException format:@"Primary key %@ is not set", pk];
            return nil;
        }
        dict[pk] = val;
    }
    return dict;
}



+ (BOOL)deleteAllFromDatabase:(FMDatabase *)db error:(NSError **)outError
{
    NSString* tableName = [[self class] tableName];
    if (!tableName) {
        [NSException raise:NSInvalidArgumentException format:@"Missing tableName for class %@", [self class]];
    }
    
    if ([db executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@", tableName]])
    {
        if (db.changes > 0) {
            [MYCDatabase tableDidChange:tableName];
        }
        return YES;
    }
    else
    {
        if (outError) {
            NSError *error = db.lastError;
            NSMutableDictionary *userInfo = [error.userInfo mutableCopy] ?: [NSMutableDictionary dictionary];
            userInfo[MYCDatabaseRecordMethodKey] = [NSString stringWithFormat:@"+[%@ %@]", self, NSStringFromSelector(_cmd)];
            *outError = [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
        }
        return NO;
    }

}

- (BOOL)deleteFromDatabase:(FMDatabase *)db error:(NSError **)outError
{
    NSString* tableName = [[self class] tableName];
    NSArray* primaryKey = [[self class] internalPrimaryKeyNames];
    
    if (!tableName) {
        [NSException raise:NSInvalidArgumentException format:@"Missing tableName for class %@", [self class]];
    }
    if (!primaryKey) {
        [NSException raise:NSInvalidArgumentException format:@"Missing primaryKeyName for class %@", [self class]];
    }

    if ([db executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@ WHERE %@", tableName, [self conditionForPrimaryKey:primaryKey]]
                withParameterDictionary:[self valuesDictionaryForPrimaryKey:primaryKey]])
    {
        if (db.changes > 0) {
            [MYCDatabase tableDidChange:tableName];
        }
        return YES;
    }
    else
    {
        if (outError) {
            NSError *error = db.lastError;
            NSMutableDictionary *userInfo = [error.userInfo mutableCopy] ?: [NSMutableDictionary dictionary];
            userInfo[MYCDatabaseRecordMethodKey] = [NSString stringWithFormat:@"-[%@ %@]", [self class], NSStringFromSelector(_cmd)];
            *outError = [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
        }
        return NO;
    }
}

- (BOOL)insertInDatabase:(FMDatabase *)db error:(NSError **)outError
{
    if (![self validateForInsert:outError])
    {
        return NO;
    }
    
    NSString* tableName = [[self class] tableName];
    if (!tableName) {
        [NSException raise:NSInvalidArgumentException format:@"Missing tableName for class %@", [self class]];
    }
    
    NSArray* columnNames = [[self class] columnNames];
    if (columnNames.count == 0) {
        // nothing to do
        return YES;
    }
    
    NSMutableArray* prefixedColumnNames = [NSMutableArray arrayWithCapacity:[columnNames count]];
    
    for (NSString* column in columnNames)
        [prefixedColumnNames addObject:[@":" stringByAppendingString:column]];
    
    NSDictionary* row = [self dictionaryWithValuesForKeys:columnNames];
    
    NSString* statement = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)", tableName, [columnNames componentsJoinedByString:@", "], [prefixedColumnNames componentsJoinedByString:@", "]];
    
    if ([db executeUpdate:statement withParameterDictionary:row])
    {
        if (db.changes > 0) {
            [MYCDatabase tableDidChange:tableName];
        }
        _existingRecord = YES;
        return YES;
    }
    else
    {
        if (outError) {
            NSError *error = db.lastError;
            NSMutableDictionary *userInfo = [error.userInfo mutableCopy] ?: [NSMutableDictionary dictionary];
            userInfo[MYCDatabaseRecordMethodKey] = [NSString stringWithFormat:@"-[%@ %@]", [self class], NSStringFromSelector(_cmd)];
            *outError = [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
        }
        return NO;
    }
}

- (BOOL)updateInDatabase:(FMDatabase *)db error:(NSError **)outError
{
    if (![self validateForUpdate:outError])
    {
        return NO;
    }
    
    NSString* tableName = [[self class] tableName];
    NSArray* primaryKey = [[self class] internalPrimaryKeyNames];

    if (!tableName) {
        [NSException raise:NSInvalidArgumentException format:@"Missing tableName for class %@", [self class]];
    }
    if (!primaryKey) {
        [NSException raise:NSInvalidArgumentException format:@"Missing primaryKeyName for class %@", [self class]];
    }
    
    NSArray* columnNames = [[self class] columnNames];
    if (columnNames.count == 0) {
        // nothing to do
        return YES;
    }
    
    NSDictionary* row = [self dictionaryWithValuesForKeys:columnNames];

    // record exists, build update statement.
    NSMutableString* updateStatement = [NSMutableString stringWithCapacity:256];
    for (NSString* key in columnNames)
    {
        if (![primaryKey containsObject:key])
            [updateStatement appendFormat:@"%@ = :%@, ", key, key];
    }
    if (updateStatement.length == 0) {
        // There is nothing to update: the only column in the primary key.
        return YES;
    }
    [updateStatement deleteCharactersInRange:NSMakeRange(updateStatement.length - 2, 2)];
    
    if ([db executeUpdate:[NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@", tableName, updateStatement, [self conditionForPrimaryKey:primaryKey]] withParameterDictionary:row])
    {
        if (db.changes > 0) {
            [MYCDatabase tableDidChange:tableName];
        }
        _existingRecord = YES;
        return YES;
    }
    else
    {
        if (outError) {
            NSError *error = db.lastError;
            NSMutableDictionary *userInfo = [error.userInfo mutableCopy] ?: [NSMutableDictionary dictionary];
            userInfo[MYCDatabaseRecordMethodKey] = [NSString stringWithFormat:@"-[%@ %@]", [self class], NSStringFromSelector(_cmd)];
            *outError = [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
        }
        return NO;
    }
}

- (BOOL)saveInDatabase:(FMDatabase *)db error:(NSError **)outError
{
    NSString* tableName = [[self class] tableName];
    NSArray* primaryKey = [[self class] internalPrimaryKeyNames];
    
    if (!tableName) {
        [NSException raise:NSInvalidArgumentException format:@"Missing tableName for class %@", [self class]];
    }
    if (!primaryKey) {
        [NSException raise:NSInvalidArgumentException format:@"Missing primaryKeyName for class %@", [self class]];
    }

    // search if we have an existing record
    if (_existingRecord)
    {
        FMResultSet* rs = [db executeQuery:[NSString stringWithFormat:@"SELECT 1 FROM %@ WHERE %@", tableName, [self conditionForPrimaryKey:primaryKey]]
                   withParameterDictionary:[self valuesDictionaryForPrimaryKey:primaryKey]];
        if (!rs) {
            if (outError) {
                *outError = db.lastError;
            }
            return NO;
        }
        if ([rs next])
        {
            [rs close]; // close unexhausted result set and avoid FMDB warning
            return [self updateInDatabase:db error:outError];
        }
    }

    if ([self insertInDatabase:db error:outError])
    {
        _existingRecord = YES;
        return YES;
    }
    return NO;
}

//+ (NSDictionary *)loadWithPrimaryKeys:(NSSet *)primaryKeys fromDatabase:(FMDatabase *)db
//{
//    NSString* tableName = [[self class] tableName];
//    NSArray* primaryKey = [[self class] internalPrimaryKeyNames];
//    
//    if (!tableName) {
//        [NSException raise:NSInvalidArgumentException format:@"Missing tableName for class %@", [self class]];
//    }
//    if (!primaryKey) {
//        [NSException raise:NSInvalidArgumentException format:@"Missing primaryKeyName for class %@", [self class]];
//    }
//    
//    NSMutableDictionary* res = [NSMutableDictionary dictionaryWithCapacity:256];
//    NSMutableArray* conditionsArray = [NSMutableArray array];
//    if ([primaryKeys count] > 0)
//    {
//        NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ in (?)", tableName, primaryKey];
//        FMResultSet* rs = [db executeQuery:query withArgumentsInArray:@[[primaryKeys allObjects]]];
//        if (!rs) {
//            [NSException raise:NSInternalInconsistencyException format:@"Unexpected database error: %@", db.lastError];
//        }
//        while ([rs next]) {
//            MYCDatabaseRecord* mo = [[self alloc] init];
//            [mo updateFromDictionary:rs.resultDictionary];
//            id primaryKeyValue = [mo valueForKey:primaryKey];
//            res[primaryKeyValue] = mo;
//        }
//    }
//    return res;
//}


// Array of dictionaries with given attributes
+ (NSArray*) loadAttributes:(NSArray*)attrs condition:(NSString*)condition fromDatabase:(FMDatabase*)db
{
    return [self loadAttributes:attrs condition:condition params:nil fromDatabase:db];
}

+ (NSArray*) loadAttributes:(NSArray*)attrs condition:(NSString*)condition params:(id)params fromDatabase:(FMDatabase*)db
{
    NSString* tableName = [self tableName];
    if (tableName)
    {
        NSMutableArray* results = [NSMutableArray array];

        NSString* query = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@",
                           [(attrs ?: @[@"*"]) componentsJoinedByString:@", "],
                           tableName,
                           condition ?: @"1"];

        FMResultSet* fmrs = nil;

        if (!params) params = @[];

        if ([params isKindOfClass:[NSArray class]])
        {
            fmrs = [db executeQuery:query withArgumentsInArray:params];
        }
        else if ([params isKindOfClass:[NSDictionary class]])
        {
            fmrs = [db executeQuery:query withParameterDictionary:params];
        }
        else
        {
            [[NSException exceptionWithName:NSInvalidArgumentException reason:@"params must be dictionary or array" userInfo:nil] raise];
        }
        while ([fmrs next])
        {
            [results addObject:fmrs.resultDictionary];
        }
        [fmrs close];
        return results;
    }
    return nil;
}

// Array of objects for a given column
+ (NSArray*) loadValuesForKey:(NSString*)attr condition:(NSString*)condition fromDatabase:(FMDatabase*)db
{
    return [self loadValuesForKey:attr condition:condition params:nil fromDatabase:db];
}

+ (NSArray*) loadValuesForKey:(NSString*)attr condition:(NSString*)condition params:(id)params fromDatabase:(FMDatabase*)db
{
    if (!attr) return @[];
    return [[self loadAttributes:@[attr] condition:condition params:params fromDatabase:db] valueForKey:attr];
}



+ (NSArray*)loadAllFromDatabase:(FMDatabase*)db
{
    return [self loadWithCondition:nil params:nil fromDatabase:db];
}

+ (NSArray*)loadWithCondition:(NSString*)condition fromDatabase:(FMDatabase*)db
{
    return [self loadWithCondition:condition params:nil fromDatabase:db];
}

+ (NSArray*)loadWithCondition:(NSString*)condition params:(id)params fromDatabase:(FMDatabase*)db
{
    NSString* tableName = [self tableName];

    if (tableName)
    {
        if (!condition) condition = @"1";

        NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@", tableName, condition];

        FMResultSet* fmrs = nil;

        if (!params) params = @[];

        if ([params isKindOfClass:[NSArray class]])
        {
            fmrs = [db executeQuery:query withArgumentsInArray:params];
        }
        else if ([params isKindOfClass:[NSDictionary class]])
        {
            fmrs = [db executeQuery:query withParameterDictionary:params];
        }
        else
        {
            [[NSException exceptionWithName:NSInvalidArgumentException reason:@"params must be dictionary or array" userInfo:nil] raise];
        }

        if (fmrs)
        {
            NSMutableArray* results = [NSMutableArray array];
            while ([fmrs next])
            {
                MYCDatabaseRecord* record = [[self alloc] init];
                record->_existingRecord = YES;
                [record updateFromDictionary:fmrs.resultDictionary];
                [record didLoadFromDatabase:db];
                [results addObject:record];
            }
            [fmrs close];
            return results;
        }
    }
    return nil;
}



- (BOOL)reloadFromDatabase:(FMDatabase *)db
{
    NSString* tableName = [[self class] tableName];
    NSString* primaryKeyName = [[self class] primaryKeyName];
    
    if (!tableName) {
        [NSException raise:NSInvalidArgumentException format:@"Missing tableName for class %@", [self class]];
    }
    if (!primaryKeyName) {
        [NSException raise:NSInvalidArgumentException format:@"Missing primaryKeyName for class %@", [self class]];
    }
    
    id primaryKeyValue = [self valueForKey:primaryKeyName];
    NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = ?", tableName, primaryKeyName];
    FMResultSet* rs = [db executeQuery:query withArgumentsInArray:@[primaryKeyValue]];
    if (!rs) {
        [NSException raise:NSInternalInconsistencyException format:@"Unexpected database error: %@", db.lastError];
    }
    while ([rs next]) {
        [self updateFromDictionary:rs.resultDictionary];
    }
    
    [rs close]; // close unexhausted result set and avoid FMDB warning
    return YES;
}


+ (instancetype)loadWithPrimaryKey:(id)primaryKeyValue fromDatabase:(FMDatabase *)db
{
    if (!primaryKeyValue) return nil;

    NSString* tableName = [[self class] tableName];
    NSArray* primaryKey = [[self class] internalPrimaryKeyNames];

    if (!tableName) {
        [NSException raise:NSInvalidArgumentException format:@"Missing tableName for class %@", [self class]];
    }
    if (!primaryKey) {
        [NSException raise:NSInvalidArgumentException format:@"Missing primaryKeyName for class %@", [self class]];
    }

    NSArray* primaryKeyValues = primaryKeyValue;
    if ([primaryKeyValues isKindOfClass:[NSString class]])
    {
        primaryKeyValues = @[ primaryKeyValues ];
    }

    if (primaryKeyValues.count != primaryKey.count)
    {
        [NSException raise:NSInvalidArgumentException format:@"Primary key value must have the same number of items as primary key has columns (class %@)", [self class]];
    }

    NSString* query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@", tableName, [self conditionForPrimaryKey:primaryKey]];
    NSMutableDictionary* params = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < primaryKey.count; i++)
    {
        params[primaryKey[i]] = primaryKeyValues[i];
    }
    FMResultSet* rs = [db executeQuery:query withParameterDictionary:params];
    if (!rs) {
        [NSException raise:NSInternalInconsistencyException format:@"Unexpected database error: %@", db.lastError];
    }
    while ([rs next])
    {
        MYCDatabaseRecord* mo = [[self alloc] init];
        [mo updateFromDictionary:rs.resultDictionary];
        [rs close];
        return mo;
    }

    return nil;
}






#pragma mark - Counting



+ (NSUInteger)countAllFromDatabase:(FMDatabase*)db
{
    return [self countWithCondition:nil params:nil fromDatabase:db];
}

+ (NSUInteger)countWithCondition:(NSString*)condition fromDatabase:(FMDatabase*)db
{
    return [self countWithCondition:condition params:nil fromDatabase:db];
}

+ (NSUInteger)countWithCondition:(NSString*)condition params:(id)params fromDatabase:(FMDatabase*)db
{
    NSString* tableName = [self tableName];

    if (tableName)
    {
        if (!condition) condition = @"1";

        NSString* query = [NSString stringWithFormat:@"SELECT COUNT(*) AS c FROM %@ WHERE %@", tableName, condition];

        FMResultSet* fmresults = nil;

        if (!params) params = @[];

        if ([params isKindOfClass:[NSArray class]])
        {
            fmresults = [db executeQuery:query withArgumentsInArray:params];
        }
        else if ([params isKindOfClass:[NSDictionary class]])
        {
            fmresults = [db executeQuery:query withParameterDictionary:params];
        }

        if ([fmresults next])
        {
            NSUInteger res = [fmresults.resultDictionary[@"c"] unsignedIntegerValue];
            [fmresults close];
            return res;
        }
        return 0;
    }
    return 0;
}








#pragma mark - Validation






- (BOOL)validateColumnNames:(NSArray*)columnNames returningError:(NSError **)outError
{
    for (NSString* columnName in columnNames)
    {
        NSError* error = nil;
        id value = [self valueForKey:columnName];
        id previousValue = value;
        BOOL validKey = [self validateValue:&value forKey:columnName error:&error];
        if (validKey)
        {
            if (value != previousValue)
                [self setValue:value forKey:columnName];
        }
        else
        {
            if (outError)
                *outError = error;
            return NO;
        }
    }
    return YES;
}

- (BOOL)validateForInsert:(NSError **)outError
{
    NSMutableArray* columnNamesToValidate = [[NSMutableArray alloc] initWithArray:[[self class] columnNames]];
    NSString* pk = [[self class] primaryKeyName];
    if (pk) [columnNamesToValidate removeObject:pk];
    return [self validateColumnNames:[[self class] columnNames] returningError:outError];
}

- (BOOL)validateForUpdate:(NSError **)outError
{
    return [self validateColumnNames:[[self class] columnNames] returningError:outError];
}

+ (NSError*)validationErrorForColumn:(NSString*)column withMessage:(NSString*)message
{
    return [NSError errorWithDomain:MYCDatabaseRecordErrorDomain code:MYCDatabaseRecordValidationErrorCode userInfo:@{NSLocalizedDescriptionKey:message, MYCDatabaseRecordColumnKey:column}];
}



#pragma mark - NSObject



- (BOOL)isEqual:(id)object
{
    if (object == self) return YES;

    NSArray* pks = [[self class] internalPrimaryKeyNames];

    if (pks.count == 0) return NO;

    // If class B is a subclass of class A,
    // [a isEqual:b] must return the same result as [b isEqual:a]
    if ([object isKindOfClass:[self class]] || [self isKindOfClass:[object class]])
    {
        for (id pk in pks)
        {
            id a = [self valueForKey:pk];
            id b = [object valueForKey:pk];
            if (![a isEqual:b]) return NO;
        }
        return YES;
    }
    return NO;
}

- (NSUInteger)hash
{
    NSString* primaryKeyName = [[self class] primaryKeyName];
    if (primaryKeyName)
    {
        return [[self valueForKey:primaryKeyName] hash];
    }
    return [super hash];
}



@end

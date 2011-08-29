#import "XMPPRosterCoreDataStorage.h"
#import "XMPPGroupCoreDataStorageObject.h"
#import "XMPPUserCoreDataStorageObject.h"
#import "XMPPResourceCoreDataStorageObject.h"
#import "XMPPRosterPrivate.h"
#import "XMPPCoreDataStorageProtected.h"
#import "XMPP.h"
#import "XMPPLogging.h"
#import "NSNumber+XMPP.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_INFO | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

#define AssertPrivateQueue() \
        NSAssert(dispatch_get_current_queue() == storageQueue, @"Private method: MUST run on storageQueue");


@implementation XMPPRosterCoreDataStorage

static XMPPRosterCoreDataStorage *sharedInstance;

+ (XMPPRosterCoreDataStorage *)sharedInstance
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		sharedInstance = [[XMPPRosterCoreDataStorage alloc] initWithDatabaseFilename:nil];
	});
	
	return sharedInstance;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)init
{
	return [self initWithDatabaseFilename:nil];
}

- (id)initWithDatabaseFilename:(NSString *)aDatabaseFileName
{
	if ((self = [super initWithDatabaseFilename:aDatabaseFileName]))
	{
		rosterPopulationSet = [[NSMutableSet alloc] init];
	}
	return self;
}

- (BOOL)configureWithParent:(XMPPRoster *)aParent queue:(dispatch_queue_t)queue
{
	return [super configureWithParent:aParent queue:queue];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPUserCoreDataStorageObject *)_userForJID:(XMPPJID *)jid
                                    xmppStream:(XMPPStream *)stream
                          managedObjectContext:(NSManagedObjectContext *)moc
{
	XMPPLogTrace();
	AssertPrivateQueue();
	
	if (jid == nil) return nil;
	
	NSString *bareJIDStr = [jid bare];
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorageObject"
	                                          inManagedObjectContext:moc];
	
	NSPredicate *predicate;
	if (stream == nil)
		predicate = [NSPredicate predicateWithFormat:@"jidStr == %@", bareJIDStr];
	else
		predicate = [NSPredicate predicateWithFormat:@"jidStr == %@ AND streamBareJidStr == %@",
					 bareJIDStr, [[self myJIDForXMPPStream:stream] bare]];
	
	NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setIncludesPendingChanges:YES];
	[fetchRequest setFetchLimit:1];
	
	NSArray *results = [moc executeFetchRequest:fetchRequest error:nil];
	
	return (XMPPUserCoreDataStorageObject *)[results lastObject];
}

- (XMPPResourceCoreDataStorageObject *)_resourceForJID:(XMPPJID *)jid
                                            xmppStream:(XMPPStream *)stream
                                  managedObjectContext:(NSManagedObjectContext *)moc
{
	XMPPLogTrace();
	AssertPrivateQueue();
	
	if (jid == nil) return nil;
	
	NSString *fullJIDStr = [jid full];
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPResourceCoreDataStorageObject"
	                                          inManagedObjectContext:moc];
	
	NSPredicate *predicate;
	if (stream == nil)
		predicate = [NSPredicate predicateWithFormat:@"jidStr == %@", fullJIDStr];
	else
		predicate = [NSPredicate predicateWithFormat:@"jidStr == %@ AND streamBareJidStr == %@",
					 fullJIDStr, [[self myJIDForXMPPStream:stream] bare]];
	
	NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:predicate];
	[fetchRequest setIncludesPendingChanges:YES];
	[fetchRequest setFetchLimit:1];
	
	NSArray *results = [moc executeFetchRequest:fetchRequest error:nil];
	
	return (XMPPResourceCoreDataStorageObject *)[results lastObject];
}

- (void)_clearAllResourcesForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	AssertPrivateQueue();
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPResourceCoreDataStorageObject"
	                                          inManagedObjectContext:[self managedObjectContext]];
	
	NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
	[fetchRequest setEntity:entity];
	[fetchRequest setFetchBatchSize:saveThreshold];
	
	if (stream)
	{
		NSPredicate *predicate;
		predicate = [NSPredicate predicateWithFormat:@"streamBareJidStr == %@",
		                                    [[self myJIDForXMPPStream:stream] bare]];
		
		[fetchRequest setPredicate:predicate];
	}
	
	NSArray *allResources = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
	
	NSUInteger unsavedCount = [self numberOfUnsavedChanges];
	
	for (XMPPResourceCoreDataStorageObject *resource in allResources)
	{
		[[self managedObjectContext] deleteObject:resource];
		
		if (++unsavedCount >= saveThreshold)
		{
			[self save];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Overrides
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)willCreatePersistentStore:(NSString *)filePath
{
	// This method is overriden from the XMPPCoreDataStore superclass.
	// From the documentation:
	// 
	// Override me, if needed, to provide customized behavior.
	// 
	// For example, if you are using the database for non-persistent data you may want to delete the database
	// file if it already exists on disk.
	// 
	// The default implementation does nothing.
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:filePath])
	{
		[[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
	}
}

- (void)didCreateManagedObjectContext
{
	// This method is overriden from the XMPPCoreDataStore superclass.
	// From the documentation:
	// 
	// Override me, if needed, to provide customized behavior.
	// 
	// For example, if you are using the database for non-persistent data you may want to delete the database
	// file if it already exists on disk.
	// 
	// The default implementation does nothing.
	
	
	// Reserved for future use (directory versioning).
	// Perhaps invoke [self _clearAllResourcesForXMPPStream:nil] ?
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPUserCoreDataStorageObject *)myUserForXMPPStream:(XMPPStream *)stream
                                  managedObjectContext:(NSManagedObjectContext *)moc
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	if (moc == nil)
	{
		return nil;
	}
	
	XMPPJID *myJID = stream.myJID;
	if (myJID == nil)
	{
		return nil;
	}
	
	return [self _userForJID:myJID xmppStream:stream managedObjectContext:moc];
}

- (XMPPResourceCoreDataStorageObject *)myResourceForXMPPStream:(XMPPStream *)stream
                                          managedObjectContext:(NSManagedObjectContext *)moc
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	if (moc == nil)
	{
		return nil;
	}
	
	XMPPJID *myJID = stream.myJID;
	if (myJID == nil)
	{
		return nil;
	}
	
	return [self _resourceForJID:myJID xmppStream:stream managedObjectContext:moc];
}

- (XMPPUserCoreDataStorageObject *)userForJID:(XMPPJID *)jid
                                   xmppStream:(XMPPStream *)stream
                         managedObjectContext:(NSManagedObjectContext *)moc
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	if (moc == nil)
	{
		return nil;
	}
	
	return [self _userForJID:jid xmppStream:stream managedObjectContext:moc];
}

- (XMPPResourceCoreDataStorageObject *)resourceForJID:(XMPPJID *)jid
										   xmppStream:(XMPPStream *)stream
                                 managedObjectContext:(NSManagedObjectContext *)moc
{
	// This is a public method, so it may be invoked on any thread/queue.
	
	XMPPLogTrace();
	
	if (moc == nil)
	{
		return nil;
	}
	
	return [self _resourceForJID:jid xmppStream:stream managedObjectContext:moc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Protocol Private API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)beginRosterPopulationForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		[rosterPopulationSet addObject:[NSNumber numberWithPtr:stream]];
    
		// Clear anything already in the roster core data store.
		// 
		// Note: Deleting a user will delete all associated resources
		// because of the cascade rule in our core data model.
		
		NSManagedObjectContext *moc = [self managedObjectContext];
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorageObject"
		                                          inManagedObjectContext:moc];
		
		NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
		[fetchRequest setEntity:entity];
		[fetchRequest setFetchBatchSize:saveThreshold];
		
		if (stream)
		{
			NSPredicate *predicate;
			predicate = [NSPredicate predicateWithFormat:@"streamBareJidStr == %@",
			                                     [[self myJIDForXMPPStream:stream] bare]];
			
			[fetchRequest setPredicate:predicate];
		}
		
		NSArray *allUsers = [moc executeFetchRequest:fetchRequest error:nil];
		
		for (XMPPUserCoreDataStorageObject *user in allUsers)
		{
			[moc deleteObject:user];
		}
		
		[XMPPGroupCoreDataStorageObject clearEmptyGroupsInManagedObjectContext:moc];
	}];
}

- (void)endRosterPopulationForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		[rosterPopulationSet removeObject:[NSNumber numberWithPtr:stream]];
	}];
}

- (void)handleRosterItem:(NSXMLElement *)itemSubElement xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	// Remember XML heirarchy memory management rules.
	// The passed parameter is a subnode of the IQ, and we need to pass it to an asynchronous operation.
	NSXMLElement *item = [[itemSubElement copy] autorelease];
	
	[self scheduleBlock:^{
		
		NSManagedObjectContext *moc = [self managedObjectContext];
		
		if ([rosterPopulationSet containsObject:[NSNumber numberWithPtr:stream]])
		{
			NSString *streamBareJidStr = [[self myJIDForXMPPStream:stream] bare];
			
			[XMPPUserCoreDataStorageObject insertInManagedObjectContext:moc
			                                                   withItem:item
			                                           streamBareJidStr:streamBareJidStr];
		}
		else
		{
			NSString *jidStr = [item attributeStringValueForName:@"jid"];
			XMPPJID *jid = [[XMPPJID jidWithString:jidStr] bareJID];
			
			XMPPUserCoreDataStorageObject *user = [self _userForJID:jid xmppStream:stream managedObjectContext:moc];
			
			NSString *subscription = [item attributeStringValueForName:@"subscription"];
			if ([subscription isEqualToString:@"remove"])
			{
				if (user)
				{
					[moc deleteObject:user];
				}
			}
			else
			{
				if (user)
				{
					[user updateWithItem:item];
				}
				else
				{
					NSString *streamBareJidStr = [[self myJIDForXMPPStream:stream] bare];
					
					[XMPPUserCoreDataStorageObject insertInManagedObjectContext:moc
					                                                   withItem:item
					                                           streamBareJidStr:streamBareJidStr];
				}
			}
		}
	}];
}

- (void)handlePresence:(XMPPPresence *)presence xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		XMPPJID *jid = [presence from];
		NSManagedObjectContext *moc = [self managedObjectContext];
		
		XMPPUserCoreDataStorageObject *user = [self _userForJID:jid xmppStream:stream managedObjectContext:moc];
		
		if (user)
		{
			NSString *streamBareJidStr = [[self myJIDForXMPPStream:stream] bare];
			
			[user updateWithPresence:presence streamBareJidStr:streamBareJidStr];
		}
	}];
}

- (BOOL)userExistsWithJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	__block BOOL result = NO;
	
	[self executeBlock:^{
		
		NSManagedObjectContext *moc = [self managedObjectContext];
		XMPPUserCoreDataStorageObject *user = [self _userForJID:jid xmppStream:stream managedObjectContext:moc];
		
		result = (user != nil);
	}];
	
	return result;
}

#if TARGET_OS_IPHONE
- (void)setPhoto:(UIImage *)photo forUserWithJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
#else
- (void)setPhoto:(NSImage *)photo forUserWithJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
#endif
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		NSManagedObjectContext *moc = [self managedObjectContext];
		XMPPUserCoreDataStorageObject *user = [self _userForJID:jid xmppStream:stream managedObjectContext:moc];
		
		if (user)
		{
			user.photo = photo;
		}
	}];
}

- (void)clearAllResourcesForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		[self _clearAllResourcesForXMPPStream:stream];
	}];
}

- (void)clearAllUsersAndResourcesForXMPPStream:(XMPPStream *)stream
{
	XMPPLogTrace();
	
	[self scheduleBlock:^{
		
		// Note: Deleting a user will delete all associated resources
		// because of the cascade rule in our core data model.
		
		NSManagedObjectContext *moc = [self managedObjectContext];
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorageObject"
												  inManagedObjectContext:moc];
		
		NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
		[fetchRequest setEntity:entity];
		[fetchRequest setFetchBatchSize:saveThreshold];
		
		if (stream)
		{
			NSPredicate *predicate;
			predicate = [NSPredicate predicateWithFormat:@"streamBareJidStr == %@",
			                            [[self myJIDForXMPPStream:stream] bare]];
			
			[fetchRequest setPredicate:predicate];
		}
		
		NSArray *allUsers = [moc executeFetchRequest:fetchRequest error:nil];
		
		NSUInteger unsavedCount = [self numberOfUnsavedChanges];
		
		for (XMPPUserCoreDataStorageObject *user in allUsers)
		{
			[moc deleteObject:user];
			
			if (++unsavedCount >= saveThreshold)
			{
				[self save];
			}
		}
    
		[XMPPGroupCoreDataStorageObject clearEmptyGroupsInManagedObjectContext:moc];
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Memory Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)dealloc
{
	[rosterPopulationSet release];
	[super dealloc];
}

@end
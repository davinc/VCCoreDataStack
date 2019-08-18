//
//  VCCoreDataStack.m
//
//  Created by Vinay Chavan on 04/07/13.
//  Copyright (C) 2011 by Vinay Chavan
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "VCCoreDataStack.h"

@implementation VCCoreDataStack

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (id)initWithManagedObjectModelUrl:(NSURL *)managedObjectModelUrl
{
	self = [super init];
	if (self) {
		_managedObjectModelUrl = [managedObjectModelUrl copy];
	}
	return self;
}

#pragma mark - Private Methods

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
	return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}


#pragma mark - Core Data stack

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
	if (_managedObjectModel != nil) {
		return _managedObjectModel;
	}
	
	_managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:_managedObjectModelUrl];
	return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
	if (_persistentStoreCoordinator != nil) {
		return _persistentStoreCoordinator;
	}
	
	NSString *fileName = [[_managedObjectModelUrl URLByDeletingPathExtension] lastPathComponent];
	NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:[fileName stringByAppendingString:@".sqlite"]];
	
	NSError *error = nil;
	NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption:[NSNumber numberWithBool:YES],
                              NSInferMappingModelAutomaticallyOption:[NSNumber numberWithBool:YES]};
	_persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
	if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                   configuration:nil
                                                             URL:storeURL
                                                         options:options
                                                           error:&error]) {
		NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
		
		// delete old file and create new one
		[[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
		_persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
		if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
			NSAssert(FALSE, @"Unresolved error %@, %@", error, [error userInfo]);
		}
	}
	
	return _persistentStoreCoordinator;
}

// Used to propegate saves to the persistent store (disk) without blocking the UI
- (NSManagedObjectContext *)managedObjectContext {
	if (_managedObjectContext != nil) {
		return _managedObjectContext;
	}
	
	NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
	if (coordinator != nil) {
		_managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
		[_managedObjectContext performBlockAndWait:^{
			[_managedObjectContext setPersistentStoreCoordinator:coordinator];
		}];
	}
	return _managedObjectContext;
}

- (NSManagedObjectContext *)privateManagedObjectContext {
	NSManagedObjectContext *privateManagedObjectContext = nil;
	NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
	if (managedObjectContext != nil) {
		privateManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
		[privateManagedObjectContext performBlockAndWait:^{
			[privateManagedObjectContext setParentContext:managedObjectContext];
		}];
	}
	
	return privateManagedObjectContext;
}

- (void)saveManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
	if (managedObjectContext == nil) {
		return;
	}
	
	[managedObjectContext performBlockAndWait:^{
		NSError *error = nil;
		BOOL saved = [managedObjectContext save:&error];
		if (!saved) {
			// do some real error handling
			NSAssert(FALSE, @"Unresolved error %@, %@", error, [error userInfo]);
		}
	}];
	
	[self saveManagedObjectContext:managedObjectContext.parentContext];
}

#pragma mark - Public Methods

- (void)deleteCoreDataStack
{
	// delete context
	_managedObjectContext = nil;
	
	// delete object model
	_managedObjectModel = nil;
	
	// delete persistant store coordinater and all its stores
	NSPersistentStoreCoordinator *cordinator = [self persistentStoreCoordinator];
	NSArray *stores = [cordinator persistentStores];
	for(NSPersistentStore *store in stores) {
		if (@available(iOS 9.0, *)) {
                    NSError *error = nil;
		    if(![cordinator destroyPersistentStoreAtURL:store.URL
						       withType:NSSQLiteStoreType
						        options:nil
						          error:&error]) {
			// do some real error handling
			NSAssert(FALSE, @"Unresolved error %@, %@", error, [error userInfo]);
		    }
		} else {
		    // Fallback on earlier versions
		    NSError *error = nil;
		    if(![cordinator removePersistentStore:store error:&error]) {
			// do some real error handling
			NSAssert(FALSE, @"Unresolved error %@, %@", error, [error userInfo]);
		    }
		    error = nil;
		    if(![[NSFileManager defaultManager] removeItemAtPath:store.URL.path error:nil]) {
			// do some real error handling
			NSAssert(FALSE, @"Unresolved error %@, %@", error, [error userInfo]);
		    }
		}
	}
	_persistentStoreCoordinator = nil;
}

@end

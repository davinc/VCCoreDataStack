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

- (void)dealloc
{
	[_managedObjectModelUrl release], _managedObjectModelUrl = nil;
	[_managedObjectModel release], _managedObjectModel = nil;
	[_persistentStoreCoordinator release], _persistentStoreCoordinator = nil;
	[_managedObjectContext release], _managedObjectContext = nil;
	[super dealloc];
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
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        DebugLog(@"Unresolved error %@, %@", error, [error userInfo]);

		// delete old file and create new one
		[[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
		_persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
		if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
			DebugLog(@"Unresolved error %@, %@", error, [error userInfo]);
			abort();
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


#pragma mark - Public Methods

- (void)deleteCoreDataStack
{
	NSArray *stores = [_persistentStoreCoordinator persistentStores];

	for(NSPersistentStore *store in stores) {
#warning Add error handling
		[_persistentStoreCoordinator removePersistentStore:store error:nil];
		[[NSFileManager defaultManager] removeItemAtPath:store.URL.path error:nil];
	}

	[_managedObjectContext release], _managedObjectContext = nil;
	[_persistentStoreCoordinator release], _persistentStoreCoordinator = nil;
	[_managedObjectModel release], _managedObjectModel = nil;
}

@end
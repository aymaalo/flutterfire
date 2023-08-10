/*
 * Copyright 2023, the Chromium project authors.  Please see the AUTHORS file
 * for details. All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

#import <Firebase/Firebase.h>
#import <Foundation/Foundation.h>
#import "messages.g.h"

@interface PigeonParser : NSObject

+ (FIRQuery *)parseQueryWithParameters:
(nonnull PigeonQueryParameters *)parameters firestore:(nonnull FIRFirestore*)firestore path:(nonnull NSString*)path isCollectionGroup:(Boolean)isCollectionGroup;
+ (FIRFilter *_Nonnull)filterFromJson:(NSDictionary<NSString *, id> *_Nullable)map;
+ (FIRFirestoreSource) parseSource:(Source)source;
+ (FIRServerTimestampBehavior) parseServerTimestampBehavior:(ServerTimestampBehavior)serverTimestampBehavior;
+ (PigeonDocumentSnapshot *) toPigeonDocumentSnapshot:(FIRDocumentSnapshot*)documentSnapshot serverTimestampBehavior:(FIRServerTimestampBehavior)serverTimestampBehavior;
+ (PigeonSnapshotMetadata *) toPigeonSnapshotMetadata:(FIRSnapshotMetadata*)snapshotMetadata;
@end
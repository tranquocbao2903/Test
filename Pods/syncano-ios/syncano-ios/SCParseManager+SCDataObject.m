//
//  SCParseManager+SCDataObject.m
//  syncano4-ios
//
//  Created by Jan Lipmann on 07/05/15.
//  Copyright (c) 2015 Syncano. All rights reserved.
//

#import "SCParseManager+SCDataObject.h"
#import "SCDataObject.h"
#import <objc/runtime.h>
#import "SCFile.h"
#import "SCDataObject+Properties.h"
#import "SCRegisterManager.h"

@implementation SCParseManager (SCDataObject)

- (id)parsedObjectOfClass:(__unsafe_unretained Class)objectClass fromJSONObject:(id)JSONObject {
    id parsedobject = [MTLJSONAdapter modelOfClass:objectClass fromJSONDictionary:JSONObject error:NULL];
    if(parsedobject == nil) {
        return parsedobject;//possible error in parsing
    }
    [self.referencesStore addDataObject:parsedobject];
    [self resolveRelationsToObject:parsedobject withJSONObject:JSONObject];
    [self resolveFilesForObject:parsedobject withJSONObject:JSONObject];
    return parsedobject;
}

- (id)relatedObjectOfClass:(__unsafe_unretained Class)objectClass fromJSONObject:(id)JSONObject {
    if(JSONObject[@"id"] != nil) {
        //object is downloaded
        return [self parsedObjectOfClass:objectClass fromJSONObject:JSONObject];
    }
    
    NSNumber *relatedObjectId = JSONObject[@"value"];
    if (relatedObjectId) {
        //we have only id
        id relatedObject = [self.referencesStore getObjectById:relatedObjectId];
        if (relatedObject) {
            return relatedObject;
        } else {
            relatedObject = [[objectClass alloc] init];
            [relatedObject setValue:relatedObjectId forKey:@"objectId"];
            [self.referencesStore addDataObject:relatedObject];
        }
        return relatedObject;
    }
    
    return nil;
}

- (void)resolveRelationsToObject:(id)parsedObject withJSONObject:(id)JSONObject {
    NSDictionary* relations = [SCRegisterManager relationsForClass:[parsedObject class]];
    for (NSString *relationKeyProperty in relations.allKeys) {
        SCClassRegisterItem *relationRegisteredItem = relations[relationKeyProperty];
        Class relatedClass = relationRegisteredItem.classReference;
        if (JSONObject[relationKeyProperty] != [NSNull null]) {
            id relatedObject = [self relatedObjectOfClass:relatedClass fromJSONObject:JSONObject[relationKeyProperty]];
            if (relatedObject != nil) {
                SCValidateAndSetValue(parsedObject, relationKeyProperty, relatedObject, YES, nil);
            }
        }
    }
}

- (void)resolveFilesForObject:(id)parsedObject withJSONObject:(id)JSONObject {
    for (NSString *key in [JSONObject allKeys]) {
        if ([parsedObject respondsToSelector:NSSelectorFromString(key)]) {
            id object = JSONObject[key];
            if ([object isKindOfClass:[NSDictionary class]] && object[@"type"] && [object[@"type"] isEqualToString:@"file"]) {
                //TODO change to send error
                NSError *error = nil;
                SCFile *file = [[SCFile alloc] initWithDictionary:object error:&error];
                SCValidateAndSetValue(parsedObject, key, file, YES, nil);
            }
        }
    }
}

- (NSArray *)parsedObjectsOfClass:(__unsafe_unretained Class)objectClass fromJSONObject:(id)responseObject {
    NSArray *responseObjects = responseObject;
    NSMutableArray *parsedObjects = [[NSMutableArray alloc] initWithCapacity:responseObjects.count];
    for (NSDictionary *object in responseObjects) {
        id result = [self parsedObjectOfClass:objectClass fromJSONObject:object];
        [parsedObjects addObject:result];
    }
    return [NSArray arrayWithArray:parsedObjects];
}

- (void)fillObject:(SCDataObject *)object withDataFromJSONObject:(id)responseObject {
    id newParsedObject = [self parsedObjectOfClass:[object class] fromJSONObject:responseObject];
    [object mergeValuesForKeysFromModel:newParsedObject];
}

- (NSDictionary *)JSONSerializedDictionaryFromDataObject:(SCDataObject *)dataObject error:(NSError *__autoreleasing *)error {
    NSDictionary *serialized = [MTLJSONAdapter JSONDictionaryFromModel:dataObject error:nil];
    /**
     *  Temporary remove non saved relations
     */
    NSDictionary *relations = [SCRegisterManager relationsForClass:[dataObject class]];
    if (relations.count > 0) {
        NSMutableDictionary *mutableSerialized = serialized.mutableCopy;
        for (NSString *relationProperty in relations.allKeys) {
            id relatedObject = [dataObject valueForKey:relationProperty];
            // relatedObject == nil means no relation was set at all
            // and we want to handle only ones that were set but were not saved
            if (relatedObject == nil) {
                continue;
            }
            NSNumber *objectId = [relatedObject valueForKey:@"objectId"];
            if (objectId) {
                [mutableSerialized setObject:objectId forKey:relationProperty];
            } else {
                if (error != NULL) {
                    NSDictionary *userInfo = @{
                                               NSLocalizedDescriptionKey: NSLocalizedString(@"Unsaved relation", @""),
                                               NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"You can not add reference for unsaved object",@""),
                                               };
                    *error = [NSError errorWithDomain:@"SCParseManagerErrorDomain" code:1 userInfo:userInfo];
                }
                [mutableSerialized removeObjectForKey:relationProperty];
            }
        }
        serialized = [NSDictionary dictionaryWithDictionary:mutableSerialized];
    }
    
    //Remove SCFileProperties
    NSArray *fileProperties = [[dataObject class] propertiesNamesOfFileClass];
    if (fileProperties.count > 0) {
        NSMutableDictionary *mutableSerialized = serialized.mutableCopy;
        for (NSString *fileProperty in fileProperties) {
            [mutableSerialized removeObjectForKey:fileProperty];
        }
        serialized = [NSDictionary dictionaryWithDictionary:mutableSerialized];
    }
    return serialized;
}
@end

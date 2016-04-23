//
//  SCPleaseProtected.h
//  syncano-ios
//
//  Created by Jakub Machoń on 25.01.2016.
//  Copyright © 2016 Syncano. All rights reserved.
//

@interface SCPlease ()

/**
 *  API class name representation of connected SCDataObject Class
 */
@property (nonatomic,retain) NSString *classNameForAPICalls;

/**
 *  [Abstract] API Client used by SCPlease to get data from syncano instance
 *
 *  @return SCAPIClient instance
 */
- (SCAPIClient *)apiClient;

/**
 *  [Abstract] Method to handle repsonse
 *
 *  @param responseObject repsonse object to handle
 *  @param error          response error to handle
 *  @param completion     completion block
 */
- (void)handleResponse:(id)responseObject error:(NSError *)error completion:(SCDataObjectsCompletionBlock)completion;

@end

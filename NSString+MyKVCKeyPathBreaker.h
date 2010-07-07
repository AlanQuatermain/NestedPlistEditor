//
//  NSString+MyKVCKeyPathBreaker.h
//  NestedPlistEditor
//
//  Created by Jim Dovey on 10-07-07.
//  Copyright 2010 Jim Dovey. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (MyKVCKeyPathBreaker)
- (NSArray *) my_componentsSeparatedByKVCPathDelimiters;
@end

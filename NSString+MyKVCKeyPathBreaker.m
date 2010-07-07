//
//  NSString+MyKVCKeyPathBreaker.m
//  NestedPlistEditor
//
//  Created by Jim Dovey on 10-07-07.
//  Copyright 2010 Jim Dovey. All rights reserved.
//

#import "NSString+MyKVCKeyPathBreaker.h"

@implementation NSString (MyKVCKeyPathBreaker)

- (NSArray *) my_componentsSeparatedByKVCPathDelimiters
{
	NSScanner * scanner = [NSScanner scannerWithString: self];
	NSMutableArray * components = [NSMutableArray arrayWithCapacity: 16];
	BOOL foundEscapedPeriod = NO;
	NSRange pullRange = {0, 0};
	
	do
	{
		if ( foundEscapedPeriod == NO )
			pullRange.location = [scanner scanLocation];
		[scanner scanUpToString: @"." intoString: NULL];
		
		// check character preceding the period-- is it a backslash?
		if ( [self characterAtIndex: [scanner scanLocation]-1] == (unichar)'\\' )
		{
			// not a break -- but we'll need to replace it in the substring we generate
			foundEscapedPeriod = YES;
			[scanner setScanLocation: [scanner scanLocation]+1];
			continue;
		}
		
		pullRange.length = [scanner scanLocation] - pullRange.location;
		if ( pullRange.length != 0 )
		{
			NSString * substring = [self substringWithRange: pullRange];
			if ( foundEscapedPeriod )
			{
				substring = [substring stringByReplacingOccurrencesOfString: @"\\." withString: @"."];
				foundEscapedPeriod = NO;
			}
			
			[components addObject: substring];
		}
		
		// skip over the period
		if ( [scanner isAtEnd] == NO )
			[scanner setScanLocation: [scanner scanLocation]+1];
		
	} while ([scanner isAtEnd] == NO);
	
	return ( [[components copy] autorelease] );
}

@end

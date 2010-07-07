/*
 * NestedPlistEditor.m
 * NestedPlistEditor
 * 
 * Created by Jim Dovey on 6/7/2010.
 * 
 * Copyright (c) 2010 Jim Dovey
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 
 * Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 * 
 * Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 * 
 * Neither the name of the project's author nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#import <Foundation/Foundation.h>
#import <sysexits.h>
#import "NSString+MyKVCKeyPathBreaker.h"

static void usage(FILE *pFile) __dead2;

void usage( FILE *pFile )
{
	fprintf( pFile, "Command line interface to a user's defaults, with support for nested properties.\n" );
	fprintf( pFile, "Syntax:\n\n" );
	
	fprintf( pFile, "'defaults-nested' [-currentHost | -host <hostname>] followed by one of the following:\n\n" );
	
	fprintf( pFile, "read                                 shows all defaults\n" );
	fprintf( pFile, "read <domain>                        shows defaults for given domain\n" );
	fprintf( pFile, "read <domain> <key>                  shows defaults for given domain, key\n\n" );
	
	fprintf( pFile, "read-type <domain> <key>             shows the type for the given domain, key\n\n" );
	
	fprintf( pFile, "write <domain> <domain_rep>          writes domain (overwrites existing)\n" );
	fprintf( pFile, "write <domain> <key> <value>         writes key for domain\n\n" );
	
	fprintf( pFile, "rename <domain> <old_key> <new_key>  renames old_key to new_key\n\n" );
	
	fprintf( pFile, "delete <domain>                      deletes domain\n" );
	fprintf( pFile, "delete <domain> <key>                deletes key in domain\n\n" );
	
	fprintf( pFile, "domains                              lists all domains\n" );
	fprintf( pFile, "help                                 print this help\n\n" );
	
	fprintf( pFile, "<domain> is ( <domain_name> | -app <application_name> | -globalDomain )\n" );
	fprintf( pFile, "         or a path to a file omitting the '.plist' extension\n\n" );
	
	fprintf( pFile, "<key> is a KVC-style key-path to an item within the property list, with\n" );
	fprintf( pFile, "      a new array index operator: 'path.to.array.@index(0)' will return\n" );
	fprintf( pFile, "      the first item in the object specified by 'path.to.array'.\n\n" );
	
	fprintf( pFile, "<value> is one of:\n" );
	fprintf( pFile, "  <value_rep>\n" );
	fprintf( pFile, "  -string <string_value>\n" );
	fprintf( pFile, "  -data <hex_digits>\n" );
	fprintf( pFile, "  -int[eger] <integer_value>\n" );
	fprintf( pFile, "  -float  <floating-point_value>\n" );
	fprintf( pFile, "  -bool[ean] (true | false | yes | no)\n" );
	fprintf( pFile, "  -date <date_rep>\n" );
	fprintf( pFile, "  -array <value1> <value2> ...\n" );
	fprintf( pFile, "  -array-add <value1> <value2> ...\n" );
	fprintf( pFile, "  -dict <key1> <value1> <key2> <value2> ...\n" );
	fprintf( pFile, "  -dict-add <key1> <value1> ...\n" );
	
	fflush( pFile );
	if ( pFile == stderr )
		exit( EX_USAGE );
	
	exit( EX_OK );
}

void SafePrintNSString( NSString * format, ... )
{
	va_list args;
	va_start(args, format);
	NSString * combined = [[NSString alloc] initWithFormat: format arguments: args];
	va_end(args);
	
	NSData * data = [combined dataUsingEncoding: NSNonLossyASCIIStringEncoding allowLossyConversion: YES];
	fprintf( stdout, "%.*s", (int)[data length], (const char *)[data bytes] );
	
	[combined release];
}

id GetNestedValue( id rootObject, NSMutableArray * comps )
{	
	// somewhere or other we've got an array index to take into account
	id current = rootObject;
	do
	{
		NSMutableString * path = [NSMutableString string];
		__block NSUInteger indexerLocation = NSNotFound;
		__block NSUInteger arrayIndexValue = NSNotFound;
		__block NSString * escapedNextKey = nil;
		
		[comps enumerateObjectsUsingBlock: ^(id obj, NSUInteger idx, BOOL *stop) {
			// check its prefix and length -- 8 characters for '@index()', should be 9 or more in total
			if ( ([obj hasPrefix: @"@index"]) && ([obj length] > 8) )
			{
				// parse the argument value -- we know exactly where it is now
				arrayIndexValue = (NSUInteger)[[obj substringWithRange: NSMakeRange(7, [obj length] - 8)] integerValue];
				indexerLocation = idx+1;	// store this location so we can trim the comps later
				*stop = YES;
			}
			else if ([obj rangeOfString: @"."].location != NSNotFound)
			{
				// grab this item and use it in -valueForKey: instead of -valueForKeyPath:, so the periods are processed
				escapedNextKey = obj;
				indexerLocation = idx+1;
				*stop = YES;
			}
			else
			{
				// just append it as-is
				if ( [path length] > 0 )
					[path appendString: @"."];
				[path appendString: obj];
			}
		}];
		
		if ( [path length] != 0 )
		{
			current = [current valueForKeyPath: path];
			if ( current == nil )
				break;
		}
		
		if ( arrayIndexValue != NSNotFound )
		{
			if ( [current respondsToSelector: @selector(objectAtIndex:)] == NO )
			{
				// it's not actually an indexable type
				current = nil;
				break;
			}
			else if ( arrayIndexValue >= [current count] )
			{
				// invalid index
				current = nil;
				break;
			}
			
			// move to that item
			current = [current objectAtIndex: arrayIndexValue];
		}
		
		if ( escapedNextKey != nil )
		{
			// use -valueForKey instead of valueForKeyPath: for keys which contain (valid) period characters
			current = [current valueForKey: escapedNextKey];
		}
		
		// if we passed the end of the array, we go out
		if ( indexerLocation >= ([comps count]) )
			break;
		
		// otherwise, we trim the array to remove those items we've already used
		[comps removeObjectsInRange: NSMakeRange(0, indexerLocation)];
		
	} while (1);
	
	return ( current );
}

id CopyNestedPreferenceValue( NSString * key, NSString * domain, CFStringRef user, CFStringRef host )
{
	NSMutableArray * comps = [[key my_componentsSeparatedByKVCPathDelimiters] mutableCopy];
	
	// grab the root item
	id rootObject = NSMakeCollectable(CFPreferencesCopyValue((CFStringRef)[comps objectAtIndex: 0], (CFStringRef)domain, user, host));
	
	if ( [comps count] == 1 )
	{
		// this is all we want
		return ( rootObject );
	}
	else if ( ([key rangeOfString: @"@index"].location == NSNotFound) && ([key rangeOfString: @"\\."].location == NSNotFound) )
	{
		// no array index specifications -- use plain old KVC
		NSString * path = [[comps subarrayWithRange: NSMakeRange(1, [comps count]-1)] componentsJoinedByString: @"."];
		return ( [rootObject valueForKeyPath: path] );
	}
	
	[comps removeObjectAtIndex: 0];
	return ( GetNestedValue(rootObject, comps) );
}

id CopyEditableRootForNestedValue( NSString * key, NSString * domain, CFStringRef user, CFStringRef host,
								   id *parentToChange, id *oldValue )
{
	*parentToChange = nil;
	*oldValue = nil;
	
	NSMutableArray * comps = [[key my_componentsSeparatedByKVCPathDelimiters] mutableCopy];
	
	// grab the root item
	id rootObject = NSMakeCollectable(CFPreferencesCopyValue((CFStringRef)[comps objectAtIndex: 0], (CFStringRef)domain, user, host));
	
	if ( [comps count] == 1 )
	{
		// this is all we want
		*oldValue = rootObject;
		return ( rootObject );
	}
	else if ( [key rangeOfString: @"@index"].location == NSNotFound )
	{
		// no array index specifications -- use plain old KVC
		NSString * path = [[comps subarrayWithRange: NSMakeRange(1, [comps count]-1)] componentsJoinedByString: @"."];
		*oldValue = [rootObject valueForKeyPath: path];
		return ( *oldValue );
	}
	
	[comps removeObjectAtIndex: 0];
	
	// make it completely mutable by serializing it out & back
	NSData * data = [NSPropertyListSerialization dataWithPropertyList: rootObject
															   format: NSPropertyListBinaryFormat_v1_0
															  options: 0
																error: NULL];
	rootObject = [NSPropertyListSerialization propertyListWithData: data
														   options: NSPropertyListMutableContainers
															format: NULL
															 error: NULL];
	
	*parentToChange = GetNestedValue(rootObject, [[comps subarrayWithRange: NSMakeRange(0, [comps count]-1)] mutableCopy]);
	*oldValue = GetNestedValue(*parentToChange, [[comps subarrayWithRange: NSMakeRange([comps count]-1, 1)] mutableCopy]);
	
	return ( rootObject );
}

BOOL SetValueForIndexableKey( id parent, NSString * fullKeyPath, id value )
{
	NSString * key = [[fullKeyPath my_componentsSeparatedByKVCPathDelimiters] lastObject];
	
	if ( ([key hasPrefix: @"@index"]) && ([key length] > 8) )
	{
		// parse the argument value -- we know exactly where it is now
		NSUInteger idx = (NSUInteger)[[key substringWithRange: NSMakeRange(7, [key length] - 8)] integerValue];
		if ( idx > [parent count] )
			return ( NO );
		
		if ( idx < [parent count] )
			[parent replaceObjectAtIndex: idx withObject: value];
		else
			[parent addObject: value];
	}
	else
	{
		[parent setValue: value forKey: key];
	}
	
	return ( YES );
}

int main (int argc, const char * argv[])
{
    if ( argc < 2 )
		usage(stderr);		// terminates app
	
	if ( strncmp(argv[1], "help", 4) == 0 )
		usage(stdout);		// terminates app
	
	CFStringRef anyUser = kCFPreferencesAnyUser;
	CFStringRef user = kCFPreferencesCurrentUser;
	CFStringRef host = kCFPreferencesAnyHost;
	
	NSMutableArray * args = [[[NSProcessInfo processInfo] arguments] mutableCopy];
	
	// eat the process name/path
	[args removeObjectAtIndex: 0];
	
	if ( [[args objectAtIndex: 0] caseInsensitiveCompare: @"-currentHost"] == NSOrderedSame )
	{
		host = kCFPreferencesCurrentHost;
		[args removeObjectAtIndex: 0];
	}
	else if ( ([[args objectAtIndex: 0] caseInsensitiveCompare: @"-host"] == NSOrderedSame) && ([args count] > 1) )
	{
		host = (CFStringRef)[args objectAtIndex: 1];
		[args removeObjectsInRange: NSMakeRange(0, 2)];
	}
	
	if ( [args count] == 0 )
		usage(stderr);
	
	void (^domainNotFound)(NSString *) = ^(NSString * domain) {
		if ( [domain isEqual: (id)kCFPreferencesAnyApplication] )
			domain = @"Apple Global Domain";
		SafePrintNSString( @"\nDomain (%@) not found.\nDefaults have not been changed.\n", domain );
	};
	void (^domainHasNoKey)(NSString *, NSString *) = ^(NSString * domain, NSString * key) {
		if ( [domain isEqual: (id)kCFPreferencesAnyApplication] )
			domain = @"Apple Global Domain";
		SafePrintNSString( @"\nKey %@ does not exist in domain %@; leaving defaults unchanged.\n", key, domain );
	};
	void (^domainDefaultPairInvalid)(NSString *, NSString *) = ^(NSString * domain, NSString * key) {
		if ( [domain isEqual: (id)kCFPreferencesAnyApplication] )
			domain = @"Apple Global Domain";
		SafePrintNSString( @"\nThe domain/default pair of (%@, %@) does not exist\n", domain, key );
	};
	
	// copies keys, retains arguments -- which is okay, since we only use the blocks while on the same stack frame
	NSMutableDictionary * commands = [NSMutableDictionary new];
	
	// that's set up its types-- best to use the C API to insert our types, to avoid casts to 'id' all over the place
	
	////////////////////////
	// read command
	[commands setObject: ^{
		if ( [args count] < 1 || [args count] > 2 )
			usage(stderr);
		
		NSString * domain = [args objectAtIndex: 0];
		id value = nil;
		
		if ( [args count] == 2 )
		{
			NSString * key = [args objectAtIndex: 1];
			value = CopyNestedPreferenceValue(key, domain, user, host);
			if ( value == nil )
			{
				domainDefaultPairInvalid(domain, key);
				return;
			}
		}
		else
		{
			value = NSMakeCollectable(CFPreferencesCopyMultiple(NULL, (CFStringRef)domain, user, host));
			if ( value == nil )
			{
				domainNotFound(domain);
				return;
			}
		}
		
		SafePrintNSString( @"%@\n", [value description] );
	} forKey: @"read"];
	
	////////////////////////
	// read-type command
	[commands setObject: ^{
		if ( [args count] != 2 )
			usage( stderr );
		
		NSString * domain = [args objectAtIndex: 0];
		NSString * key = [args objectAtIndex: 1];
		
		CFTypeRef value = CFMakeCollectable(CFPreferencesCopyValue((CFStringRef)key, (CFStringRef)domain, anyUser, host));
		if ( value == NULL )
		{
			domainDefaultPairInvalid(domain, key);
			return;
		}
		
		NSString * typeStr = nil;
		
		CFTypeID typeID = CFGetTypeID(value);
		if ( typeID == CFStringGetTypeID() )
		{
			typeStr = @"string";
		}
		else if ( typeID == CFDataGetTypeID() )
		{
			typeStr = @"data";
		}
		else if ( typeID == CFNumberGetTypeID() )
		{
			if ( CFNumberIsFloatType(value) )
				typeStr = @"float";
			else
				typeStr = @"integer";
		}
		else if ( typeID == CFBooleanGetTypeID() )
		{
			typeStr = @"boolean";
		}
		else if ( typeID == CFDateGetTypeID() )
		{
			typeStr = @"date";
		}
		else if ( typeID == CFArrayGetTypeID() )
		{
			typeStr = @"array";
		}
		else if ( typeID == CFDictionaryGetTypeID() )
		{
			typeStr = @"dictionary";
		}
		else
		{
			typeStr = @"an unknown property list type";
		}
		
		SafePrintNSString( @"Type is %@\n", typeStr );
	} forKey: @"read-type"];
	
	////////////////////////
	// write command
	[commands setObject: ^{
		if ( [args count] < 2 || [args count] > 3 )
			usage(stderr);
		
		NSString * domain = [args objectAtIndex: 0];
		if ( [args count] == 2 )
		{
			id replacement = [args objectAtIndex: 1];
			if ( (replacement == nil) || ([replacement isKindOfClass: [NSDictionary class]] == NO) )
			{
				SafePrintNSString( @"\nRep argument is not a dictionary\nDefaults have not been changed.\n" );
				return;
			}
			
			NSMutableArray * keysToRemove = [NSMakeCollectable(CFPreferencesCopyKeyList((CFStringRef)domain, user, host)) mutableCopy];
			if ( keysToRemove == nil )
			{
				domainNotFound(domain);
				return;
			}
			
			[keysToRemove removeObjectsInArray: [replacement allKeys]];
			CFPreferencesSetMultiple( (CFPropertyListRef)replacement, (CFArrayRef)keysToRemove, (CFStringRef)domain, user, host );
		}
		else
		{
			NSString * key = [args objectAtIndex: 1];
			id value = [args objectAtIndex: 2];
			
			id oldValue = nil;
			id parent = nil;
			id root = CopyEditableRootForNestedValue( key, domain, user, host, &parent, &oldValue );
			
			if ( oldValue != nil )
			{
				if ( [oldValue isKindOfClass: [NSArray class]] )
				{
					if ( [value isKindOfClass: [NSArray class]] == NO )
					{
						SafePrintNSString( @"Value for key %@ is not an array; cannot append.  Leaving defaults unchanged.\n", key );
						return;
					}
					
					// merge in new values
					value = [oldValue arrayByAddingObjectsFromArray: value];
				}
				else if ( [oldValue isKindOfClass: [NSDictionary class]] )
				{
					if ( [value isKindOfClass: [NSDictionary class]] == NO )
					{
						SafePrintNSString( @"Value for key %@ is not a dictionary; cannot append.  Leaving defaults unchanged.\n" );
						return;
					}
					
					// merge in new keys/values
					value = [value mutableCopy];
					[value addEntriesFromDictionary: oldValue];
				}
			}
			
			if ( oldValue == root )
			{
				// simple case
				CFPreferencesSetValue( (CFStringRef)key, (CFPropertyListRef)value, (CFStringRef)domain, user, host );
			}
			else
			{
				NSString * rootKey = [key substringToIndex: [key rangeOfString: @"."].location];
				
				// first set the actual value deep in the hierarchy
				if ( SetValueForIndexableKey(parent, key, value) == NO )
				{
					SafePrintNSString( @"Array index for settable value is out of bounds.\n" );
					return;
				}
				
				// then plonk the hierarchy back into the root
				CFPreferencesSetValue( (CFStringRef)rootKey, (CFPropertyListRef)root, (CFStringRef)domain, user, host );
			}
		}
		
		CFPreferencesSynchronize( (CFStringRef)domain, user, host );
	} forKey: @"write"];
	
	////////////////////////
	// rename command
	[commands setObject: ^{
		if ( [args count] != 5 )
			usage( stderr );
		
		NSString * domain = [args objectAtIndex: 0];
		NSString * oldKey = [args objectAtIndex: 1];
		NSString * newKey = [args objectAtIndex: 2];
		
		CFPropertyListRef value = CFMakeCollectable(CFPreferencesCopyValue((CFStringRef)oldKey, (CFStringRef)domain, user, host));
		if ( value == NULL )
		{
			domainHasNoKey(domain, oldKey);
			return;
		}
		
		CFPreferencesSetValue( (CFStringRef)newKey, value, (CFStringRef)domain, user, host );
		CFPreferencesSetValue( (CFStringRef)oldKey, NULL, (CFStringRef)domain, user, host );
		CFPreferencesSynchronize( (CFStringRef)domain, user, host );
	} forKey: @"rename"];
	
	/////////////////////////
	// delete command
	[commands setObject: ^{
		if ( [args count] < 1 || [args count] > 2 )
			usage( stderr );
		
		NSString * domain = [args objectAtIndex: 0];
		if ( [args count] == 1 )
		{
			NSArray * keys = NSMakeCollectable(CFPreferencesCopyKeyList((CFStringRef)domain, user, host));
			if ( [keys count] == 0 )
			{
				domainNotFound(domain);
				return;
			}
			
			CFPreferencesSetMultiple( NULL, (CFArrayRef)keys, (CFStringRef)domain, user, host );
		}
		else
		{
			CFPreferencesSetValue( (CFStringRef)[args objectAtIndex: 1], NULL, (CFStringRef)domain, user,  host );
		}
		
		CFPreferencesSynchronize( (CFStringRef)domain, user, host );
	} forKey: @"delete"];
	
	/////////////////////////
	// domains command
	[commands setObject: ^{
		NSArray * allDomains = NSMakeCollectable(CFPreferencesCopyApplicationList(user, host));
		NSUInteger idx = [allDomains indexOfObject: (id)kCFPreferencesAnyApplication];
		if ( idx != NSNotFound )
		{
			NSMutableArray * tmp = [allDomains mutableCopy];
			[tmp removeObjectAtIndex: idx];
			allDomains = [tmp autorelease];
		}
		
		SafePrintNSString( @"%@\n", [[allDomains componentsJoinedByString: @", "] description] );
	} forKey: @"domains"];
	
	dispatch_block_t handler = [commands objectForKey: [args objectAtIndex: 0]];
	if ( handler == NULL)
		usage(stderr);
	
	// eat the command name
	[args removeObjectAtIndex: 0];
	
	handler();

    return ( EX_OK );
}

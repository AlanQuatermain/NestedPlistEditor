NestedPlistEditor
=================

Version 0.9 -- July 7 2010

By "Jim Dovey":mailto:jimdovey@mac.com

**Requires Mac OS X 10.6 or later to run.**

Introduction
------------

This project implements something very similar to the 'defaults' command line tool, with one major difference: it supports nested properties.

The nested property support makes use of Key-Value Coding with a single addition. Paths themselves are period-delimited (support for escaped period characters in property names is forthcoming), and can use various functions, each preceded with an @ character. This means that you can use the set and array operators described in the "official KVC documentation":http://developer.apple.com/mac/library/documentation/Cocoa/Conceptual/KeyValueCoding/Concepts/ArrayOperators.html#//apple_ref/doc/uid/20002176-BAJEAIEE. For instance, you can print an average of scores across all Players by using a path similar to:

    defaults-nested read com.mycompany.myapp Players.@avg.Score

Our one addition to the KVC syntax is an array index specification. This uses the format:

    @index([num])

So for example we can look at the score for the 5th player using the following:

    defaults-nested read com.mycompany.myapp Players.@index(5).Score

Unlike the other set/array operators, we can also use this to set values. To change the score for that player, you can do:

    defaults-nested write com.mycompany.myapp Players.@index(5).Score 32768

### Real-World Examples

This was written to support creating an Xcode build script for my project whereby I could automatically update a static text 'Version' attribute in my app's preferences bundle. Reading the CFBundleShortVersionString from my Info.plist is simple enough, but writing it was problematic since the settings bundle's Root.plist uses nesting.

Placing a copy of this application at my project's root folder and installing the following as a *_ZSH_* run-script build phase allows me to do this.

    typeset INFO_PLIST=`echo ${INFOPLIST_FILE} | cut -d. -f1`
    
	"${PROJECT_DIR}/defaults-nested" write "${PROJECT_DIR}/Settings.bundle/Root" "PreferenceSpecifiers.@index(0).DefaultValue" `defaults read "${PROJECT_DIR}/${INFO_PLIST}" CFBundleShortVersionString`

Note that it is important that you use ZSH for this-- the 'typeset' command comes from there.

In my example the version number is the first item in my settings, so I use `@index(0)`. You'll need to change that to suit your own setup.
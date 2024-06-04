        # The ScopeData module
>
## Table of Contents
[Purpose](#purpose)  
[Method diagnostic()](#method-diagnostic)  
[Method start-scope( :$starter!, :$title, :$verbatim )](#method-start-scope-starter-title-verbatim-)  
[Method end-scope](#method-end-scope)  
[multi method config(%h)](#multi-method-configh)  
[multi method config( --&gt; Hash )](#multi-method-config----hash-)  
[multi method aliases(%h)](#multi-method-aliasesh)  
[multi method aliases( --&gt; Hash )](#multi-method-aliases----hash-)  
[method last-starter](#method-last-starter)  
[multi method last-title()](#multi-method-last-title)  
[multi method last-title( $s )](#multi-method-last-title-s-)  
[multi method verbatim()](#multi-method-verbatim)  
[multi method verbatim( :called-by($)! )](#multi-method-verbatim-called-by-)  
[multi method item-inc( $level --&gt; Str )](#multi-method-item-inc-level----str-)  
[multi method item-reset()](#multi-method-item-reset)  
[multi method defn-inc( --&gt; Str )](#multi-method-defn-inc----str-)  
[multi method defn-reset()](#multi-method-defn-reset)  

----
# Purpose
RakuDoc v2 introduces the concept of a block scope. The choice of terminology is to avoid some of the complexities of Raku's 'lexical scope'.

Basically a block scope is started by a `=begin BLOCKNAME` and ended by a `=end BLOCKNAME`. 

Within a block scope, several directives may affect other RakuDoc features within the same block, such as `=config` and `=alias`.

Once the block has ended, the effect of such directives end.

The ScopedData class was written to track and handle this sort of behaviour.

Typically only one ScopedData object is instantiated.

The following pieces of information are tracked:

*  starter - the block that starts a scope

*  titles - the title of the block starting the scope

*  config - the accumulated config data

	*  config data is a hash for each block

	*  the value for each block is the metadata option available for such a block

*  alias - alias defined for the scope

*  items-numeration - the current numeration for items

*  defns-numeration - the current numeration for defns

## Method diagnostic()
Provides information about all block scopes. A ScopeData object has an attribute `debug`. If set to True then diagnostic is called by `start-scope` and `end-scope`.

## Method `start-scope( :$starter!, :$title, :$verbatim ) `
Starts a new scope. When a scope is started, all the previous information is copied.

This information can be changed within the scope.

If `verbatim` is set, then all strings will be rendered without removing spaces or new lines.

## Method end-scope
Changes to items tracked by the object are forgotten.

## `multi method config(%h)`
Add key/value pair to the existing scope's config

## `multi method config( --&gt; Hash )`
Get the current scope's config

## `multi method aliases(%h)`
Add key/value pair to the existing scope's aliases

## `multi method aliases( --&gt; Hash )`
Get the current scope's aliases

## `method last-starter `
Return the last starter block

## `multi method last-title() `
Return the most recent title

## `multi method last-title( $s )`
Change the title for the current block

## `multi method verbatim()`
Change the state of the verbatim flag to True

## `multi method verbatim( :called-by($)! )`
Which block set the verbatim flag

## `multi method item-inc( $level --&gt; Str )`
Increment the item numeration at the required level, returns the result. See [Numeration module](/Numeration.md) for more detail

## `multi method item-reset()`
Reset the item numeration altogether

## `multi method defn-inc( --&gt; Str )`
Increment the defn numeration, only one level

## `multi method defn-reset()`
Reset the defn numeration







----
Rendered from ScopedData at 2024-06-04T22:25:03Z
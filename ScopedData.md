
# The ScopeData module

----

## Table of Contents
<a href="#Purpose">Purpose</a>   
  - <a href="#Method_diagnostic()">Method diagnostic()</a>   
  - <a href="#Method_`_start-scope(_:$starter!,_:$title,_:$verbatim_)_`">Method ` start-scope( :$starter!, :$title, :$verbatim ) `</a>   
  - <a href="#Method_end-scope">Method end-scope</a>   
  - <a href="#`_multi_method_config(%h)`">` multi method config(%h)`</a>   
  - <a href="#`_multi_method_config(_-->_Hash_)`">` multi method config( --> Hash )`</a>   
  - <a href="#`_multi_method_aliases(%h)`">` multi method aliases(%h)`</a>   
  - <a href="#`_multi_method_aliases(_-->_Hash_)`">` multi method aliases( --> Hash )`</a>   
  - <a href="#`_method_last-starter_`">` method last-starter `</a>   
  - <a href="#`_multi_method_last-title()_`">` multi method last-title() `</a>   
  - <a href="#`_multi_method_last-title(_$s_)`">` multi method last-title( $s )`</a>   
  - <a href="#`_multi_method_verbatim()`">` multi method verbatim()`</a>   
  - <a href="#`_multi_method_verbatim(_:called-by($)!_)`">` multi method verbatim( :called-by($)! )`</a>   
  - <a href="#`_multi_method_item-inc(_$level_-->_Str_)`">` multi method item-inc( $level --> Str )`</a>   
  - <a href="#`_multi_method_item-reset()`">` multi method item-reset()`</a>   
  - <a href="#`_multi_method_defn-inc(_-->_Str_)`">` multi method defn-inc( --> Str )`</a>   
  - <a href="#`_multi_method_defn-reset()`">` multi method defn-reset()`</a>   
<a href="#Credits">Credits</a>   


----

## Purpose<div id="Purpose"> </div>
RakuDoc v2 introduces the concept of a block scope. The choice of terminology is to avoid some of the complexities of Raku's 'lexical scope'. 

Basically a block scope is started by a `=begin BLOCKNAME` and ended by a `=end BLOCKNAME`. 

Within a block scope, several directives may affect other RakuDoc features within the same block, such as `=config` and `=alias`. 

Once the block has ended, the effect of such directives end. 

The ScopedData class was written to track and handle this sort of behaviour. 

Typically only one ScopedData object is instantiated. 

The following pieces of information are tracked: 



&nbsp;&nbsp;• starter - the block that starts a scope  
&nbsp;&nbsp;• titles - the title of the block starting the scope  
&nbsp;&nbsp;• config - the accumulated config data  
&nbsp;&nbsp;&nbsp;&nbsp;▹ config data is a hash for each block  
&nbsp;&nbsp;&nbsp;&nbsp;▹ the value for each block is the metadata option available for such a block  
&nbsp;&nbsp;• alias - alias defined for the scope  
&nbsp;&nbsp;• items-numeration - the current numeration for items  
&nbsp;&nbsp;• defns-numeration - the current numeration for defns  


### Method diagnostic()<div id="Method_diagnostic()"> </div>
Provides information about all block scopes. A ScopeData object has an attribute `debug`. If set to True then diagnostic is called by `start-scope` and `end-scope`. 



### Method ` start-scope( :$starter!, :$title, :$verbatim ) `<div id="Method_`_start-scope(_:$starter!,_:$title,_:$verbatim_)_`"> </div>
Starts a new scope. When a scope is started, all the previous information is copied. 

This information can be changed within the scope. 

If `verbatim` is set, then all strings will be rendered without removing spaces or new lines. 



### Method end-scope<div id="Method_end-scope"> </div>
Changes to items tracked by the object are forgotten. 



### ` multi method config(%h)`<div id="`_multi_method_config(%h)`"> </div>
Add key/value pair to the existing scope's config 



### ` multi method config( --> Hash )`<div id="`_multi_method_config(_-->_Hash_)`"> </div>
Get the current scope's config 



### ` multi method aliases(%h)`<div id="`_multi_method_aliases(%h)`"> </div>
Add key/value pair to the existing scope's aliases 



### ` multi method aliases( --> Hash )`<div id="`_multi_method_aliases(_-->_Hash_)`"> </div>
Get the current scope's aliases 



### ` method last-starter `<div id="`_method_last-starter_`"> </div>
Return the last starter block 



### ` multi method last-title() `<div id="`_multi_method_last-title()_`"> </div>
Return the most recent title 



### ` multi method last-title( $s )`<div id="`_multi_method_last-title(_$s_)`"> </div>
Change the title for the current block 



### ` multi method verbatim()`<div id="`_multi_method_verbatim()`"> </div>
Change the state of the verbatim flag to True 



### ` multi method verbatim( :called-by($)! )`<div id="`_multi_method_verbatim(_:called-by($)!_)`"> </div>
Which block set the verbatim flag 



### ` multi method item-inc( $level --> Str )`<div id="`_multi_method_item-inc(_$level_-->_Str_)`"> </div>
Increment the item numeration at the required level, returns the result. See [Numeration module](Numeration.md) for more detail 



### ` multi method item-reset()`<div id="`_multi_method_item-reset()`"> </div>
Reset the item numeration altogether 



### ` multi method defn-inc( --> Str )`<div id="`_multi_method_defn-inc(_-->_Str_)`"> </div>
Increment the defn numeration, only one level 



### ` multi method defn-reset()`<div id="`_multi_method_defn-reset()`"> </div>
Reset the defn numeration 


----
<div id="Credits"> </div>
----

## AUTHOR<div id="AUTHOR"> </div>
Richard Hainsworth aka finanalyst




----
<div id="Placement"> </div>
----

## VERSION<div id="VERSION"> </div>
v0.2.1





----

----

Rendered from docs/docs/ScopedData.rakudoc at 15:33 UTC on 2024-06-19

Source last modified at 15:32 UTC on 2024-06-19



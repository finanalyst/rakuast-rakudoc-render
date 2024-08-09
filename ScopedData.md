
# The ScopeData module

	Handling RakuDoc v2 block scope concept.

----

## Table of Contents

<a href="#Purpose">Purpose</a>   
<a href="#Credits">Credits</a>   



----

## Purpose<div id="Purpose"> </div>
<span class="para" id="22e11ec"></span>RakuDoc v2 introduces the concept of a block scope. The choice of terminology is to avoid some of the complexities of Raku's 'lexical scope'. 

<span class="para" id="be873ba"></span>Basically a block scope is started by a `=begin BLOCKNAME` and ended by a `=end BLOCKNAME`. 

<span class="para" id="533aa8f"></span>Within a block scope, several directives may affect other RakuDoc features within the same block, such as `=config` and `=alias`. 

<span class="para" id="1406b45"></span>Once the block has ended, the effect of such directives end. 

<span class="para" id="f4d4293"></span>The ScopedData class was written to track and handle this sort of behaviour. 

<span class="para" id="53256c7"></span>Typically only one ScopedData object is instantiated. 

<span class="para" id="69440e2"></span>The following pieces of information are tracked: 



&nbsp;&nbsp;• starter - the block that starts a scope  
&nbsp;&nbsp;• titles - the title of the block starting the scope  
&nbsp;&nbsp;• config - the accumulated config data  
&nbsp;&nbsp;&nbsp;&nbsp;▹ config data is a hash for each block  
&nbsp;&nbsp;&nbsp;&nbsp;▹ the value for each block is the metadata option available for such a block  
&nbsp;&nbsp;• alias - alias defined for the scope  
&nbsp;&nbsp;• items-numeration - the current numeration for items  
&nbsp;&nbsp;• defns-numeration - the current numeration for defns  


### Method diagnostic()<div id="Method_diagnostic()"> </div>
<span class="para" id="325852f"></span>Provides information about all block scopes. A ScopeData object has an attribute `debug`. If set to True then diagnostic is called by `start-scope` and `end-scope`. 



### <span class="para" id="d274ce7"></span>Method ` start-scope( :$starter!, :$title, :$verbatim ) ` 

<div id="<span_class="para"_id="d274ce7"></span>Method_`_start-scope(_:$starter!,_:$title,_:$verbatim_)_`"> </div>
<span class="para" id="dc30c3a"></span>Starts a new scope. When a scope is started, all the previous information is copied. 

<span class="para" id="c974347"></span>This information can be changed within the scope. 

<span class="para" id="6d35097"></span>If `verbatim` is set, then all strings will be rendered without removing spaces or new lines. 



### Method end-scope<div id="Method_end-scope"> </div>
<span class="para" id="e036cf7"></span>Changes to items tracked by the object are forgotten. 



### <span class="para" id="d31aef8"></span>` multi method config(%h)` 

<div id="<span_class="para"_id="d31aef8"></span>`_multi_method_config(%h)`"> </div>
<span class="para" id="c859a2b"></span>Add key/value pair to the existing scope's config 



### <span class="para" id="1e2a459"></span>` multi method config( --> Hash )` 

<div id="<span_class="para"_id="1e2a459"></span>`_multi_method_config(_-->_Hash_)`"> </div>
<span class="para" id="28d670f"></span>Get the current scope's config 



### <span class="para" id="a51c3cd"></span>` multi method aliases(%h)` 

<div id="<span_class="para"_id="a51c3cd"></span>`_multi_method_aliases(%h)`"> </div>
<span class="para" id="cd745fe"></span>Add key/value pair to the existing scope's aliases 



### <span class="para" id="9d61991"></span>` multi method aliases( --> Hash )` 

<div id="<span_class="para"_id="9d61991"></span>`_multi_method_aliases(_-->_Hash_)`"> </div>
<span class="para" id="80cf22d"></span>Get the current scope's aliases 



### <span class="para" id="1534183"></span>` method last-starter ` 

<div id="<span_class="para"_id="1534183"></span>`_method_last-starter_`"> </div>
<span class="para" id="2da6349"></span>Return the last starter block 



### <span class="para" id="698cf07"></span>` multi method last-title() ` 

<div id="<span_class="para"_id="698cf07"></span>`_multi_method_last-title()_`"> </div>
<span class="para" id="b1d8fab"></span>Return the most recent title 



### <span class="para" id="ebe5b26"></span>` multi method last-title( $s )` 

<div id="<span_class="para"_id="ebe5b26"></span>`_multi_method_last-title(_$s_)`"> </div>
<span class="para" id="2d32bfd"></span>Change the title for the current block 



### <span class="para" id="015f39e"></span>` multi method verbatim()` 

<div id="<span_class="para"_id="015f39e"></span>`_multi_method_verbatim()`"> </div>
<span class="para" id="3a5fb49"></span>Change the state of the verbatim flag to True 



### <span class="para" id="c003b05"></span>` multi method verbatim( :called-by($)! )` 

<div id="<span_class="para"_id="c003b05"></span>`_multi_method_verbatim(_:called-by($)!_)`"> </div>
<span class="para" id="4519a04"></span>Which block set the verbatim flag 



### <span class="para" id="6df8b7c"></span>` multi method item-inc( $level --> Str )` 

<div id="<span_class="para"_id="6df8b7c"></span>`_multi_method_item-inc(_$level_-->_Str_)`"> </div>
<span class="para" id="07df0ae"></span>Increment the item numeration at the required level, returns the result. See [Numeration module](Numeration) for more detail 



### <span class="para" id="b7235a6"></span>` multi method item-reset()` 

<div id="<span_class="para"_id="b7235a6"></span>`_multi_method_item-reset()`"> </div>
<span class="para" id="6dd75d3"></span>Reset the item numeration altogether 



### <span class="para" id="a75664f"></span>` multi method defn-inc( --> Str )` 

<div id="<span_class="para"_id="a75664f"></span>`_multi_method_defn-inc(_-->_Str_)`"> </div>
<span class="para" id="37a8eea"></span>Increment the defn numeration, only one level 



### <span class="para" id="6f49046"></span>` multi method defn-reset()` 

<div id="<span_class="para"_id="6f49046"></span>`_multi_method_defn-reset()`"> </div>
<span class="para" id="b75a9fe"></span>Reset the defn numeration 


----

## Credits<div id="Credits"> </div>
Richard Hainsworth aka finanalyst




----

## VERSION<div id="VERSION_0"> </div>
v0.2.1





----

----

Rendered from docs/docs/ScopedData.rakudoc at 15:53 UTC on 2024-08-08

Source last modified at 09:38 UTC on 2024-08-07



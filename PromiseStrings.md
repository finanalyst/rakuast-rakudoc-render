
# PromiseStrings for templates

	How RakuAsT-RakuDoc-Render handles forward references or placement material that has not yet been rendered 

When `=place toc:*` is given in a RakuDoc source (eg at the top of a source), typically the source has not yet been completely rendered. 

The renderer actually renders a source into `PStr` or **PromiseStrings** rather than `Str`. As forward references become known, they are included in the text.

----

## Table of Contents
<a href="#PCell_and_PStr_classes">PCell and PStr classes</a>   
  - <a href="#Concatenation_to_PStr">Concatenation to PStr</a>   
  - <a href="#PStr_methods">PStr methods</a>   
    - <a href="#new()_and_new(_*@string_)">new() and new( *@string )</a>   
    - <a href="#debug_Calling_debug_on_a_**PStr**_will_stringify_the_object_together_with_information_about_any_**PCells**_inside_the_object.">debug Calling debug on a **PStr** will stringify the object together with information about any **PCells** inside the object.</a>   
    - <a href="#Method_strip_Goes_through_a_**PStr**_and_substitutes_any_expanded_**PCell**_with_its_Str_equivalent._All_Str_are_then_concatenated.">Method strip Goes through a **PStr** and substitutes any expanded **PCell** with its Str equivalent. All Str are then concatenated.</a>   
    - <a href="#Method_trim-trailing,_trim-leading,_trim">Method trim-trailing, trim-leading, trim</a>   
    - <a href="#Method_`_has-PCells(_-->_Bool_)_`">Method ` has-PCells( --> Bool ) `</a>   
    - <a href="#Method_`_segments(_-->_Int_)_`">Method ` segments( --> Int ) `</a>   
    - <a href="#Methods_`_lead(_-->Str_)_`_and_`_tail(_-->_Str_)_`">Methods ` lead( -->Str ) ` and ` tail( --> Str ) `</a>   
  - <a href="#PCell_methods">PCell methods</a>   
    - <a href="#debug">debug</a>   
<a href="#Credits">Credits</a>   


----

## PCell and PStr classes<div id="PCell_and_PStr_classes"> </div>
RakuDoc statements that make references to structures or data that have not been completely rendered embed the references in **PCells**, which will interpolate the rendering once known. 

Consequently, parameters to a template may contain a mixture of Raku *Str* and *PCells*, in an object of type called **PStr**. 

*PCells* should not be visible to the template user. 

If a *PStr* or *PCell* is stringified before the data has been rendered, its internal *id* and *UNAVAILABLE* will be the rendered result. 

Since the embedded content of a *PStr* may ony be available after a template has rendered, care must be taken not be stringify any of the parameters prematurely. 

Consequently, the return object from a template should be built from the parameter values using the concatenation operator `~`. 



### Concatenation to PStr<div id="Concatenation_to_PStr"> </div>
A PStr is built up by concatenating using the infix operator `~`. Assignment does not add to a PStr. Concatenation can be on the left or the right of the PStr and the result will depend on the type. 



&nbsp;&nbsp;• A PCell on the left or right is added to the start or end, respectively, of the PStr  
&nbsp;&nbsp;• Concatentating two PStr adds the right hand one to the left hand one, and returns the left hand one  
&nbsp;&nbsp;• Any other type on the left or right is coerced to a Str and added to the start/end of the PStr  
Since left concatenation has an effect on the PStr on the right, use `sink` to discard the return value, unless of course the return value is the last line of a block, in which case it is returned as the value of the block, eg., 


```
my PStr $p; $p ~= PCell.new( :s($a-supplier.Supply), :id<AAA> ); sink '<bold>' ~ $p
```


### PStr methods<div id="PStr_methods"> </div>
The following methods are defined for **PStr**. Unless specified, they result in a **PStr** allowing for chaining. 



#### new() and new( *@string )<div id="new()_and_new(_*@string_)"> </div>
Creates a new **PStr** either with no parameters, or a sequence of strings. 



#### debug Calling debug on a **PStr** will stringify the object together with information about any **PCells** inside the object.<div id="debug_Calling_debug_on_a_**PStr**_will_stringify_the_object_together_with_information_about_any_**PCells**_inside_the_object."> </div>


#### Method strip Goes through a **PStr** and substitutes any expanded **PCell** with its Str equivalent. All Str are then concatenated.<div id="Method_strip_Goes_through_a_**PStr**_and_substitutes_any_expanded_**PCell**_with_its_Str_equivalent._All_Str_are_then_concatenated."> </div>


#### Method trim-trailing, trim-leading, trim<div id="Method_trim-trailing,_trim-leading,_trim"> </div>
`strip` is first called, then trailing or leading space, respectively, are removed from final, initial strings in the **PStr**. `trim` calls both trim-trailing and trim-leading. 



#### Method ` has-PCells( --> Bool ) `<div id="Method_`_has-PCells(_-->_Bool_)_`"> </div>
Determines whether there are any unexpanded **PCell** in a **PStr**. 



#### Method ` segments( --> Int ) `<div id="Method_`_segments(_-->_Int_)_`"> </div>
Returns the number of segments (strings or **PCells**) in a **PStr** 



#### Methods ` lead( -->Str ) ` and ` tail( --> Str ) `<div id="Methods_`_lead(_-->Str_)_`_and_`_tail(_-->_Str_)_`"> </div>
These two methods of a *PStr* object return any of the **leading** or **tailing** (respectively) *Str* elements of the *PStr*. The elements are removed, and so should be concatenated back on after processing. 

For simplicity above, examples were given of pre- and post-processing templates, and treating the contents of `%prm` as *Str*. Since some parameters may contain *PStr*, more care is needed. For example, the post-processing should be done as follows: 


```
table => -> %prm, $tmpl { my $rv = $tmpl.prev; if $rv ~~ PStr { # get leading text my $lead = $rv.lead; # process the string, if it exists $lead.subst( / '<table' \s+ 'class="pod-table' /, '<table class="table is-centered'); # left concatenate onto the PStr $lead ~ $rv # concatenating to a PStr results in a PStr, which is the return object } else { $rv.subst( / '<table' \s+ 'class="pod-table' /, '<table class="table is-centered') } }
```


### PCell methods<div id="PCell_methods"> </div>
**PCells** should be invisible to the end user. However, if references are made that are not expanded, then a PCell will become visible. 

Typically, **PCell** instances are converted to Str as soon as possible. 



#### debug<div id="debug"> </div>
Provides information about a **PCell**. 


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

Rendered from docs/docs/PromiseStrings.rakudoc at 15:33 UTC on 2024-06-19

Source last modified at 15:32 UTC on 2024-06-19



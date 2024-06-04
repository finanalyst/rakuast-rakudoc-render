        # PromiseStrings for templates
>How RakuAsT-RakuDoc-Render handles forward references or placement material that has not yet been rendered


## Table of Contents
[PCell and PStr classes](#pcell-and-pstr-classes)  
[Concatenation to PStr](#concatenation-to-pstr)  
[PStr methods](#pstr-methods)  
[new() and new( *@string )](#new-and-new-string-)  
[debug Calling debug on a PStr will stringify the object together with information about any PCells inside the object.](#debug-calling-debug-on-a-pstr-will-stringify-the-object-together-with-information-about-any-pcells-inside-the-object)  
[Method strip Goes through a PStr and substitutes any expanded PCell with its Str equivalent. All Str are then concatenated.](#method-strip-goes-through-a-pstr-and-substitutes-any-expanded-pcell-with-its-str-equivalent-all-str-are-then-concatenated)  
[Method trim-trailing, trim-leading, trim](#method-trim-trailing-trim-leading-trim)  
[Method has-PCells( --&gt; Bool )](#method-has-pcells----bool-)  
[Method segments( --&gt; Int )](#method-segments----int-)  
[Methods lead( --&gt;Str )  and tail( --&gt; Str )](#methods-lead---str--and-tail----str-)  
[PCell methods](#pcell-methods)  
[debug](#debug)  

----
When `=place toc:*` is given in a RakuDoc source (eg at the top of a source), typically the source has not yet been completely rendered.

The renderer actually renders a source into `PStr` or **PromiseStrings** rather than `Str`. As forward references become known, they are included in the text.

# PCell and PStr classes
RakuDoc statements that make references to structures or data that have not been completely rendered embed the references in **PCells**, which will interpolate the rendering once known.

Consequently, parameters to a template may contain a mixture of Raku _Str_ and _PCells_, in an object of type called **PStr**.

_PCells_ should not be visible to the template user.

If a _PStr_ or _PCell_ is stringified before the data has been rendered, its internal _id_ and _UNAVAILABLE_ will be the rendered result.

Since the embedded content of a _PStr_ may ony be available after a template has rendered, care must be taken not be stringify any of the parameters prematurely.

Consequently, the return object from a template should be built from the parameter values using the concatenation operator `~`.

## Concatenation to PStr
A PStr is built up by concatenating using the infix operator `~`. Assignment does not add to a PStr. Concatenation can be on the left or the right of the PStr and the result will depend on the type.

*  A PCell on the left or right is added to the start or end, respectively, of the PStr

*  Concatentating two PStr adds the right hand one to the left hand one, and returns the left hand one

*  Any other type on the left or right is coerced to a Str and added to the start/end of the PStr

Since left concatenation has an effect on the PStr on the right, use `sink` to discard the return value, unless of course the return value is the last line of a block, in which case it is returned as the value of the block, eg.,

my PStr $p; $p ~= PCell.new( :s($a-supplier.Supply), :id<AAA> ); sink '<bold>' ~ $p

## PStr methods
The following methods are defined for **PStr**. Unless specified, they result in a **PStr** allowing for chaining.

### new() and new( *@string )
Creates a new **PStr** either with no parameters, or a sequence of strings.

### debug Calling debug on a **PStr** will stringify the object together with information about any **PCells** inside the object.
### Method strip Goes through a **PStr** and substitutes any expanded **PCell** with its Str equivalent. All Str are then concatenated.
### Method trim-trailing, trim-leading, trim
`strip` is first called, then trailing or leading space, respectively, are removed from final, initial strings in the **PStr**. `trim` calls both trim-trailing and trim-leading.

### Method `has-PCells( --&gt; Bool ) `
Determines whether there are any unexpanded **PCell** in a **PStr**.

### Method `segments( --&gt; Int ) `
Returns the number of segments (strings or **PCells**) in a **PStr**

### Methods `lead( --&gt;Str ) ` and `tail( --&gt; Str ) `
These two methods of a _PStr_ object return any of the **leading** or **tailing** (respectively) _Str_ elements of the _PStr_. The elements are removed, and so should be concatenated back on after processing.

For simplicity above, examples were given of pre- and post-processing templates, and treating the contents of `%prm` as _Str_. Since some parameters may contain _PStr_, more care is needed. For example, the post-processing should be done as follows:

table => -> %prm, $tmpl { my $rv = $tmpl.prev; if $rv ~~ PStr { # get leading text my $lead = $rv.lead; # process the string, if it exists $lead.subst( / '<table' \s+ 'class="pod-table' /, '<table class="table is-centered'); # left concatenate onto the PStr $lead ~ $rv # concatenating to a PStr results in a PStr, which is the return object } else { $rv.subst( / '<table' \s+ 'class="pod-table' /, '<table class="table is-centered') } }

## PCell methods
**PCells** should be invisible to the end user. However, if references are made that are not expanded, then a PCell will become visible.

Typically, **PCell** instances are converted to Str as soon as possible.

### debug
Provides information about a **PCell**.







----
Rendered from PromiseStrings at 2024-06-04T22:22:57Z
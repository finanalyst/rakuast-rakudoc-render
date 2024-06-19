
# Minimal documentation of RakuDoc::Render Module

----

## Table of Contents
<a href="#Overview">Overview</a>   
  - <a href="#Templates">Templates</a>   
  - <a href="#Process">Process</a>   
  - <a href="#Warnings">Warnings</a>   
  - <a href="#Customisability">Customisability</a>   
    - <a href="#Custom_blocks">Custom blocks</a>   
    - <a href="#Custom_markup_codes">Custom markup codes</a>   
      - <a href="#Markup_M">Markup M</a>   
      - <a href="#Markup_UNICODE[upper]">Markup UNICODE[upper]</a>   
    - <a href="#Global_data_accessible_in_templates">Global data accessible in templates</a>   
  - <a href="#Debugging">Debugging</a>   
    - <a href="#Debug_options">Debug options</a>   
<a href="#Environment_variables">Environment variables</a>   
<a href="#Credits">Credits</a>   


----

## Overview<div id="Overview"> </div>
The module contains the RakuDoc::Processor class. 

The class method 'render' is the principal one for rendering RakuDoc v2. The Raku compiler expects to call render with an AST and to return a Str. It can be called with the option `:pre-finalised` to get the processed data, see the example in [Debugging](Debugging). 

The aim is for a **RakuDoc::Processor** object (an **RPO**) to be as generic as possible, allowing for other classes to instantiate it, and to attach templates that will generate more specific formats, such as HTML, MarkDown, or EPub pages. 

An **RPO** relies on [Templates](Templates.md), [PromiseStrings](PromiseStrings.md), and [ScopedData](ScopedData.md). 

It is also necessary to have a good understanding of RakuDoc v2. 

Some [environment variables](Environment_variables) provide for some output control. 

The following describes choices that are left by RakuDoc v2 to the renderer. 



### Templates<div id="Templates"> </div>
An **RPO** contains a default set of Text templates. 

The aim of the text templates is that they are the lowest level templates needed to render any RakuDoc source. 

When a renderer is needed to output a new format, eg., HTML, the renderer instantiates an **RPO** and attaches new templates to it using the `add-template( Pair $p, :source )` method or the `add-templates( Hash $h, :source )` method. Setting the `source` option to some value will help determine which module introduced the templates. 

The design of the Templates object means that new additions to the object push the previous definition onto a linked list, and so they will always be available by default. 

The set of template keys needed to create a renderer is [tabulated here](default-text-templates.md). 

All aspects of the output can be defined using the templates. 



### Process<div id="Process"> </div>
The generic render method transforms the AST of the input file using a handle method for each type of Block and Markup code. A template exists for each block and markup code. 

After all the blocks have been processed, the Table of Contents, Index, and Footnotes are rendered, with templates for each item and for the list of items. 

Any forward references and numerations are then resolved. 

The intermediate structure of the processed file can then be accessed before it is finally rendered into a string. 

The final rendering is done by the 'final' template. 

Once a string has been obtained, it can be post-processed using the post-process method. For example, text output can be transformed by wrapping lines. 



### Warnings<div id="Warnings"> </div>
In order to offer the maximum flexibility to a RakuDoc author, if there is an error condition after the RakuDoc source has been compiled, a set of warnings are generated. 

By default these are rendered using the 'warnings' template, and the rendered version is appended to the output file. 



### Customisability<div id="Customisability"> </div>
RakuDoc allows for customisability. This renderer handles customisability via the template mechanism. 



#### Custom blocks<div id="Custom_blocks"> </div>
When custom block is detected according to the RakuDoc v2 spelling rules, an **RPO** will check whether a template exists with that name. 

If a template has been attached to an **RPO**, then the rendered content of the block (including rendered embedded RakuDoc instructions) will be provided to the template as `contents` and the verbatim contents with no renderering will be provided as `raw`. 

So a new block can be created by attaching a template with the blockname to the **RPO**. 



#### Custom markup codes<div id="Custom_markup_codes"> </div>
RakuDoc v2 allows for custom markup codes in two ways: 



&nbsp;&nbsp;• the ` M< DISPLAY | FUNCTION ; list of comma delimited strings > `  
&nbsp;&nbsp;• a single Unicode (not ASCII ) character with the *upper* property.  


##### Markup M<div id="Markup_M"> </div>
When a ` M< DISPLAY | FUNCTION ; LIST > ` is encountered, the renderer will look for a template named in the **__FUNCTION__** position. If no such template exists, the text will be rendered verbatim and a warning logged. 



##### Markup UNICODE[upper]<div id="Markup_UNICODE[upper]"> </div>
When some custom markup is encountered, the renderer will 



&nbsp;&nbsp;• check that the character, eg Ɵ (Greek Capital Theta), has the unicode property *Upper*;  
&nbsp;&nbsp;• look for a template called (eg) **markup-Ɵ**. For clarity, the Unicode character chosen for the markup code is prefixed by **markup-** in order to name the template.  
Thus in order to create a new markup code, create an appropriately named template and add it to the **RPO**. 



#### Global data accessible in templates<div id="Global_data_accessible_in_templates"> </div>
More information is available in [Templates](Templates.md). 

All templates can attach items to the Table of Contents, Index, Footnotes, and Warnings structures of the rendered source using the helper methods. 

The following helper methods are available: 



&nbsp;&nbsp;• add-to-toc( %h ), where %h is a hash with the following keys:  
&nbsp;&nbsp;&nbsp;&nbsp;▹ :caption(Str)  
&nbsp;&nbsp;&nbsp;&nbsp;▹ :target( Str )  
&nbsp;&nbsp;&nbsp;&nbsp;▹ :level( Int )  
&nbsp;&nbsp;• add-to-index( %h ), where %h is a hash with the following keys:  
&nbsp;&nbsp;&nbsp;&nbsp;▹ :contents(Str)  
&nbsp;&nbsp;&nbsp;&nbsp;▹ :target(Str)  
&nbsp;&nbsp;&nbsp;&nbsp;▹ :place( Str }  
&nbsp;&nbsp;• add-to-footnotes( %h ), where %h is a hash with the following keys:  
&nbsp;&nbsp;&nbsp;&nbsp;▹ :retTarget(Str)  
&nbsp;&nbsp;&nbsp;&nbsp;▹ :fnTarget(Str)  
&nbsp;&nbsp;&nbsp;&nbsp;▹ :fnNumber(Str}  
&nbsp;&nbsp;• add-to-warnings( $warning )  
In addition, within a template, it is possible to attach data to globals, and to retrieve the data in another template. 

For an example of this, see test **xt/030-customisation-data.rakutest**. (test number may be changed, but otherwise the filename will be the same). 



### Debugging<div id="Debugging"> </div>
When developing new templates or renderers based on an **RPO**, several debug options can be attached to the **RPO**, eg. 


```
    my RakuDoc::Processor $rdp .=new( :test );
    $rdp.debug( AstBlock, Templates);
    $ast = Q:to/QAST/.AST;
    =begin rakudoc
    =head This is a header

    Some text

    =end rakudoc
    QAST

    $rv = $rdp.render( $ast, :pre-finalised );
    'myOutput'.IO.spurt: $rdp.finalise
```
Commentary on the code 



&nbsp;&nbsp;• ` new( :test )` this attaches the test templates to the **RPO**  
&nbsp;&nbsp;• the list inside the debug method may contain several entities as described below  
&nbsp;&nbsp;• creation of an AST from a string, or it can be slurped in from a file.  
&nbsp;&nbsp;• ` :pre-finalised ` returns the RakuDoc::Processed object  
&nbsp;&nbsp;• if called with `:pre-finalised`, calling `finalise` returns a Str that can then be stored as a file.  


#### Debug options<div id="Debug_options"> </div>
The following options are available: 



&nbsp;&nbsp;• None removes all previous debugging  
&nbsp;&nbsp;• All adds all debugging options  
&nbsp;&nbsp;• AstBlock diagnostic whenever a new Block is called  
&nbsp;&nbsp;• BlockType information about which `RakuAST::Doc::Block` is being processed  
&nbsp;&nbsp;• Scoping produces scope level diagnostics when a new level is started/ended  
&nbsp;&nbsp;• Templates indicates which templates are called and the params they are called with  
&nbsp;&nbsp;• MarkUp like BlockType but gives the MarkUp letter  
It is also possible to get the result of one template (so as to reduce the amount of output information). This is done eg for the 'table' template: $rdp.verbose( 'table' ); $rv = $rdp.render( $ast, :pre-finalised ); 

The Test and Pretty options described in [the Templates documentation](Templates.md) can be set on an **RPO**, eg. $rdp.test( True ); $rdp.pretty( True ); 

Bear in mind that the **pretty** flag overrides the **test** flag, and both override the **debug** and **verbose** flags. 

----

## Environment variables<div id="Environment_variables"> </div>
By setting the environment variable POSTPROCESSING=1 the text output will be naively wrapped. 

For example, POSTPROCESSING=1 bin/RenderTextify --pretty rakudociem-ipsum 

If the environment variable WIDTH is also set, the text output will be wrapped to the value. 

WIDTH by default is set at 80 chars. To set at 70, use: POSTPROCESSING=1 WIDTH=70 bin/RenderTextify rakudociem-ipsum 


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

Rendered from docs/docs/Render.rakudoc at 15:33 UTC on 2024-06-19

Source last modified at 15:32 UTC on 2024-06-19



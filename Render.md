
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
<a href="#Paragraph_id">Paragraph id</a>   
<a href="#Credits">Credits</a>   


----

## Overview<div id="Overview"> </div>
<span id="2b8160a"></span>The module contains the RakuDoc::Processor class. 

<span id="939179f"></span>The class method 'render' is the principal one for rendering RakuDoc v2. The Raku compiler expects to call render with an AST and to return a Str. It can be called with the option `:pre-finalised` to get the processed data, see the example in [Debugging](Debugging). 

<span id="7fab93d"></span>The aim is for a **RakuDoc::Processor** object (an **RPO**) to be as generic as possible, allowing for other classes to instantiate it, and to attach templates that will generate more specific formats, such as HTML, MarkDown, or EPub pages. 

<span id="82c4107"></span>An **RPO** relies on [Templates](Templates.md), [PromiseStrings](PromiseStrings.md), and [ScopedData](ScopedData.md). 

<span id="dbba06d"></span>It is also necessary to have a good understanding of RakuDoc v2. 

<span id="23813ba"></span>Some [environment variables](Environment_variables) provide for some output control. 

<span id="685dcbf"></span>The following describes choices that are left by RakuDoc v2 to the renderer. 



### Templates<div id="Templates"> </div>
<span id="cc07ee6"></span>An **RPO** contains a default set of Text templates. 

<span id="214c828"></span>The aim of the text templates is that they are the lowest level templates needed to render any RakuDoc source. 

<span id="194d81d"></span>When a renderer is needed to output a new format, eg., HTML, the renderer instantiates an **RPO** and attaches new templates to it using the `add-template( Pair $p, :source )` method or the `add-templates( Hash $h, :source )` method. Setting the `source` option to some value will help determine which module introduced the templates. 

<span id="f31964f"></span>The design of the Templates object means that new additions to the object push the previous definition onto a linked list, and so they will always be available by default. 

<span id="810a9ef"></span>The set of template keys needed to create a renderer is [tabulated here](default-text-templates.md). 

<span id="2e881b0"></span>All aspects of the output can be defined using the templates. 



### Process<div id="Process"> </div>
<span id="f30be0b"></span>The generic render method transforms the AST of the input file using a handle method for each type of Block and Markup code. A template exists for each block and markup code. 

<span id="dce45f9"></span>After all the blocks have been processed, the Table of Contents, Index, and Footnotes are rendered, with templates for each item and for the list of items. 

<span id="75d7015"></span>Any forward references and numerations are then resolved. 

<span id="b5a857e"></span>The intermediate structure of the processed file can then be accessed before it is finally rendered into a string. 

<span id="9179577"></span>The final rendering is done by the 'final' template. 

<span id="b8b2717"></span>Once a string has been obtained, it can be post-processed using the post-process method. For example, text output can be transformed by wrapping lines. 



### Warnings<div id="Warnings"> </div>
<span id="9d7622b"></span>In order to offer the maximum flexibility to a RakuDoc author, if there is an error condition after the RakuDoc source has been compiled, a set of warnings are generated. 

<span id="f8a57a9"></span>By default these are rendered using the 'warnings' template, and the rendered version is appended to the output file. 



### Customisability<div id="Customisability"> </div>
<span id="389c5ca"></span>RakuDoc allows for customisability. This renderer handles customisability via the template mechanism. 



#### Custom blocks<div id="Custom_blocks"> </div>
<span id="96b5a64"></span>When custom block is detected according to the RakuDoc v2 spelling rules, an **RPO** will check whether a template exists with that name. 

<span id="ea1baa3"></span>If a template has been attached to an **RPO**, then the rendered content of the block (including rendered embedded RakuDoc instructions) will be provided to the template as `contents` and the verbatim contents with no renderering will be provided as `raw`. 

<span id="7ddea86"></span>So a new block can be created by attaching a template with the blockname to the **RPO**. 



#### Custom markup codes<div id="Custom_markup_codes"> </div>
<span id="cc3389a"></span>RakuDoc v2 allows for custom markup codes in two ways: 



&nbsp;&nbsp;• <span id="ee6c481"></span>the ` M< DISPLAY | FUNCTION ; list of comma delimited strings > ` 

  
&nbsp;&nbsp;• <span id="feb4d63"></span>a single Unicode (not ASCII ) character with the *upper* property. 

  


##### Markup M<div id="Markup_M"> </div>
<span id="d752c0c"></span>When a ` M< DISPLAY | FUNCTION ; LIST > ` is encountered, the renderer will look for a template named in the **__FUNCTION__** position. If no such template exists, the text will be rendered verbatim and a warning logged. 



##### Markup UNICODE[upper]<div id="Markup_UNICODE[upper]"> </div>
<span id="d42c4d4"></span>When some custom markup is encountered, the renderer will 



&nbsp;&nbsp;• <span id="c3bc1e9"></span>check that the character, eg Ɵ (Greek Capital Theta), has the unicode property *Upper*; 

  
&nbsp;&nbsp;• <span id="611aec8"></span>look for a template called (eg) **markup-Ɵ**. For clarity, the Unicode character chosen for the markup code is prefixed by **markup-** in order to name the template. 

  
<span id="e673df7"></span>Thus in order to create a new markup code, create an appropriately named template and add it to the **RPO**. 



#### Global data accessible in templates<div id="Global_data_accessible_in_templates"> </div>
<span id="221a62d"></span>More information is available in [Templates](Templates.md). 

<span id="094f0a8"></span>All templates can attach items to the Table of Contents, Index, Footnotes, and Warnings structures of the rendered source using the helper methods. 

<span id="dee143f"></span>The following helper methods are available: 



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
<span id="d3c6895"></span>In addition, within a template, it is possible to attach data to globals, and to retrieve the data in another template. 

<span id="c3819d9"></span>For an example of this, see test **xt/030-customisation-data.rakutest**. (test number may be changed, but otherwise the filename will be the same). 



### Debugging<div id="Debugging"> </div>
<span id="07bec4d"></span>When developing new templates or renderers based on an **RPO**, several debug options can be attached to the **RPO**, eg. 


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
<span id="a8b339d"></span>Commentary on the code 



&nbsp;&nbsp;• <span id="6d163d6"></span>` new( :test )` this attaches the test templates to the **RPO** 

  
&nbsp;&nbsp;• the list inside the debug method may contain several entities as described below  
&nbsp;&nbsp;• creation of an AST from a string, or it can be slurped in from a file.  
&nbsp;&nbsp;• <span id="e706ebf"></span>` :pre-finalised ` returns the RakuDoc::Processed object 

  
&nbsp;&nbsp;• <span id="b96ac93"></span>if called with `:pre-finalised`, calling `finalise` returns a Str that can then be stored as a file. 

  


#### Debug options<div id="Debug_options"> </div>
<span id="bce5bad"></span>The following options are available: 



&nbsp;&nbsp;• None removes all previous debugging  
&nbsp;&nbsp;• All adds all debugging options  
&nbsp;&nbsp;• AstBlock diagnostic whenever a new Block is called  
&nbsp;&nbsp;• <span id="f5131a2"></span>BlockType information about which `RakuAST::Doc::Block` is being processed 

  
&nbsp;&nbsp;• Scoping produces scope level diagnostics when a new level is started/ended  
&nbsp;&nbsp;• Templates indicates which templates are called and the params they are called with  
&nbsp;&nbsp;• MarkUp like BlockType but gives the MarkUp letter  
<span id="146e904"></span>It is also possible to get the result of one template (so as to reduce the amount of output information). This is done eg for the 'table' template: $rdp.verbose( 'table' ); $rv = $rdp.render( $ast, :pre-finalised ); 

<span id="7092363"></span>The Test and Pretty options described in [the Templates documentation](Templates.md) can be set on an **RPO**, eg. $rdp.test( True ); $rdp.pretty( True ); 

<span id="4acb082"></span>Bear in mind that the **pretty** flag overrides the **test** flag, and both override the **debug** and **verbose** flags. 

----

## Environment variables<div id="Environment_variables"> </div>
<span id="aa34249"></span>By setting the environment variable POSTPROCESSING=1 the text output will be naively wrapped. 

<span id="189b0ff"></span>For example, POSTPROCESSING=1 bin/RenderTextify --pretty rakudociem-ipsum 

<span id="d0c9c25"></span>If the environment variable WIDTH is also set, the text output will be wrapped to the value. 

<span id="b2879cf"></span>WIDTH by default is set at 80 chars. To set at 70, use: POSTPROCESSING=1 WIDTH=70 bin/RenderTextify rakudociem-ipsum 

----

## Paragraph id<div id="Paragraph_id"> </div>
<span id="d37a747"></span>Since sometimes it is necessary to target a specific paragraph, some paragraphs get an automated id based on the last Seven hex chars of the SHA1 encoding of its contents. 

<span id="cea9f65"></span>Seven chars should be adequate so long as the number of paragraphs in a single document is below 16,000. 

> <span id="80ce965"></span>Based on the expectation that we would see collision in a repository with 2^(2N) objects when using object names shortened to first N bits [Stackoverflow question](https://stackoverflow.com/questions/18134627/how-much-of-a-git-sha-is-generally-considered-necessary-to-uniquely-identify-a) 



<span id="ef6367d"></span>Long texts or books will probably need more to avoid a conflict. This can be done by setting `paragraph-id-length` in the %structure-data to the required number of hex digits. 


----
<div id="Credits"> </div>
----

## AUTHOR<div id="AUTHOR"> </div>
Richard Hainsworth aka finanalyst




----
<div id="Placement"> </div>
----

## VERSION<div id="VERSION"> </div>
v0.3.0





----

----

Rendered from docs/docs/Render.rakudoc at 21:39 UTC on 2024-06-28

Source last modified at 21:24 UTC on 2024-06-28



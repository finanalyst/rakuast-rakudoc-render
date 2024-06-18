
# RakuDoc renderer

	Renders RakuDoc sources into an output format dependent on templates

----

## Table of Contents
<a href="#Overview">Overview</a>   
<a href="#RenderTextify_utility">RenderTextify utility</a>   
<a href="#Troubleshooting">Troubleshooting</a>   
<a href="#Credits">Credits</a>   


----

## Overview<div id="Overview"> </div>
This module is intended to provide a generic renderer from RakuDoc v2 into text, but is designed to be easily extended to other output formats by subclassing. 

Two other formats, namely HTML and MarkDown, are ( & to be) provided in the distribution, see [RakuDoc::To::Markdown](RakuDoc-To-Markdown.md), **to be written**. 

This is software using bleeding edge Rakudo, so look ([at troubleshooting below](Troubleshooting)). 

The **canonical method** for generating rendered text is possible (which sends output to STDOUT, so pipe to a file), namely RAKUDO_RAKUAST=1 raku --rakudoc=Generic rakudociem-ipsum.rakudoc > store-output 

The file [rakudociem-ipsum.rakudoc](https://github.com/Raku/RakuDoc-GAMMA/blob/main/rakudociem-ipsum.rakudoc) is the file for testing RakuDoc v2 compliance. It can be obtained with: bin/get-compliance-document 

Another (easier?) way to render a RakuDoc file is using [RenderTextify](RenderTextify utility.md), which avoids some installation problems, stores the output and offers some other output options, eg. bin/RenderTextify rakudociem-ipsum 

(the .rakudoc extension may be omitted if desired) 

The two main documentation sources are: 



&nbsp;&nbsp;• [An overview of the generic renderer](Render.md)  
&nbsp;&nbsp;• [The templating system](Templates.md)  
Other modules are also documented: 



&nbsp;&nbsp;• [Processed - objects to keep track of intermediate state](Processed.md)  
&nbsp;&nbsp;• [PStr - Strings containing forward references](PromiseStrings.md)  
&nbsp;&nbsp;• [ScopedData - an object to keep track of data valid for a block scope](ScopedData.md)  
&nbsp;&nbsp;• [a table of the minimum set of templates to render any RakuDoc source](default-text-templates.md)  
&nbsp;&nbsp;• [a grammar for parsing the meta data of a Markup code](MarkUpMeta.md)  
&nbsp;&nbsp;• [an object for numerating items headings](Numeration.md)  
----

## RenderTextify utility<div id="RenderTextify_utility"> </div>
The utility `bin/RenderTexify` can be called with a RakuDoc source and it saves the result directly to a file, rather than to STDOUT. 

For example, bin/RenderTextify rakudociem-ipsum 

will produce the file rakudociem-ipsum.rakudoc.text 

The executable `bin/RenderTexify` can also be called with the flags `test` and `pretty` and the name of a file to render. The file is output to text files with the flag and `.text` appended to the name. The file format `.rakudoc` is assumed, and added if missing. 

For example, bin/RenderTextify --pretty rakudociem-ipsum 

will produce the file rakudociem-ipsum.rakudoc.pretty.text 

By setting the environment variable POSTPROCESSING=1 the text output will be naively wrapped. This option is still being developed. 

For example, POSTPROCESSING=1 bin/RenderTextify --pretty rakudociem-ipsum 

If the environment variable WIDTH is also set, the text output will be wrapped to the value. 

WIDTH by default is set at 80 chars. To set at 70, use: POSTPROCESSING=1 WIDTH=70 bin/RenderTextify rakudociem-ipsum 

----

## Troubleshooting<div id="Troubleshooting"> </div>
In order to get the RakuDoc render test file (rakudociem-ipsum) to work, a recent version of the Rakudoc compiler is needed: $ raku -v Welcome to Rakudo™ v2024.05-32-g5b44a64b2. Implementing the Raku® Programming Language v6.d. Built on MoarVM version 2024.05-5-gf48abb710. 

If the cannonical command above fails, perhaps with a message such as ===SORRY!=== This element has not been resolved. Type: RakuAST::Type::Simple 

but there is a local version of `RakuDoc::To::Generic` available, then try RAKUDO_RAKUAST=1 raku -I. -MRakuDoc::Render --rakudoc=Generic rakudociem-ipsum.rakudoc > store-output 

The command above may also generate an error, such as ===SORRY!=== Error while compiling ..... (OO::Monitors) Variable '$cond' is not declared. Perhaps you forgot a 'sub' if this was intended to be part of a signature? at .... ------> macro wait-condition(⏏$cond) is export { because the RakuAST compiler does not yet handle macros, and (OO::Monitors) uses them. 

The first step is to re-run the test files, eg., prove6 -I. 

This causes a recompilation of the modules in this distribution to be recompiled because the tests run `isa-ok` on each module. 

This is sometimes not sufficient. The next step is to use the utility `bin/force-compile` in the root of the repo. It deletes the `.precomp` files in the current directory, then recompiles the modules in the repo. 

Again try running the basic tests. 

Another method might be to run the `raku --rakudoc=...` command, but without 'RAKUDO_RAKUAST=1'. Expect errors because the current production version of Rakudo does not allow for extensive Unicode entities. 

However, this will compile `RakuDoc::Render` and its dependencies. 

Then run the command again but with 'RAKUDO_RAKUAST=1'. 


<div id="Credits"> </div>----

## AUTHOR<div id="AUTHOR"> </div>
Richard Hainsworth aka finanalyst




<div id="Placement"> </div>----

## VERSION<div id="VERSION"> </div>
v0.2.1





----

----

Rendered from docs/docs/README.rakudoc at 17:55 UTC on 2024-06-18

Source last modified at 17:12 UTC on 2024-06-18



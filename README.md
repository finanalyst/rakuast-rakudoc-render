
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
<span id="0fe6971"></span>This module is intended to provide a generic renderer from RakuDoc v2 into text, but is designed to be easily extended to other output formats by subclassing. 

<span id="483341c"></span>Two other formats, namely HTML and Markdown, are provided in the distribution, see [RakuDoc::To::Markdown](RakuDoc-To-HTML.md) and [RakuDoc::To::Markdown](RakuDoc-To-Markdown.md). 

<span id="0196e05"></span>This is software using bleeding edge Rakudo, so look ([at troubleshooting below](Troubleshooting)). For the time being: 



&nbsp;&nbsp;• clone the repo  
&nbsp;&nbsp;• <span id="433e7b6"></span>run `prove6 -I.` which will compile the submodules and dependences in the correct order. 

  
<span id="b23d08f"></span>The **canonical method** for generating rendered text is possible (which sends output to STDOUT, so pipe to a file), namely RAKUDO_RAKUAST=1 raku --rakudoc=Generic rakudociem-ipsum.rakudoc > store-output 

<span id="8ba4e87"></span>The file [rakudociem-ipsum.rakudoc](https://github.com/Raku/RakuDoc-GAMMA/blob/main/rakudociem-ipsum.rakudoc) is the file for testing RakuDoc v2 compliance. It can be obtained with: bin/get-compliance-document 

<span id="48153d4"></span>Another (easier?) way to render a RakuDoc file is using [RenderTextify](RenderTextify utility.md), which avoids some installation problems, stores the output and offers some other output options, eg. bin/RenderTextify rakudociem-ipsum 

<span id="416d7d2"></span>(the .rakudoc extension may be omitted if desired) 

<span id="9ae1d19"></span>The two main documentation sources are: 



&nbsp;&nbsp;• <span id="94ec4ac"></span>[An overview of the generic renderer](Render.md) 

  
&nbsp;&nbsp;• <span id="c11632c"></span>[The templating system](Templates.md) 

  
<span id="525d438"></span>Other modules are also documented: 



&nbsp;&nbsp;• <span id="8ca950d"></span>[Processed - objects to keep track of intermediate state](Processed.md) 

  
&nbsp;&nbsp;• <span id="86c99ef"></span>[PStr - Strings containing forward references](PromiseStrings.md) 

  
&nbsp;&nbsp;• <span id="b75e585"></span>[ScopedData - an object to keep track of data valid for a block scope](ScopedData.md) 

  
&nbsp;&nbsp;• <span id="52bf018"></span>[a table of the minimum set of templates to render any RakuDoc source](default-text-templates.md) 

  
&nbsp;&nbsp;• <span id="4812438"></span>[a grammar for parsing the meta data of a Markup code](MarkUpMeta.md) 

  
&nbsp;&nbsp;• <span id="2fa4035"></span>[an object for numerating items headings](Numeration.md) 

  
----

## RenderTextify utility<div id="RenderTextify_utility"> </div>
<span id="ab8d800"></span>The utility `bin/RenderTexify` can be called with a RakuDoc source and it saves the result directly to a file, rather than to STDOUT. 

<span id="015a74e"></span>For example, bin/RenderTextify rakudociem-ipsum 

<span id="649dc5b"></span>will produce the file rakudociem-ipsum.rakudoc.text 

<span id="44c7693"></span>The executable `bin/RenderTexify` can also be called with the flags `test` and `pretty` and the name of a file to render. The file is output to text files with the flag and `.text` appended to the name. The file format `.rakudoc` is assumed, and added if missing. 

<span id="99ab30b"></span>For example, bin/RenderTextify --pretty rakudociem-ipsum 

<span id="49a5b48"></span>will produce the file rakudociem-ipsum.rakudoc.pretty.text 

<span id="9f11110"></span>By setting the environment variable POSTPROCESSING=1 the text output will be naively wrapped. This option is still being developed. 

<span id="189b0ff"></span>For example, POSTPROCESSING=1 bin/RenderTextify --pretty rakudociem-ipsum 

<span id="d0c9c25"></span>If the environment variable WIDTH is also set, the text output will be wrapped to the value. 

<span id="b2879cf"></span>WIDTH by default is set at 80 chars. To set at 70, use: POSTPROCESSING=1 WIDTH=70 bin/RenderTextify rakudociem-ipsum 

----

## Troubleshooting<div id="Troubleshooting"> </div>
<span id="50d54e8"></span>In order to get the RakuDoc render test file (rakudociem-ipsum) to work, a recent version of the Rakudoc compiler is needed, after v2024.06. 

<span id="574a9a7"></span>If the cannonical command above fails, perhaps with a message such as ===SORRY!=== This element has not been resolved. Type: RakuAST::Type::Simple 

<span id="d58c2b1"></span>but there is a local version of `RakuDoc::To::Generic` available, then try RAKUDO_RAKUAST=1 raku -I. -MRakuDoc::Render --rakudoc=Generic rakudociem-ipsum.rakudoc > store-output 

<span id="ffefa39"></span>The command above may also generate an error, such as ===SORRY!=== Error while compiling ..... (OO::Monitors) Variable '$cond' is not declared. Perhaps you forgot a 'sub' if this was intended to be part of a signature? at .... ------> macro wait-condition(⏏$cond) is export { because the RakuAST compiler does not yet handle macros, and (OO::Monitors) uses them. 

<span id="8113c36"></span>The first step is to re-run the test files, eg., prove6 -I. 

<span id="d9dd54f"></span>This causes a recompilation of the modules in this distribution to be recompiled because the tests run `isa-ok` on each module. 

<span id="4abdf35"></span>This is sometimes not sufficient. The next step is to use the utility `bin/force-compile` in the root of the repo. It deletes the `.precomp` files in the current directory, then recompiles the modules in the repo. 

<span id="fd0a4cf"></span>Again try running the basic tests. 

<span id="aa237b8"></span>Another method might be to run the `raku --rakudoc=...` command, but without 'RAKUDO_RAKUAST=1'. Expect errors because the current production version of Rakudo does not allow for extensive Unicode entities. 

<span id="2add0a6"></span>However, this will compile `RakuDoc::Render` and its dependencies. 

<span id="42b626a"></span>Then run the command again but with 'RAKUDO_RAKUAST=1'. 


----
<div id="Credits"> </div>
----

## AUTHOR<div id="AUTHOR"> </div>
Richard Hainsworth aka finanalyst




----
<div id="Placement"> </div>
----

## VERSION<div id="VERSION"> </div>
v0.3.1





----

----

Rendered from docs/docs/README.rakudoc at 21:39 UTC on 2024-06-28

Source last modified at 19:50 UTC on 2024-06-28



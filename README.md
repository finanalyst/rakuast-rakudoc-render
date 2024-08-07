
# RakuDoc renderer

	Renders RakuDoc sources into an output format dependent on templates

----

## Table of Contents

<a href="#SYNOPSIS">SYNOPSIS</a>   
<a href="#Overview">Overview</a>   
&nbsp;&nbsp;- <a href="#Table_of_outputs_and_renderers">Table of outputs and renderers</a>   
<a href="#Documentation">Documentation</a>   
<a href="#RenderTextify_utility">RenderTextify utility</a>   
<a href="#Wrapping">Wrapping</a>   
<a href="#Troubleshooting">Troubleshooting</a>   
<a href="#Credits">Credits</a>   



----

## SYNOPSIS<div id="SYNOPSIS"> </div>
&nbsp;&nbsp;• Clone the repository and submodule  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="e52a3a8"></span>`git clone https://github.com/finanalyst/rakuast-rakudoc-render.git rrr` 

  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="1fa8ad9"></span>`cd rrr && git submodule init` 

  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="e4ec964"></span>`git submodule update` 

  
&nbsp;&nbsp;• Install using zef as follows (flag is important)  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="8f021ca"></span>`zef install . -/precompile-install` 

  
<span class="para" id="351913a"></span>Note that `zef` runs the tests in `t/`, and those cause compilation of the modules in the distribution. 




----

## Overview<div id="Overview"> </div>
<span class="para" id="887ec44"></span>This distribution is intended to provide several renderers from RakuDoc v2 into commonly used output formats. 

<span class="para" id="288415f"></span>The basic render engine is `RakuDoc::Render`, which renders into Text. It is designed to be extended to other output formats by subclassing. 

<span class="para" id="da74a31"></span>Currently, the other renderers in this distribution are: 



### Table of outputs and renderers<div id="Table_of_outputs_and_renderers"> </div>
 | **Output** | **Renderer** | **Documentation** |
| :---: | :---: | :---: |
 | Text | <span class="para" id="c482061"></span>`RakuDoc::To::Generic` | <span class="para" id="a467a99"></span>[a wrapper for *RakuDoc::Render*](Render) |
 | Markdown | <span class="para" id="b82d661"></span>`RakuDoc::To::Markdown` | <span class="para" id="783db0c"></span>[Markdown](RakuDoc-To-Markdown) |
 | HTML | <span class="para" id="4bbd661"></span>`RakuDoc::To::HTML` | <span class="para" id="5200ddf"></span>[A minimal, single file, 'all in' HTML](RakuDoc-To-HTML) |
 | HTML-Extra | in development | HTML output using Bulma CSS, Graphviz, Leaflet-Maps, Latex, assumes internet |
<span class="para" id="c0e52b5"></span>This is software using bleeding edge Rakudo, so look [at troubleshooting below](Troubleshooting). 

<span class="para" id="a9d8493"></span>Using the *Generic* renderer, the **canonical method** for generating rendered text is possible (which sends output to STDOUT, so pipe to a file), namely 


```
RAKUDO_RAKUAST=1 raku --rakudoc=Generic rakudociem-ipsum.rakudoc > store-output
```
<span class="para" id="81696a6"></span>Some [naive wrapping and width modification](Wrapping) is possible using environment variables. 

<span class="para" id="880a886"></span>The file [rakudociem-ipsum.rakudoc](https://github.com/Raku/RakuDoc-GAMMA/blob/main/rakudociem-ipsum.rakudoc) is the file for testing RakuDoc v2 compliance. It can be obtained with: 


```
bin/get-compliance-document
```
<span class="para" id="7599a17"></span>`rakudociem-ipsum.rakudoc` is contained in the submodule `rakudoc-compliance` with a link in `resources/compliance`. 

<span class="para" id="084d11c"></span>In order to avoid environment variables, eg for Windows, a RakuDoc file can be rendered to Text using the [RenderTextify](RenderTextify_utility). It avoids some installation problems, stores the output and offers some other output options, eg. 


```
bin/RenderTextify rakudociem-ipsum
```
<span class="para" id="416d7d2"></span>(the .rakudoc extension may be omitted if desired) 


----

## Documentation<div id="Documentation"> </div>
<span class="para" id="9ae1d19"></span>The two main documentation sources are: 



&nbsp;&nbsp;• <span class="para" id="4759936"></span>[An overview of the generic renderer](Render) 

  
&nbsp;&nbsp;• <span class="para" id="c06fad3"></span>[The templating system](Templates) 

  
<span class="para" id="525d438"></span>Other modules are also documented: 



&nbsp;&nbsp;• <span class="para" id="d531605"></span>[Processed - objects to keep track of intermediate state](Processed) 

  
&nbsp;&nbsp;• <span class="para" id="2753916"></span>[PStr - Strings containing forward references](PromiseStrings) 

  
&nbsp;&nbsp;• <span class="para" id="ae4d406"></span>[ScopedData - an object to keep track of data valid for a block scope](ScopedData) 

  
&nbsp;&nbsp;• <span class="para" id="0f6a7ab"></span>[a table of the minimum set of templates to render any RakuDoc source](default-text-templates) 

  
&nbsp;&nbsp;• <span class="para" id="17fd6d8"></span>[a grammar for parsing the meta data of a Markup code](MarkUpMeta) 

  
&nbsp;&nbsp;• <span class="para" id="71c42e9"></span>[an object for numerating items headings](Numeration) 

  

----

## RenderTextify utility<div id="RenderTextify_utility"> </div>
<span class="para" id="ab8d800"></span>The utility `bin/RenderTexify` can be called with a RakuDoc source and it saves the result directly to a file, rather than to STDOUT. 

<span class="para" id="c976c61"></span>For example, 


```
bin/RenderTextify rakudociem-ipsum
```
<span class="para" id="6d462ae"></span>will produce the file 


```
rakudociem-ipsum.rakudoc.text
```
<span class="para" id="3fbe458"></span>The executable `bin/RenderTexify` can also be called with the flags `test` and `pretty` and the name of a file to render. The use case of these options is to see what templates receive from the rendering engine when developing new templates. 

<span class="para" id="63bbd59"></span>The file is output to text files with the flag and `.text` appended to the name. The file format `.rakudoc` is assumed, and added if missing. 

<span class="para" id="c976c61"></span>For example, 


```
bin/RenderTextify --pretty rakudociem-ipsum
```
<span class="para" id="6d462ae"></span>will produce the file 


```
rakudociem-ipsum.rakudoc.pretty.text
```

----

## Wrapping<div id="Wrapping"> </div>
<span class="para" id="1860541"></span>The text output will be naively wrapped (the algorithm is still being developed), either by setting the environment variable POSTPROCESSING=1 or using RenderTextify. For example, 


```
POSTPROCESSING=1 RAKUDO_RAKUAST=1 raku --rakudoc=Generic doc.rakudoc > store-output
```
<span class="para" id="7fa2f84"></span>or 


```
bin/RenderTextify --post-processing doc
```
<span class="para" id="96f3270"></span>If the environment variable WIDTH (--width) is also set, the text output will be wrapped to the value. WIDTH by default is set at 80 chars. To set at 70, use: 


```
POSTPROCESSING=1 WIDTH=70 RAKUDO_RAKUAST=1 raku --rakudoc=Generic doc.rakudoc > store-output
```
<span class="para" id="7fa2f84"></span>or 


```
bin/RenderTextify --post-processing --width=70 doc
```

----

## Troubleshooting<div id="Troubleshooting"> </div>
<span class="para" id="50d54e8"></span>In order to get the RakuDoc render test file (rakudociem-ipsum) to work, a recent version of the Rakudoc compiler is needed, after v2024.06. 

<span class="para" id="53029b4"></span>If the cannonical command above fails, perhaps with a message such as 


```
===SORRY!===
    This element has not been resolved. Type: RakuAST::Type::Simple
```
<span class="para" id="347a187"></span>then try 


```
RAKUDO_RAKUAST=1 raku -I. -MRakuDoc::Render --rakudoc=Generic rakudociem-ipsum.rakudoc > store-output
```
<span class="para" id="4c23d02"></span>The command above may also generate an error, such as 


```
    ===SORRY!=== Error while compiling ..... (OO::Monitors)
    Variable '$cond' is not declared.  Perhaps you forgot a 'sub' if this
    was intended to be part of a signature?
    at ....
    ------> macro wait-condition(⏏$cond) is export {
because the RakuAST compiler does not yet handle macros, and (OO::Monitors) uses them.
```
<span class="para" id="87645ef"></span>The first step is to re-run the test files, eg., 


```
prove6 -I.
```
<span class="para" id="d9dd54f"></span>This causes a recompilation of the modules in this distribution to be recompiled because the tests run `isa-ok` on each module. 

<span class="para" id="e0ec639"></span>This is sometimes not sufficient. The next step is to use the utility `bin/force-compile` in the root of the repo. It deletes the `.precomp` files in the current directory, and runs `prove6 -I.`. 


----

## Credits<div id="Credits"> </div>
Richard Hainsworth aka finanalyst




----

## VERSION<div id="VERSION_0"> </div>
v0.3.1





----

----

Rendered from docs/docs/README.rakudoc at 15:53 UTC on 2024-08-08

Source last modified at 09:38 UTC on 2024-08-07



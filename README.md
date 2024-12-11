
# RakuDoc renderer

	Renders RakuDoc sources into an output format dependent on templates

----

## Table of Contents

<a href="#SYNOPSIS">SYNOPSIS</a>   
<a href="#Overview">Overview</a>   
<a href="#Documentation">Documentation</a>   
<a href="#RenderTextify_utility">RenderTextify utility</a>   
<a href="#Wrapping">Wrapping</a>   
<a href="#RenderDocs_utility">RenderDocs utility</a>   
<a href="#Troubleshooting">Troubleshooting</a>   
<a href="#Credits">Credits</a>   



----

## SYNOPSIS<div id="SYNOPSIS"> </div>
&nbsp;&nbsp;• Clone the repository  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="fc2dfe0"></span>`git clone https://github.com/finanalyst/rakuast-rakudoc-render.git` 

  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="6846695"></span>`cd rakuast-rakudoc-render` 

  
&nbsp;&nbsp;• Install using zef as follows (flag is important)  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="8f021ca"></span>`zef install . -/precompile-install` 

  
<span class="para" id="351913a"></span>Note that `zef` runs the tests in `t/`, and those cause compilation of the modules in the distribution. 




----

## Overview<div id="Overview"> </div>
<span class="para" id="887ec44"></span>This distribution is intended to provide several renderers from RakuDoc v2 into commonly used output formats. 

<span class="para" id="cb2e9a3"></span>The basic render engine is `RakuDoc::Render`, which renders a RakuDoc source into text for display on a terminal. 

<span class="para" id="221bd19"></span>The Renderer class is designed to be extended to other output formats by subclassing. 

<span class="para" id="c0e52b5"></span>This is software using bleeding edge Rakudo, so look [at troubleshooting below](Troubleshooting). 

<span class="para" id="a9d8493"></span>Using the *Generic* renderer, the **canonical method** for generating rendered text is possible (which sends output to STDOUT, so pipe to a file), namely 


```
RAKUDO_RAKUAST=1 raku --rakudoc=Generic rakudociem-ipsum.rakudoc > store-output


```
<span class="para" id="81696a6"></span>Some [naive wrapping and width modification](Wrapping) is possible using environment variables. 

<span class="para" id="40878f3"></span>The file [rakudociem-ipsum.rakudoc](https://github.com/Raku/RakuDoc-GAMMA/blob/main/compliance-document/rakudociem-ipsum.rakudoc) is the file for testing RakuDoc v2 compliance. An uptodate copy can be obtained with: 


```
bin/get-compliance-document


```
<span class="para" id="f4a51f3"></span>A copy of `rakudociem-ipsum.rakudoc` is also contained in `resources/compliance-rendering`, together with renderings of the file using the output renderers in this distribution. 

<span class="para" id="bba4fc2"></span>In order to avoid environment variables, eg for Windows, a RakuDoc file can be rendered to Text using the [RenderTextify](RenderTextify utility). It avoids some installation problems, stores the output and offers some other output options, eg. 


```
bin/RenderTextify rakudociem-ipsum


```
<span class="para" id="416d7d2"></span>(the .rakudoc extension may be omitted if desired) 

<span class="para" id="c26bad9"></span>Rendering into the other output formats provided in this distribution can be done using [RenderDocs](RenderDocs utility). By default, sources are located in `docs/` and rendered to the current working directory into MarkDown, eg., 


```
bin/RenderDocs README


```

----

## Documentation<div id="Documentation"> </div>
<span class="para" id="4a6e64e"></span>All documentation can be found at [finanalyst.github.io](https://finanalyst.github.io). 

<span class="para" id="9ae1d19"></span>The two main documentation sources are: 



&nbsp;&nbsp;• <span class="para" id="8c91600"></span>[An overview of the generic renderer](https://finanalyst.github.io/Render) 

  
&nbsp;&nbsp;• <span class="para" id="0b80cbf"></span>[The templating system](https://finanalyst.github.io/Templates) 

  

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
<span class="para" id="c90fe6d"></span>The utility can also be used for debugging new templates. For more information, see the Render and Templates documents. To get all the debugging information, and information on the template for `C-markup` try 


```
bin/RenderTextify --debug='All' --verbose='C-markup' doc


```

----

## RenderDocs utility<div id="RenderDocs_utility"> </div>
<span class="para" id="05fee90"></span>*RenderDoc* is similar to RenderTextify, but uses the other formats in this distribution, namely 



&nbsp;&nbsp;• <span class="para" id="5fa0920"></span>**.md** - Markdown (default) 

  
&nbsp;&nbsp;• <span class="para" id="7e486a3"></span>**-singlefile.html** - HTML that can be opened directly in a browser without internet connection. 

  
&nbsp;&nbsp;• <span class="para" id="6e6d9fd"></span>**.html** - HTML that is intended for use with an internet connection 

  
<span class="para" id="d2b2c4f"></span>By default, the utility renders all the *rakudoc* sources from `docs/` and outputs them in *markdown* to the current working directory, eg. 


```
bin/RenderDocs


```
<span class="para" id="1cb6d95"></span>In order to get the useage try 


```
bin/RenderDocs -h


```
<span class="para" id="da9a3ba"></span>In order to render a single file, put the basename without *.rakudoc* as a string parameter, eg. 


```
bin/RenderDocs README


```
<span class="para" id="c8b00c3"></span>In order to override the source and output defaults use `--src` and `--to` options, eg. 


```
bin/RenderDocs --src='sources/' --to='rendered/' some-file


```
<span class="para" id="21f9a8c"></span>In order to get single file HTML, rather than markdown 


```
bin/Render --to='rendered' --html --single README


```
<span class="para" id="651cfd2"></span>In order to get the possibilities offered by RakuDoc::To::HTML-Extra, including maps, graphs, themes and the Bulma CSS framework, use `--html` and `--extra`, eg. 


```
bin/Render --html Graphviz


```
<span class="para" id="bb9fe7d"></span>The **html** variants allow for `--debug` and `--verbose`, which are described in [Render](Render.txt). 


----

## Troubleshooting<div id="Troubleshooting"> </div>
<span class="para" id="e3431ff"></span>In order to get the RakuDoc render test file (rakudociem-ipsum) to work, a recent version of the Rakudoc compiler is needed, after v2024.07. 

<span class="para" id="53029b4"></span>If the cannonical command above fails, perhaps with a message such as 


```
===SORRY!===
This element has not been resolved. Type: RakuAST::Type::Simple


```
<span class="para" id="7fa2f84"></span>or 


```
Out-of-sync package detected in LANG1 at r => Str=｢{ $!front-matter }｣

  (value in braid: RakuAST::Class, value in $*PACKAGE: RakuAST::Class)
===SORRY!===
No such method 'IMPL-REGEX-QAST' for invocant of type 'RakuAST::Regex'

```
<span class="para" id="347a187"></span>then try 


```
bin/force-compile


```
<span class="para" id="06b115a"></span>This deletes the `.precomp` files in the current directory, and runs `prove6 -I.`, which causes a recompilation of all the modules. 


----

## Credits<div id="Credits"> </div>
Richard Hainsworth aka finanalyst




----

## VERSION<div id="VERSION_0"> </div>
v0.16.2





----

----

Rendered from docs/docs/README.rakudoc at 23:41 UTC on 2024-12-11

Source last modified at 12:49 UTC on 2024-12-08



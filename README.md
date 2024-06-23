
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
<span id="930a3c48b8e54b488998d5325d4f56fdf0fe6971"></span>This module is intended to provide a generic renderer from RakuDoc v2 into text, but is designed to be easily extended to other output formats by subclassing. 

<span id="7b152629478b1cb2585b3283b4f9d34c8483341c"></span>Two other formats, namely HTML and Markdown, are provided in the distribution, see [RakuDoc::To::Markdown](RakuDoc-To-HTML.md) and [RakuDoc::To::Markdown](RakuDoc-To-Markdown.md). 

<span id="82405827b77898e41e1d10368899982c9f6c52d6"></span>This is software using bleeding edge Rakudo, so look ([at troubleshooting below](Troubleshooting)). 

<span id="690052db767069285e24e2a61d9e4e2c6b23d08f"></span>The **canonical method** for generating rendered text is possible (which sends output to STDOUT, so pipe to a file), namely RAKUDO_RAKUAST=1 raku --rakudoc=Generic rakudociem-ipsum.rakudoc > store-output 

<span id="3f0008c83b0c22dd2a5b45e8638d50a398ba4e87"></span>The file [rakudociem-ipsum.rakudoc](https://github.com/Raku/RakuDoc-GAMMA/blob/main/rakudociem-ipsum.rakudoc) is the file for testing RakuDoc v2 compliance. It can be obtained with: bin/get-compliance-document 

<span id="5dd7301d3a849a0619f6800fa9e06f78f48153d4"></span>Another (easier?) way to render a RakuDoc file is using [RenderTextify](RenderTextify utility.md), which avoids some installation problems, stores the output and offers some other output options, eg. bin/RenderTextify rakudociem-ipsum 

<span id="af5bcae55e25b31acd095d365de2957b0416d7d2"></span>(the .rakudoc extension may be omitted if desired) 

<span id="09f0f26b67a8b11af550aef938fbaf9769ae1d19"></span>The two main documentation sources are: 



&nbsp;&nbsp;• <span id="179ee1d515d990af4db79613605f42f8094ec4ac"></span>[An overview of the generic renderer](Render.md) 

  
&nbsp;&nbsp;• <span id="08b70501785f4440b4ee18be43e8c7fa8c11632c"></span>[The templating system](Templates.md) 

  
<span id="f2ec0f54c89539c78693f77a600028939525d438"></span>Other modules are also documented: 



&nbsp;&nbsp;• <span id="a3c31bed5b3d955c5699e3777d09e47d98ca950d"></span>[Processed - objects to keep track of intermediate state](Processed.md) 

  
&nbsp;&nbsp;• <span id="98e06429dd994315b15c401ad17fca34086c99ef"></span>[PStr - Strings containing forward references](PromiseStrings.md) 

  
&nbsp;&nbsp;• <span id="0ccf2aa5bd419a5ba50c87ab927d95dabb75e585"></span>[ScopedData - an object to keep track of data valid for a block scope](ScopedData.md) 

  
&nbsp;&nbsp;• <span id="c77973e4f43974a6bf1a31c3400d0bad552bf018"></span>[a table of the minimum set of templates to render any RakuDoc source](default-text-templates.md) 

  
&nbsp;&nbsp;• <span id="9c394608a54d2ba386c9b25f525eb6bf34812438"></span>[a grammar for parsing the meta data of a Markup code](MarkUpMeta.md) 

  
&nbsp;&nbsp;• <span id="59109209b814d8173e652edaa8f7ffc872fa4035"></span>[an object for numerating items headings](Numeration.md) 

  
----

## RenderTextify utility<div id="RenderTextify_utility"> </div>
<span id="05f8004e1639478cdb627d624dd235fdfab8d800"></span>The utility `bin/RenderTexify` can be called with a RakuDoc source and it saves the result directly to a file, rather than to STDOUT. 

<span id="58e41f858a4db6ec5a1026e48b75d4262015a74e"></span>For example, bin/RenderTextify rakudociem-ipsum 

<span id="8f5925e8aedef809bec16ab69fec8eff1649dc5b"></span>will produce the file rakudociem-ipsum.rakudoc.text 

<span id="3aaa5f5d595b7947e3b4f1460a23c852d44c7693"></span>The executable `bin/RenderTexify` can also be called with the flags `test` and `pretty` and the name of a file to render. The file is output to text files with the flag and `.text` appended to the name. The file format `.rakudoc` is assumed, and added if missing. 

<span id="b8a1071c140ca4ca77117172807fffd0999ab30b"></span>For example, bin/RenderTextify --pretty rakudociem-ipsum 

<span id="fffb9f9e7320a92db460269039bef88fe49a5b48"></span>will produce the file rakudociem-ipsum.rakudoc.pretty.text 

<span id="eafcd9bbe508c1f1a608f9358878d28bb9f11110"></span>By setting the environment variable POSTPROCESSING=1 the text output will be naively wrapped. This option is still being developed. 

<span id="2fc3736b0605f03dcce11e30538258ea8189b0ff"></span>For example, POSTPROCESSING=1 bin/RenderTextify --pretty rakudociem-ipsum 

<span id="217bc3dd6c3a42825ebd4264b20be56ecd0c9c25"></span>If the environment variable WIDTH is also set, the text output will be wrapped to the value. 

<span id="5104eeaac91ef34d922b98a5258a629ceb2879cf"></span>WIDTH by default is set at 80 chars. To set at 70, use: POSTPROCESSING=1 WIDTH=70 bin/RenderTextify rakudociem-ipsum 

----

## Troubleshooting<div id="Troubleshooting"> </div>
<span id="a99bb4c0728e4d548af92c7da932f4a19d33d92f"></span>In order to get the RakuDoc render test file (rakudociem-ipsum) to work, a recent version of the Rakudoc compiler is needed: $ raku -v Welcome to Rakudo™ v2024.05-32-g5b44a64b2. Implementing the Raku® Programming Language v6.d. Built on MoarVM version 2024.05-5-gf48abb710. 

<span id="43aa0dcf938ddf822e727cc59e504a6c6574a9a7"></span>If the cannonical command above fails, perhaps with a message such as ===SORRY!=== This element has not been resolved. Type: RakuAST::Type::Simple 

<span id="9cb1409b697413778d632b20d031299e6d58c2b1"></span>but there is a local version of `RakuDoc::To::Generic` available, then try RAKUDO_RAKUAST=1 raku -I. -MRakuDoc::Render --rakudoc=Generic rakudociem-ipsum.rakudoc > store-output 

<span id="e762e55ba8fab9819616fdc5552d09df3ffefa39"></span>The command above may also generate an error, such as ===SORRY!=== Error while compiling ..... (OO::Monitors) Variable '$cond' is not declared. Perhaps you forgot a 'sub' if this was intended to be part of a signature? at .... ------> macro wait-condition(⏏$cond) is export { because the RakuAST compiler does not yet handle macros, and (OO::Monitors) uses them. 

<span id="c598ed793f736a84f681fc79afb2d7a118113c36"></span>The first step is to re-run the test files, eg., prove6 -I. 

<span id="f0226b20b584f762143c9234850418c7fd9dd54f"></span>This causes a recompilation of the modules in this distribution to be recompiled because the tests run `isa-ok` on each module. 

<span id="677cf2fa2553f787a3c21c1b9ae44a4be4abdf35"></span>This is sometimes not sufficient. The next step is to use the utility `bin/force-compile` in the root of the repo. It deletes the `.precomp` files in the current directory, then recompiles the modules in the repo. 

<span id="fe4b9451bd29ced34ecf93e82d843f861fd0a4cf"></span>Again try running the basic tests. 

<span id="23c41c4849874c1e9cbda122dc9d8c2b6aa237b8"></span>Another method might be to run the `raku --rakudoc=...` command, but without 'RAKUDO_RAKUAST=1'. Expect errors because the current production version of Rakudo does not allow for extensive Unicode entities. 

<span id="f3bcc5ced943cad62b5af64b8708b25bc2add0a6"></span>However, this will compile `RakuDoc::Render` and its dependencies. 

<span id="9288b0226731ebb2427153139d016358442b626a"></span>Then run the command again but with 'RAKUDO_RAKUAST=1'. 


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

Rendered from docs/docs/README.rakudoc at 11:20 UTC on 2024-06-23

Source last modified at 11:04 UTC on 2024-06-23



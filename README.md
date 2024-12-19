
# RakuDoc renderer

	Renders RakuDoc sources into an output format dependent on templates

----

## Table of Contents

<a href="#SYNOPSIS">SYNOPSIS</a>   
<a href="#Overview">Overview</a>   
<a href="#Command_line_invocation">Command line invocation</a>   
<a href="#RenderDocs_utility">RenderDocs utility</a>   
<a href="#Docker_image">Docker image</a>   
<a href="#Documentation">Documentation</a>   
<a href="#RenderTextify_utility">RenderTextify utility</a>   
<a href="#Wrapping">Wrapping</a>   
<a href="#Troubleshooting">Troubleshooting</a>   
<a href="#Credits">Credits</a>   


<div id="SYNOPSIS"></div>

## SYNOPSIS
&nbsp;&nbsp;• Clone the repository  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="fc2dfe0"></span>`git clone https://github.com/finanalyst/rakuast-rakudoc-render.git` 

  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="6846695"></span>`cd rakuast-rakudoc-render` 

  
&nbsp;&nbsp;• Install using zef as follows (flag is important)  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="8f021ca"></span>`zef install . -/precompile-install` 

  
<span class="para" id="351913a"></span>Note that `zef` runs the tests in `t/`, and those cause compilation of the modules in the distribution. 

<span class="para" id="22a894d"></span>Also a docker container is available as described in [Docker image](Docker image) 



<div id="Overview"></div>

## Overview
<span class="para" id="54589ed"></span>This distribution is intended to provide several renderers from RakuDoc v2 into commonly used output formats. For those reading this file on *finanalyst.github.io*, the distribution can be found at [Github repo](https://github.com/finanalyst/rakuast-rakudoc-render). 

<span class="para" id="cb2e9a3"></span>The basic render engine is `RakuDoc::Render`, which renders a RakuDoc source into text for display on a terminal. 

<span class="para" id="221bd19"></span>The Renderer class is designed to be extended to other output formats by subclassing. 

<span class="para" id="dc78d1b"></span>It is easier to use [RenderDocs](RenderDocs utility), which handles output to different formats and saves to a file. 

<span class="para" id="4e119c7"></span>This software uses bleeding edge Rakudo, so look [at troubleshooting below](Troubleshooting). 


<div id="Command line invocation"></div><div id="Command_line_invocation"></div>

## Command line invocation
<span class="para" id="243b1df"></span>The RakuDoc documentation describes a command line invocation, which is described here, but [RenderDocs](RenderDocs utility) is recommended. 

<span class="para" id="c009944"></span>The **canonical method** for generating rendered text is possible using the *Generic* renderer and sends the output to STDOUT, so its best to pipe to a file, namely 


```
RAKUDO_RAKUAST=1 raku --rakudoc=Generic rakudociem-ipsum.rakudoc > store-output
```
<span class="para" id="81696a6"></span>Some [naive wrapping and width modification](Wrapping) is possible using environment variables. 

<span class="para" id="e719414"></span>The file [rakudociem-ipsum.rakudoc](https://github.com/Raku/RakuDoc-GAMMA/blob/main/compliance-document/rakudociem-ipsum.rakudoc) is the file for testing RakuDoc v2 compliance. An up-to-date copy can be obtained with: 


```
bin/get-compliance-document
```
<span class="para" id="f4a51f3"></span>A copy of `rakudociem-ipsum.rakudoc` is also contained in `resources/compliance-rendering`, together with renderings of the file using the output renderers in this distribution. 

<span class="para" id="bba4fc2"></span>In order to avoid environment variables, eg for Windows, a RakuDoc file can be rendered to Text using the [RenderTextify](RenderTextify utility). It avoids some installation problems, stores the output and offers some other output options, eg. 


```
bin/RenderTextify rakudociem-ipsum
```
<span class="para" id="416d7d2"></span>(the .rakudoc extension may be omitted if desired) 


<div id="RenderDocs utility"></div><div id="RenderDocs_utility"></div>

## RenderDocs utility
<span class="para" id="bce3aed"></span>*RenderDoc* has several advantages over a `raku` invocation: 



&nbsp;&nbsp;• <span class="para" id="475e1a6"></span>Output to different formats is managed using the `--format` command line option: 

  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="9d4694b"></span>*no --format* or `--format=md`: generates a file in Markdown with an ***.md*** extension 

  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="cfc1ecd"></span>`--format=HTML --single`: generates a file in HTML, ending ***_singlefile.html***, which can be opened directly in a browser without internet connection. 

  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="bed871e"></span>`--format=HTML`: generates a file in HTML, ending ***.html***, the HTML is intended for use with an internet connection and has a number of custom blocks. 

  
&nbsp;&nbsp;• Simpler file specification  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="9e2a82b"></span>By default, **all** the *rakudoc* sources from `docs/` are rendered 

  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="64b1baa"></span>By default, all the output files are stored at the *Current working directory* 

  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="0392c7f"></span>The first word after the options (eg **__documents__**) is taken to be the file **docs/documents.rakudoc** 

  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="6e5245c"></span>The source location can be given with `--src=...` and the output with `--to=...` 

  
<span class="para" id="65a4ea7"></span>Given these defaults, the following will render all the **.rakudocs* in *docs/* to <./*.md> in Markdown. 


```
bin/RenderDocs
```
<span class="para" id="f5c7f24"></span>In order to get the command line options try 


```
bin/RenderDocs -h
```
<span class="para" id="b457977"></span>An example of rendering a single file, put the basename without *.rakudoc* as a string parameter, eg. 


```
bin/RenderDocs README
```
<span class="para" id="c8b00c3"></span>In order to override the source and output defaults use `--src` and `--to` options, eg. 


```
bin/RenderDocs --src='sources/' --to='rendered/' some-file
```
<span class="para" id="2493f92"></span>In order to get single file HTML, rather than markdown, and output it into *rendered/* 


```
bin/Render --to='rendered' --html --single README
```
<span class="para" id="2e5dbcf"></span>In order to get the possibilities offered by RakuDoc::To::HTML-Extra, including maps, graphs, themes and the Bulma CSS framework, use `--format=html`, eg. 


```
bin/Render --format=html src=docs/plugins Graphviz
```
<span class="para" id="0e606fa"></span>Two debug options `--debug` and `--verbose` are available and are described in [Render](Render.md). 


<div id="Docker image"></div><div id="Docker_image"></div>

## Docker image
<span class="para" id="b244dd7"></span>The distribution contains a `Dockerfile`, which shows the installation steps needed. An image of a recent distribution can be found at `docker.io/finanalyst/rakuast-rakudoc-render:latest` 

<span class="para" id="e929c7d"></span>The docker image was designed for use as a *github CI action*. For example, place the following content in the file `.workflows/GenerateDocs.yml` in the root of a *github* repository: 


```
name: RakuDoc to MD
on:
  # Runs on pushes targeting the main branch
  push:
    branches: ["main"]
  # Allows you to run this workflow manually from the Actions tab
  workflow_dispatch:
jobs:
    container-job:
        runs-on: ubuntu-latest
        steps:
            - name: Checkout code
              uses: actions/checkout@master
              with:
                persist-credentials: false
                fetch-depth: 0
            - name: Render docs/sources
              uses: addnab/docker-run-action@v3
              with:
                image: finanalyst/rakuast-rakudoc-render:latest
                registry: docker.io
                options: -v ${{github.workspace}}/docs:/docs -v ${{github.workspace}}:/to
                run: RenderDocs
            - name: Commit and Push changes
              uses: Andro999b/push@v1.3
              with:
                github_token: ${{ secrets.GITHUB_TOKEN }}
                branch: 'main'
```
<span class="para" id="8649ca1"></span>Then whenever commits are pushed to the repository, all new or modified documents in **docs/** are rendered into Markdown and copied to the root of the repository (remember to `git pull` locally). 

<div id="Documentation"></div>

## Documentation
<span class="para" id="b01e23f"></span>If you are reading this from the repo, an HTML version of the documentation can be found at [finanalyst.github.io](https://finanalyst.github.io). 

<span class="para" id="9ae1d19"></span>The two main documentation sources are: 



&nbsp;&nbsp;• <span class="para" id="8c91600"></span>[An overview of the generic renderer](https://finanalyst.github.io/Render) 

  
&nbsp;&nbsp;• <span class="para" id="0b80cbf"></span>[The templating system](https://finanalyst.github.io/Templates) 

  

<div id="RenderTextify utility"></div><div id="RenderTextify_utility"></div>

## RenderTextify utility
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
<div id="Wrapping"></div>

## Wrapping
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
<div id="Troubleshooting"></div>

## Troubleshooting
<span class="para" id="e3431ff"></span>In order to get the RakuDoc render test file (rakudociem-ipsum) to work, a recent version of the Rakudoc compiler is needed, after v2024.07. 

<span class="para" id="c75f356"></span>If the cannonical command `raku` invocation fails, perhaps with a message such as 


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

<div id="Credits"></div>

## Credits
Richard Hainsworth aka finanalyst




<div id="VERSION"></div><div id="VERSION_0"></div>

## VERSION
 <div class="rakudoc-version">v0.20.0</div> 



----

----

Rendered from docs/README.rakudoc/README at 21:03 UTC on 2024-12-19

Source last modified at 20:53 UTC on 2024-12-19


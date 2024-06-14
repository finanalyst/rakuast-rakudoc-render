        # RakuDoc renderer
>Renders RakuDoc sources into an output format dependent on templates


> **AUTHOR** # AUTHOR
Richard Hainsworth aka finanalyst


----
## Table of Contents
[Overview](#overview)  
[RenderTextify utility](#rendertextify-utility)  
[Troubleshooting](#troubleshooting-0)  

----
# Overview
This module is intended to provide a generic renderer from RakuDoc v2 into text, but is designed to be easily extended to other output formats by subclassing.

Two other formats, namely HTML and MarkDown, are (to be) provided in the distribution.

The cannonical method for generating rendered text is possible, namely RAKUDO_RAKUAST=1 raku --rakudoc=Generic rakudociem-ipsum.rakudoc

The file [rakudociem-ipsum.rakudoc](https://github.com/Raku/RakuDoc-GAMMA/blob/main/rakudociem-ipsum.rakudoc) is the file for testing RakuDoc v2 compliance.

Another (easier?) way to render a RakuDoc file is [RenderTextify](RenderTextify utility.md), which avoids some problems ([more detail below](troubleshooting)) and gives a title and date to the output.

The two main documentation sources are:

*  [An overview of the generic renderer](Render.md)

*  [The templating system](Templates.md)

Other modules are also documented:

*  [Processed - objects to keep track of intermediate state](Processed.md)

*  [PStr - Strings containing forward references](PromiseStrings.md)

*  [ScopedData - an object to keep track of data valid for a block scope](ScopedData.md)

*  [a table of the minimum set of templates to render any RakuDoc source](default-text-templates.md)

*  [a grammar for parsing the meta data of a Markup code](MarkUpMeta.md)

*  [an object for numerating items headings](Numeration.md)

# RenderTextify utility
The utility `bin/RenderTexify` can be called with a RakuDoc source and it extracts information about the file, such as its name and modification date, which are included in the rendered output. The Rakudo compiler only provides the AST to the render method, so a filename cannot be included in the output.

For example, bin/RenderTextify rakudociem-ipsum

will produce the file rakudociem-ipsum.rakudoc.text

The executable `bin/RenderTexify` can also be called with the flags `test` and `pretty` and the name of a file to render. The file is output to text files with the flag and `.text` appended to the name. The file format `.rakudoc` is assumed, and added if missing.

For example, bin/RenderTextify --pretty rakudociem-ipsum

will produce the file rakudociem-ipsum.rakudoc.pretty.text

By setting the environment variable POSTPROCESSING=1 the text output will be naively wrapped. For example, POSTPROCESSING=1 bin/RenderTextify --pretty rakudociem-ipsum

If the environment variable WIDTH is also set, the text output will be wrapped to the value.

WIDTH by default is set at 80 chars. To set at 70, use: POSTPROCESSING=1 WIDTH=70 bin/RenderTextify rakudociem-ipsum

# Troubleshooting
In order to get the RakuDoc render test file (rakudociem-ipsum) to work, a recent version of the Rakudoc compiler is needed: $ raku -v Welcome to Rakudo™ v2024.05-27-g46511d59c. Implementing the Raku® Programming Language v6.d. Built on MoarVM version 2024.05-5-gf48abb710.

If the cannonical command above fails, perhaps with a message such as ===SORRY!=== This element has not been resolved. Type: RakuAST::Type::Simple

but there is a local version of `RakuDoc::To::Generic` available, then try RAKUDO_RAKUAST=1 raku -I. -MRakuDoc::Render --rakudoc=Generic rakudociem-ipsum.rakudoc

If the command above generates an error, such as ===SORRY!=== Error while compiling ...FCE553 (OO::Monitors) Variable '$cond' is not declared. Perhaps you forgot a 'sub' if this was intended to be part of a signature? at ...FCE553 (OO::Monitors):101 ------> macro wait-condition(⏏$cond) is export {

Then try running the same command but without 'RAKUDO_RAKUAST=1'







----
Rendered from README at 2024-06-14T08:54:29Z
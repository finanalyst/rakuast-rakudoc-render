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

This is software using bleeding edge Rakudo, so look ([at troubleshooting below](troubleshooting)).

The canonical method for generating rendered text is possible (which sends output to STDOUT, so pipe to a file), namely RAKUDO_RAKUAST=1 raku --rakudoc=Generic rakudociem-ipsum.rakudoc > store-output

The file [rakudociem-ipsum.rakudoc](https://github.com/Raku/RakuDoc-GAMMA/blob/main/rakudociem-ipsum.rakudoc) is the file for testing RakuDoc v2 compliance. It can be obtained with: bin/get-compliance-document

Another (easier?) way to render a RakuDoc file is using [RenderTextify](RenderTextify utility.md), which avoids some installation problems, stores the output and offers some other output options, eg. bin/RenderTextify rakudociem-ipsum

(the .rakudoc extension may be omitted if desired)

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

# Troubleshooting
In order to get the RakuDoc render test file (rakudociem-ipsum) to work, a recent version of the Rakudoc compiler is needed: $ raku -v Welcome to Rakudo™ v2024.05-32-g5b44a64b2. Implementing the Raku® Programming Language v6.d. Built on MoarVM version 2024.05-5-gf48abb710.

If the cannonical command above fails, perhaps with a message such as ===SORRY!=== This element has not been resolved. Type: RakuAST::Type::Simple

but there is a local version of `RakuDoc::To::Generic` available, then try RAKUDO_RAKUAST=1 raku -I. -MRakuDoc::Render --rakudoc=Generic rakudociem-ipsum.rakudoc > store-output

The command above may generate a compile time error because the RakuAST compiler cannot compile a module that the Rakudo compiler can.

A workaround is to use the utility `bin/force-compile` in the root of the repo. It deletes the `.precomp` files in the current directory, then recompiles the modules in the repo.

Another method might be to run the `raku --rakudoc=...` but without 'RAKUDO_RAKUAST=1'. Expect errors because the current production version of Rakudo does not allow for extensive Unicode entities.

However, this will compile `RakuDoc::Render` and its dependencies.

Then run the command again but with 'RAKUDO_RAKUAST=1'.







----
Rendered from README at 2024-06-16T19:46:04Z
        # ProcessState and RakuDoc::Processed
>
## Table of Contents
[Purpose](#purpose)  
[Attributes of ProcessedState object](#attributes-of-processedstate-object)  
[PStr $.body is rw](#pstr-body-is-rw)  
[Hash @.toc](#hash-toc)  
[Array @.head-numbering](#array-head-numbering)  
[%.index](#index)  
[@.footnotes](#footnotes)  
[Array %.semantics](#array-semantics)  
[@.warnings](#warnings)  
[@.items](#items)  
[@.defns](#defns)  
[@.numitems](#numitems)  
[@.numdefns](#numdefns)  
[%.definitions](#definitions)  
[@.inline-defns](#inline-defns)  
[Attributes of RakuDoc::Processed](#attributes-of-rakudocprocessed)  
[%.source-data](#source-data)  
[$!output-format = 'txt'](#output-format--txt)  
[Str $.front-matter is rw = 'preface'](#str-front-matter-is-rw--preface)  
[Str $.name is rw](#str-name-is-rw)  
[Str $.title is rw = 'NO_TITLE'](#str-title-is-rw--no_title)  
[Str $.title-target is rw = '___top'](#str-title-target-is-rw--___top)  
[Str $.subtitle is rw = ''](#str-subtitle-is-rw--)  
[Str $.modified is rw = now.DateTime.utc.truncated-to('seconds').Str](#str-modified-is-rw--nowdatetimeutctruncated-tosecondsstr)  
[SetHash $.targets](#sethash-targets)  
[Hash %.links](#hash-links)  
[Str $.rendered-toc is rw](#str-rendered-toc-is-rw)  
[Str $.rendered-index is rw](#str-rendered-index-is-rw)  

----
# Purpose
When a RakuDoc source is being processed, data is collected about numerous items, such as the Table of Contents, the Index, list and definition entries.

Many RakuDoc blocks allow for recursion, with blocks being embedded within each other. A ProcessState object is therefore created to contain all the intermediary data.

One ProcessState object can be added to another, and so once one block has been processed, it can be 'added' to the ProcessState object of the containing block.

Finally, when an entire RakuDoc source has been fully rendered, it is useful to retain all the intermediary data structures as well. 

The overall RakuDoc::Processed object contains data related to the source as well as the rendered data.

By keeping track of the timestamps of the source file and the rendering, it will be possible to determine whether to render a source again, or not. 

## Attributes of ProcessedState object
### `PStr $.body is rw `
String of rendered source, may contain Promises during rendering

### `Hash @.toc `
Table of Contents data Ordered array of { :level, :text, :target, :is-heading } level - in heading hierarchy, text - to be shown in TOC target - of item in text, is-heading - used for Index placing

### `Array @.head-numbering `
heading numbering data Ordered array of [ $id, $level ] $id is the PCell id of where the numeration structure is to be placed level - in heading hierarchy

### `%.index `
Index (from   markup) Hash key => Array of :target, :is-header, :place key to be displayed, target is for link, place is description of section is-header because   in headings treated differently to ordinary text

### `@.footnotes `
Footnotes (from [ 1 ] markup) Ordered Array of :$text, :$retTarget, :$fnNumber, :$fnTarget text is content of footnote, fnNumber is footNote number fnTarget is link to rendered footnote retTarget is link to where footnote is defined to link back form footnote

### `Array %.semantics `
Semantic blocks (which includes TITLE & SUBTITLE) can be hidden Hash of SEMANTIC => [ PStr | Str ]

### `@.warnings `
An array of warnings is generated and then rendered by the warnings template The warning template, by default is called by the wrap-source template RakuDoc warnings are generated as specified in the RakuDoc v2 document.

### `@.items `
An array of accumulated rendered items, added to body when next non-item block encountered

### `@.defns `
An array of accumulated rendered definitions, added to body when next non-defn block encountered

### `@.numitems `
An array of accumulated rendered numbered items, added to body when next non-item block encountered

### `@.numdefns `
An array of accumulated rendered numbered definitions, added to body when next non-defn block encountered

### `%.definitions `
Hash of definition => rendered value for definitions

### `@.inline-defns `
Array to signal when one or more inline defn are made in a Paragraph

## Attributes of RakuDoc::Processed
All of the ProcessState attributes, and the following.

### `%.source-data `
Information about the RakuDoc source, eg file name, path, modified, language

### `$!output-format = 'txt' `
The output format that the source has been rendered into

### `Str $.front-matter is rw = 'preface' `
Text between =TITLE and first header, used for   place before first header

### `Str $.name is rw `
Name to be used in titles and files name can be modified after creation of Object name can be set when creating object if name is not set, then it is taken from source name + format

### `Str $.title is rw = 'NO_TITLE' `
String value of TITLE.

### `Str $.title-target is rw = '___top' `
Target of Title Line

### `Str $.subtitle is rw = '' `
String value of SUBTITLE, provides description of file

### `Str $.modified is rw = now.DateTime.utc.truncated-to('seconds').Str `
When RakuDoc Processed Object modified (source-data<modified> should be earlier than RPO.modified)

### `SetHash $.targets `
target data generated from block names and :id metadata A set of unique targets inside the file, new targets must be unique

### `Hash %.links `
Links (from [link-label](destination.md) markup) Hash of destination => :target, :type, :place, :link-label target = computed URL (for local files), place = anchor inside file type has following values:

*  Internal are of the form '#this is a heading' and refer to anchors inside the file

*  Local are of the form 'some-type#a heading there', where 'some-type' is a file name in the same directory

*  External is a fully qualified URL

### `Str $.rendered-toc is rw `
Rendered version of the ToC

### `Str $.rendered-index is rw `
Rendered version of the Index






----
###### 1


----
Rendered from Processed at 2024-06-04T22:21:33Z
        # Templates in default-text-templates
>Auto generated from `lib/RakuDoc/Render.rakumod`


## Table of Contents
[Documentation of default templates](#documentation-of-default-templates)  

----
>Documentation of default templates

| **Name** | **Description**  |
| --- | ---  |
| **_name**| special key to name template set |
| **code**| renders =code blocks |
| **comment**| renders =comment block |
| **custom**| renders =custom block |
| **defn**| renders =defn block |
| **defn-list**| renders =numdefn block |
|  &nbsp; | special template to render a defn list data structure |
| **delta**| rendering the content from the :delta option |
|  &nbsp; | see inline variant markup-Δ |
| **final**| special template to encapsulate all the output to save to a file |
| **footnotes**| special template to render the footnotes data structure |
| **formula**| renders =formula block |
| **head**| renders =head block |
| **implicit-code**| renders implicit code from an indented paragraph |
| **index**| special template to render the index data structure |
| **index-item**| renders a single item in the index |
| **input**| renders =input block |
| **item**| renders =item block |
| **item-list**| special template to render an item list data structure |
| **markup-A**| A< DISPLAY-TEXT &#124; METADATA = ALIAS-NAME > |
|  &nbsp; | Alias to be replaced by contents of specified V<=alias> directive |
| **markup-B**| B< DISPLAY-TEXT > |
|  &nbsp; | Basis/focus of sentence (typically rendered bold) |
| **markup-C**| C< DISPLAY-TEXT > |
|  &nbsp; | Code (typically rendered fixed-width) |
| **markup-D**| D< DISPLAY-TEXT &#124; METADATA = SYNONYMS > |
|  &nbsp; | Definition inline ( D<term being defined&#124;synonym1; synonym2> ) |
| **markup-E**| E< DISPLAY-TEXT &#124; METADATA = HTML/UNICODE-ENTITIES > |
|  &nbsp; | Entity (HTML or Unicode) description ( E<entity1;entity2; multi,glyph;...> ) |
| **markup-F**| F< DISPLAY-TEXT &#124; METADATA = LATEX-FORM > |
|  &nbsp; | Formula inline content ( F<ALT&#124;LaTex notation> ) |
| **markup-H**| H< DISPLAY-TEXT > |
|  &nbsp; | High text (typically rendered superscript) |
| **markup-I**| I< DISPLAY-TEXT > |
|  &nbsp; | Important (typically rendered in italics) |
| **markup-J**| J< DISPLAY-TEXT > |
|  &nbsp; | Junior text (typically rendered subscript) |
| **markup-K**| K< DISPLAY-TEXT > |
|  &nbsp; | Keyboard input (typically rendered fixed-width) |
| **markup-L**| L< DISPLAY-TEXT &#124; METADATA = TARGET-URI > |
|  &nbsp; | Link ( L<display text&#124;destination URI> ) |
| **markup-M**| M< DISPLAY-TEXT &#124; METADATA = WHATEVER > |
|  &nbsp; | Markup extra ( M<display text&#124;functionality;param,sub-type;...>) |
| **markup-N**| N< DISPLAY-TEXT > |
|  &nbsp; | Note (text not rendered inline, but visible in some way: footnote, sidenote, pop-up, etc.)) |
| **markup-O**| O< DISPLAY-TEXT > |
|  &nbsp; | Overstrike or strikethrough |
| **markup-P**| P< DISPLAY-TEXT &#124; METADATA = REPLACEMENT-URI > |
|  &nbsp; | Placement link |
| **markup-R**| R< DISPLAY-TEXT > |
|  &nbsp; | Replaceable component or metasyntax |
| **markup-S**| S< DISPLAY-TEXT > |
|  &nbsp; | Space characters to be preserved |
| **markup-T**| T< DISPLAY-TEXT > |
|  &nbsp; | Terminal output (typically rendered fixed-width) |
| **markup-U**| U< DISPLAY-TEXT > |
|  &nbsp; | Unusual (typically rendered with underlining) |
| **markup-V**| V< DISPLAY-TEXT > |
|  &nbsp; | Verbatim (internal markup instructions ignored) |
| **markup-X**| X< DISPLAY-TEXT &#124; METADATA = INDEX-ENTRY > |
|  &nbsp; | Index entry ( X<display text&#124;entry,subentry;...>) |
| **markup-bad**| Unknown markup, render minimally |
| **markup-Δ**| Δ< DISPLAY-TEXT &#124; METADATA = VERSION-ETC > |
|  &nbsp; | Delta note ( Δ<visible text&#124;version; Notification text> ) |
| **nested**| renders =nested block |
| **numdefn**| special template to render a numbered defn list data structure |
| **numdefn-list**| special template to render a numbered item list data structure |
| **numhead**| renders =numhead block |
| **numitem**| renders =numitem block |
| **numitem-list**| special template to render a numbered item list data structure |
| **output**| renders =output block |
| **para**| renders =para block |
| **place**| renders =place block |
| **pod**| renders =pod block |
| **rakudoc**| renders =rakudoc block |
| **section**| renders =section block |
| **semantic**| renders =SEMANTIC block, if not otherwise given |
| **table**| renders =table block |
| **toc**| special template to render the toc list |
| **toc-item**| renders a single item in the toc |
| **toc-numeration**| renders the numeration part for a toc |
| **unknown**| renders any unknown block minimally |
| **warnings**| special template to render the warnings data structure |






----
Rendered from default-text-templates at 2024-06-17T20:27:17Z
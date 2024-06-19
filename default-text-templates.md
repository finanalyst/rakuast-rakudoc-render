
# Templates in `default-text-templates`

	Auto generated from `lib/RakuDoc/Render.rakumod`

----

## Table of Contents
<a href="#Documentation_of_default_templates">Documentation of default templates</a>   


----

## Documentation of default templates<div id="Documentation_of_default_templates"> </div>
 | **Name** | **Description** |
| :---: | :---: |
 | **_name** | special key to name template set |
 | **code** | renders =code blocks |
 | **comment** | renders =comment block |
 | **custom** | renders =custom block |
 | **defn** | renders =defn block |
 | **defn-list** | renders =numdefn block |
 | &nbsp; | special template to render a defn list data structure |
 | **delta** | rendering the content from the :delta option |
 | &nbsp; | see inline variant markup-Δ |
 | **final** | special template to encapsulate all the output to save to a file |
 | **footnotes** | special template to render the footnotes data structure |
 | **formula** | renders =formula block |
 | **head** | renders =head block |
 | **implicit-code** | renders implicit code from an indented paragraph |
 | **index** | special template to render the index data structure |
 | **index-item** | renders a single item in the index |
 | **input** | renders =input block |
 | **item** | renders =item block |
 | **item-list** | special template to render an item list data structure |
 | **markup-A** | A&lt; DISPLAY-TEXT &amp;#124;&nbsp;&nbsp;METADATA = ALIAS-NAME &gt; |
 | &nbsp; | Alias to be replaced by contents of specified V&lt;=alias&gt; directive |
 | **markup-B** | B&lt; DISPLAY-TEXT &gt; |
 | &nbsp; | Basis/focus of sentence (typically rendered bold) |
 | **markup-C** | C&lt; DISPLAY-TEXT &gt; |
 | &nbsp; | Code (typically rendered fixed-width) |
 | **markup-D** | D&lt; DISPLAY-TEXT &amp;#124;&nbsp;&nbsp;METADATA = SYNONYMS &gt; |
 | &nbsp; | Definition inline ( D&lt;term being defined&amp;#124;synonym1; synonym2&gt; ) |
 | **markup-E** | E&lt; DISPLAY-TEXT &amp;#124;&nbsp;&nbsp;METADATA = HTML/UNICODE-ENTITIES |&gt; |
 | &nbsp; | Entity (HTML or Unicode) description ( E&lt;entity1;entity2; multi,glyph;...|&gt; ) |
 | **markup-F** | F&lt; DISPLAY-TEXT &amp;#124;&nbsp;&nbsp;METADATA = LATEX-FORM &gt; |
 | &nbsp; | Formula inline content ( F&lt;ALT&amp;#124;LaTex notation&gt; ) |
 | **markup-H** | H&lt; DISPLAY-TEXT &gt; |
 | &nbsp; | High text (typically rendered superscript) |
 | **markup-I** | I&lt; DISPLAY-TEXT &gt; |
 | &nbsp; | Important (typically rendered in italics) |
 | **markup-J** | J&lt; DISPLAY-TEXT &gt; |
 | &nbsp; | Junior text (typically rendered subscript) |
 | **markup-K** | K&lt; DISPLAY-TEXT &gt; |
 | &nbsp; | Keyboard input (typically rendered fixed-width) |
 | **markup-L** | L&lt; DISPLAY-TEXT &amp;#124;&nbsp;&nbsp;METADATA = TARGET-URI &gt; |
 | &nbsp; | Link ( L&lt;display text&amp;#124;destination URI&gt; ) |
 | **markup-M** | M&lt; DISPLAY-TEXT &amp;#124;&nbsp;&nbsp;METADATA = WHATEVER &gt; |
 | &nbsp; | Markup extra ( M&lt;display text&amp;#124;functionality;param,sub-type;...&gt;) |
 | **markup-N** | N&lt; DISPLAY-TEXT &gt; |
 | &nbsp; | Note (text not rendered inline, but visible in some way: footnote, sidenote, pop-up, etc.)) |
 | **markup-O** | O&lt; DISPLAY-TEXT &gt; |
 | &nbsp; | Overstrike or strikethrough |
 | **markup-P** | P&lt; DISPLAY-TEXT &amp;#124;&nbsp;&nbsp;METADATA = REPLACEMENT-URI &gt; |
 | &nbsp; | Placement link |
 | **markup-R** | R&lt; DISPLAY-TEXT &gt; |
 | &nbsp; | Replaceable component or metasyntax |
 | **markup-S** | S&lt; DISPLAY-TEXT &gt; |
 | &nbsp; | Space characters to be preserved |
 | **markup-T** | T&lt; DISPLAY-TEXT &gt; |
 | &nbsp; | Terminal output (typically rendered fixed-width) |
 | **markup-U** | U&lt; DISPLAY-TEXT &gt; |
 | &nbsp; | Unusual (typically rendered with underlining) |
 | **markup-V** | V&lt; DISPLAY-TEXT &gt; |
 | &nbsp; | Verbatim (internal markup instructions ignored) |
 | **markup-X** | X&lt; DISPLAY-TEXT &amp;#124;&nbsp;&nbsp;METADATA = INDEX-ENTRY &gt; |
 | &nbsp; | Index entry ( X&lt;display text&amp;#124;entry,subentry;...&gt;) |
 | **markup-bad** | Unknown markup, render minimally |
 | **markup-Δ** | Δ&lt; DISPLAY-TEXT &amp;#124;&nbsp;&nbsp;METADATA = VERSION-ETC &gt; |
 | &nbsp; | Delta note ( Δ&lt;visible text&amp;#124;version; Notification text&gt; ) |
 | **nested** | renders =nested block |
 | **numdefn** | special template to render a numbered defn list data structure |
 | **numdefn-list** | special template to render a numbered item list data structure |
 | **numhead** | renders =numhead block |
 | **numitem** | renders =numitem block |
 | **numitem-list** | special template to render a numbered item list data structure |
 | **output** | renders =output block |
 | **para** | renders =para block |
 | **place** | renders =place block |
 | **pod** | renders =pod block |
 | **rakudoc** | renders =rakudoc block |
 | **section** | renders =section block |
 | **semantic** | renders =SEMANTIC block, if not otherwise given |
 | **table** | renders =table block |
 | **toc** | special template to render the toc list |
 | **toc-item** | renders a single item in the toc |
 | **toc-numeration** | renders the numeration part for a toc |
 | **unknown** | renders any unknown block minimally |
 | **warnings** | special template to render the warnings data structure |



----

----

Rendered from docs/docs/default-text-templates.rakudoc at 15:33 UTC on 2024-06-19

Source last modified at 15:32 UTC on 2024-06-19



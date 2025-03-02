# list of things to do
- [ ] Testing. Skip test in 115 ln 19 when offline
- [-] Templates
  - [ ] Epub, need to add extra metadata pages 

- [ ] Add tests to Templates for new escape attribute
- [ ] Change documentation for Templates about escape attribute
- [ ] ditto to Render

- [ ] Outputs needing change
  - [ ] MD pseudo extensions
    - [ ] More tests of rendered output, including headers to test escaping 
  - [ ] text psuedo extensions ??
  - [ ] HTML, ditto
  - [x] HTML, include binary data into output, eg images.
  - [x] HTML-Extra create SCSS processing & theme changes 
    - [ ] linked css dark / light (eg for highlights-js)
    - [ ] toc at mobile
  - [ ] 

- [ ] Apply numeration possibilities numTable, numFormula, numPara
- [ ] Implement new numbering extensions, 
  - [ ] :number
  - [ ] :numberalias
- [ ] Fix default text templates
  - [ ] improve wrapping postprocessing
  - [ ] when lines are wrapped, Esc codes 'leak' accross line boundaries
  - [ ] Esc chars are counted as if visible, but should not for wrapping
  - [ ] Replace Section names in Index and ToC with line numbers
  - [ ] add originating line numbers to Footnotes 

use Rainbow;
use RakuDoc::Render;

unit class RakuDoc::Plugin::HTML::Hilite;
has %.config = %(
    :name-space<hilite>,
	:license<Artistic-2.0>,
	:credit<finanalyst, lizmat>,
	:author<<Richard Hainsworth, aka finanalyst\nElizabeth Mattijsen, aka lizmat>>,
	:version<0.1.1>,
	:js-link(
		['src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/highlight.min.js"', 2 ],
		['src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/languages/haskell.min.js"', 2 ],
	),
	:css-link(
		['href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/styles/default.min.css"',1],
	),
    :js([self.js-text,1],),
    :scss([ self.scss-str, 1], ),
);
has %!hilight-langs = %(
    'HTML' => 'xml',
    'XML' => 'xml',
    'BASH' => 'bash',
    'C' => 'c',
    'C++' => 'cpp',
    'C#' => 'csharp',
    'SCSS' => 'css',
    'SASS' => 'css',
    'CSS' => 'css',
    'MARKDOWN' => 'markdown',
    'DIFF' => 'diff',
    'RUBY' => 'ruby',
    'GO' => 'go',
    'TOML' => 'ini',
    'INI' => 'ini',
    'JAVA' => 'java',
    'JAVASCRIPT' => 'javascript',
    'JSON' => 'json',
    'KOTLIN' => 'kotlin',
    'LESS' => 'less',
    'LUA' => 'lua',
    'MAKEFILE' => 'makefile',
    'PERL' => 'perl',
    'OBJECTIVE-C' => 'objectivec',
    'PHP' => 'php',
    'PHP-TEMPLATE' => 'php-template',
    'PHPTEMPLATE' => 'php-template',
    'PHP_TEMPLATE' => 'php-template',
    'PYTHON' => 'python',
    'PYTHON-REPL' => 'python-repl',
    'PYTHON_REPL' => 'python-repl',
    'R' => 'r',
    'RUST' => 'rust',
    'SCSS' => 'scss',
    'SHELL' => 'shell',
    'SQL' => 'sql',
    'SWIFT' => 'swift',
    'YAML' => 'yaml',
    'TYPESCRIPT' => 'typescript',
    'BASIC' => 'vbnet',
    '.NET' => 'vbnet',
    'HASKELL' => 'haskell',
);
method enable( RakuDoc::Processor:D $rdp ) {
    $rdp.add-templates( $.templates, :source<Hilite plugin> );
    $rdp.add-data( %!config<name-space>, %!config );
}
sub wrapper(str $color, str $c) {
    $c.trim ?? "<span style=\"color:var(--bulma-$color);font-weight:500;\">$c\</span>" !! $c
}
method templates {
    constant CUT-LENG = 500; # crop length in error message
    %(
        code => sub (%prm, $tmpl) {
            # if :allow is set, then no highlighting as allow creates alternative styling
            # if :!syntax-highlighting, then no highlighting
            # if :lang is set to a lang in list, then enable highlightjs
            # if :lang is set to lang not in list, not raku or RakuDoc, then no highlighting
            # if :lang is not set, then highlight as Raku

            my $code;
            my $syntax-label;
            my $source = %prm<contents>.Str.trim-trailing;
            my Bool $hilite = %prm<syntax-highlighting> // True;
            if %prm<allow> {
                $syntax-label = '<b>allow</b> styling';
                $code = qq:to/NOHIGHS/;
                    <pre class="nohighlights">
                    { $tmpl<escape-code> }
                    </pre>
                    NOHIGHS
            }
            elsif $hilite {
                my $lang = %prm<lang> // 'Raku';
                given $lang.uc {
                    when any( %!hilight-langs.keys ) {
                        $syntax-label = $lang ~  ' highlighting by highlight-js';
                        $code = qq:to/HILIGHT/;
                            <pre class="browser-hl">\<code class="language-{ %!hilight-langs{ $_ } }">{ $tmpl.globals.escape.($source) }\</code>\</pre>
                            HILIGHT
                    }
                    when 'RAKUDOC' {
                        $syntax-label = 'RakuDoc';
                    }
                    when ! /^ 'RAKU' » / {
                        $syntax-label = $lang;
                        $code = qq:to/NOHIGHS/;
                            <pre class="nohighlights">$tmpl.globals.escape.($source)\</pre>
                            NOHIGHS
                    }
                    default {
                        $syntax-label = 'Raku highlighting';
                    }
                }
            }
            else { # no :allow and :!syntax-highlighting
                $syntax-label = %prm<lang> // 'Text';
                $code = qq:to/NOHIGHS/;
                    <pre class="nohighlights">{ $tmpl.globals.escape.($source) }\</pre>
                    NOHIGHS
            }
            without $code { # so need Raku highlighting
                if $syntax-label eq 'RakuDoc' {
                        $code = Rainbow::tokenize-rakudoc($source).map( -> $t {
                            my $cont = $tmpl.globals.escape.($t.text);
                            if $t.type.key ne 'TEXT' {
                                qq[<span class="rainbow-{$t.type.key.lc}">$cont\</span>]
                            }
                            else {
                                $cont .= subst(/ ' ' /, '&nbsp;',:g);
                            }
                        }).join('');
                    }
                    else {
                        $code = Rainbow::tokenize($source).map( -> $t {
                            my $cont = $tmpl.globals.escape.($t.text);
                            if $t.type.key ne 'TEXT' {
                                qq[<span class="rainbow-{$t.type.key.lc}">$cont\</span>]
                            }
                            else {
                                $cont .= subst(/ ' ' /, '&nbsp;',:g);
                            }
                        }).join('');
                    }
                $code .= subst( / \v+ <?before $> /, '');
                $code .= subst( / \v /, '<br>', :g);
                $code .= subst( / "\t" /, '&nbsp' x 4, :g );
                $code = qq:to/NOHIGHS/;
                        <pre class="nohighlights">$code\</pre>
                        NOHIGHS
            }
            my $del = %prm<delta> // '';
            my $caption = %prm<caption>;
            $caption = [~] %prm<numeration>.grep( *.so ).map( {
                '<span class="enumeration-' ~ .field-type ~ '">' ~ $_ ~ '</span>'
            } ) if %prm<numeration>;
            qq:to/CODE/
                { '<div class="delta">' ~ $del if $del }
                <div class="raku-code">
                <button class="copy-code" title="Copy code">⿻</button>
                <label>$syntax-label\</label>
                <div>$code\</div>
                <div class="code-caption">$caption\</div>
                </div>
                { '</div>' if $del }
            CODE
        },
    )
}
method js-text {
    q:to/JSCOPY/;
        // Hilite-helper.js
        document.addEventListener('DOMContentLoaded', function () {
            // trigger the highlighter for non-Raku code
            hljs.highlightAll();

            // copy code block to clipboard adapted from solution at
            // https://stackoverflow.com/questions/34191780/javascript-copy-string-to-clipboard-as-text-html
            // if behaviour problems with different browsers add stylesheet code from that solution.
            const copyButtons = Array.from(document.querySelectorAll('.copy-code'));
            copyButtons.forEach( function( button ) {
            var codeElement = button.nextElementSibling.nextElementSibling; // skip the label and get the div
            button.addEventListener( 'click', function(insideButton) {
                var container = document.createElement('div');
                container.innerHTML = codeElement.innerHTML;
                    container.style.position = 'fixed';
                    container.style.pointerEvents = 'none';
                    container.style.opacity = 0;
                    document.body.appendChild(container);
                    window.getSelection().removeAllRanges();
                    var range = document.createRange();
                    range.selectNode(container);
                    window.getSelection().addRange(range);
                    document.execCommand("copy", false);
                    document.body.removeChild(container);
                });
            });
        });
    JSCOPY
}
method scss-str {
    q:to/SCSS/
    /* Raku code highlighting */

    //hardwire hilite colours (for now)
    :root {
        --base-color-scalar: #2458a2;       /* Darker than #3273dc */
        --base-color-array: #B01030;        /* Darkened crimson */
        --base-color-hash: #00a693;         /* Darker cyan-green */
        --base-color-code: #209cee;         /* Bulma info */
        --base-color-keyword: #008c7e;      /* Darkened primary cyan */
        --base-color-operator: #1ca24f;     /* Darker green for contrast */
        --base-color-type: #d12c4c;         /* Deeper pinkish red */
        --base-color-routine: #489fdc;      /* Richer blue, not too pale */
        --base-color-string: #369ec6;       /* Stronger blue-cyan */
        --base-color-string-delimiter: #1d90d2; /* More contrast than #7dd3fc */
        --base-color-escape: #2b2b2b;       /* Darkened for visibility */
        --base-color-text: #2a2a2a;         /* Darker base text */
        --base-color-comment: #4aa36c;      /* Less pastel, more visible green */
        --base-color-regex-special: #00996f; /* Balanced mid-green */
        --base-color-regex-literal: #a52a2a; /* brown */
        --base-color-regex-delimiter: #aa00aa; /* Darkened fuchsia */
        --base-color-doc-text: #2b9e71;     /* Deeper mint green */
        --base-color-doc-markup: #d02b4c;   /* Matches adjusted danger */
    }
    .raku-code {
        position: relative;
        margin: 0 1rem 0 1rem;
        button.copy-code {
            cursor: pointer;
            opacity: 0;
            padding: 0 0.25rem 0.25rem 0.25rem;
            position: absolute;
        }
        .code-caption {
            margin: 0;
        }
        &:hover button.copy-code {
            opacity: 0.5;
        }
        label {
            float: right;
            font-size: xx-small;
            font-style: italic;
            height: auto;
            padding-right: 0;
        }
        /* required to match highlights-js css with raku highlighter css */
        pre.browser-hl { padding: 7px; }

        .code-name {
            padding-top: 0.75rem;
            padding-left: 1.25rem;
            font-weight: 500;
        }
        pre {
            display: inline-block;
            overflow: scroll;
            width: 100%;
        }
        .rakudoc-in-code {
            padding: 1.25rem 1.5rem;
        }
        .section {
            /* https://github.com/Raku/doc-website/issues/144 */
            padding: 0rem;
        }
        // Exception: If inside .nohighlights, reset styles
        .nohighlights {
            background: none;
            color: inherit;
        }
        .rainbow-name_scalar {
          color: var(--base-color-scalar);
          font-weight: 500;
        }
        .rainbow-name_array {
          color: var(--base-color-array);
          font-weight: 500;
        }
        .rainbow-name_hash {
          color: var(--base-color-hash);
          font-weight: 500;
        }
        .rainbow-name_code {
          color: var(--base-color-code);
          font-weight: 500;
        }
        .rainbow-keyword {
          color: var(--base-color-keyword);
          font-weight: 500;
        }
        .rainbow-operator {
          color: var(--base-color-operator);
          font-weight: 500;
        }
        .rainbow-type {
          color: var(--base-color-type);
          font-weight: 500;
        }
        .rainbow-routine {
          color: var(--base-color-routine);
          font-weight: 500;
        }
        .rainbow-string {
          color: var(--base-color-string);
          font-weight: 500;
        }
        .rainbow-string_delimiter {
          color: var(--base-color-string-delimiter);
          font-weight: 500;
        }
        .rainbow-escape {
          color: var(--base-color-escape);
          font-weight: 500;
        }
        .rainbow-text {
          color: var(--base-color-text);
          font-weight: 500;
        }
        .rainbow-comment {
          color: var(--base-color-comment);
          font-weight: 500;
        }
        .rainbow-regex_special {
          color: var(--base-color-regex-special);
          font-weight: 500;
        }
        .rainbow-regex_literal {
          color: var(--base-color-regex-literal);
          font-weight: 500;
        }
        .rainbow-regex_delimiter {
          color: var(--base-color-regex-delimiter);
          font-weight: 500;
        }
        .rainbow-rakudoc_text {
          color: var(--base-color-doc-text);
          font-weight: 500;
        }
        .rainbow-rakudoc_markup {
          color: var(--base-color-doc-markup);
          font-weight: 500;
        }
    }
    SCSS
}

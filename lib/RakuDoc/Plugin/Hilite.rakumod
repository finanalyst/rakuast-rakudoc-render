use experimental :rakuast;
use RakuAST::Deparse::Highlight;
use RakuDoc::Render;

unit class RakuDoc::Plugin::Hilite;
has %.config = %(
    :name-space<hilite>,
	:license<Artistic-2.0>,
	:credit<finanalyst, lizmat>,
	:author<<Richard Hainsworth, aka finanalyst\nElizabeth Mattijsen, aka lizmat>>,
	:version<0.1.0>,
	:js-link(
		['src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.8.0/highlight.min.js"', 2 ],
		['src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.8.0/languages/haskell.min.js"', 2 ],
	),
	:css-link(
		['href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.8.0/styles/atom-one-light.min.css" title="light"',1],
	),
    :js([self.js-text,1],),
    :scss([ self.scss-str, 1], ),
);
has %!hilight-langs = %(
    'HTML' => 'xml',
    'XML' => 'xml',
    'BASH' => 'bash',
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
    $rdp.add-templates( $.templates );
    $rdp.add-data( %!config<name-space>, %!config );
}

method templates {
    %(
    code => sub (%prm, $tmpl) {
        # if :lang is set != raku / rakudoc, then enable highlightjs
        # otherwise pass through Raku syntax highlighter.
        my $code;
        my $syntax-label;
        if %prm<lang>:exists {
            if %prm<lang>.uc ~~ any( %!hilight-langs.keys ) {
                $syntax-label = %prm<lang>.tc ~  ' highlighting by highlight-js';
                $code = qq:to/HILIGHT/;
                    <pre class="browser-hl">
                    <code class="language-{ %!hilight-langs{ %prm<lang>.uc } }">{ $tmpl<escaped> }
                    </code></pre>
                    HILIGHT
            }
            elsif %prm<lang> ~~ any( <Raku RakuDoc Rakudoc raku rakudoc> ) {
                $syntax-label = %prm<lang> ~ ' highlighting';
            }
            else {
                $syntax-label = "｢{ %prm<lang> }｣ without highlighting";
                $code = qq:to/NOHIGHS/;
                    <pre class="nohighlights">
                    { $tmpl<escaped> }
                    </pre>
                    NOHIGHS
            }
        }
        else {
            $syntax-label = 'Raku highlighting';
        }
        without $code { # so need Raku highlighting
            my $source = %prm<contents>.Str;
            try {
                $code = highlight( $source, 'HTML');
            }
            with $! {
                $tmpl.globals.helper<add-to-warnings>( 'Error when highlighting ｢' ~
                    ( $source.chars > 200
                        ?? ($source.substr(200) ~ ' ... ')
                        !! $source.trim ) ~
                    '｣' ~ "\nbecause\n" ~ .message );
                $code = $source;
            }
            unless $code {
                $tmpl.globals.helper<add-to-warnings>( 'Could not highlight ｢' ~
                    ( $source.chars > 200
                        ?? ($source.substr(200) ~ ' ... ')
                        !! $source.trim ) ~
                    '｣' );
                $code = $source;
            }
            $code = qq:to/NOHIGHS/;
                    <pre class="nohighlights">
                    $code
                    </pre>
                    NOHIGHS
        }
        qq[
            <div class="raku-code raku-lang">
                <button class="copy-code" title="Copy code"><i class="far fa-clipboard"></i></button>
                <label>$syntax-label\</label>
                <div>$code\</div>
            </div>
        ]
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
    .raku-code {
      position: relative;
      margin: 1rem 0;
      border-bottom: 3px solid #ccccccc;
      box-shadow: 0 2px 3px 0 rgba(0, 0, 0, 0.07);;
      border: 1px solid #ccccccc;

      button.copy-code {
        cursor: pointer;
        opacity: 0;
        padding: 0 0.25rem 0.25rem 0.25rem;
        position: absolute;
      }
      &:hover button.copy-code {
        opacity: 0.5;
      }

      label {
        float: right;
        font-size: xx-small;
        font-style: italic;
        height: auto;
        margin: 0 5px 0 0;
      }

    /* required to match highlights-js css with raku highlighter css */
      pre.browser-hl { padding: 7px; }

      .code-name {
        padding-top: 0.75rem;
        padding-left: 1.25rem;
        color: #A30031;
        font-weight: 500;
      }
       pre {
        background-color: #fafafa;
        color: #030303;
        display: inline-block;
        overflow: scroll;
        width: 96%;
      }
      .rakudoc-in-code {
        padding: 1.25rem 1.5rem;
      }

      .section {
        /* https://github.com/Raku/doc-website/issues/144 */
        padding: 0rem;
      }
    }
    SCSS
}
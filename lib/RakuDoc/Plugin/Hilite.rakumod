use experimental :rakuast;
use RakuAST::Deparse::Highlight;
use Rainbow;
use RakuDoc::Render;

unit class RakuDoc::Plugin::Hilite;
has %.config = %(
    :name-space<hilite>,
	:license<Artistic-2.0>,
	:credit<finanalyst, lizmat>,
	:author<<Richard Hainsworth, aka finanalyst\nElizabeth Mattijsen, aka lizmat>>,
	:version<0.1.1>,
	:js-link(
		['src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.10.0/build/highlight.min.js"', 2 ],
		['src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.10.0/languages/haskell.min.js"', 2 ],
	),
	:css-link(
		['href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.10.0/build/styles/default.min.css"',1],
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
    $c.trim ?? "<span style=\"color:var(--bulma-$color);font-weight:600;\">$c\</span>" !! $c
}
my %mappings =
     deparse => mapper(
          black     => -> $c { wrapper( "black",   $c ) },
          blue      => -> $c { wrapper( "link",    $c ) },
          cyan      => -> $c { wrapper( "info",    $c ) },
          green     => -> $c { wrapper( "primary", $c ) },
          magenta   => -> $c { wrapper( "success", $c ) },
          none      => -> $c { wrapper( "none",    $c ) },
          red       => -> $c { wrapper( "danger",  $c ) },
          yellow    => -> $c { wrapper( "warning", $c ) },
          white     => -> $c { wrapper( "white",   $c ) },
     ),
     rainbow => %(
            NAME_SCALAR => 'link',
            NAME_ARRAY => 'link',
            NAME_HASH => 'link',
            NAME_CODE => 'info',
            KEYWORD => 'primary',
            OPERATOR => 'success',
            TYPE => 'danger',
            ROUTINE => 'info',
            STRING => 'warning',
            STRING_DELIMITER => 'black',
            ESCAPE => 'black',
            TEXT => 'black',
            COMMENT => 'black',
            REGEX_SPECIAL => 'success',
            REGEX_LITERAL => 'black',
            REGEX_DELIMITER => 'primary',
            POD_TEXT => 'warning',
            POD_MARKUP => 'danger',
    )
;
method templates {
    constant CUT-LENG = 500; # crop length in error message
    %(
        code => sub (%prm, $tmpl) {
            # if :allow is set, then no highlighting as allow creates alternative styling
            # if :!syntax-highlighting, then no highlighting
            # if :lang is set to a lang in list, then enable highlightjs
            # if :lang is set to lang not in list, not raku or RakuDoc, then no highlighting
            # if :lang is not set, then highlight as Raku

            # select hilite engine
            my $engine = 'rainbow';
            $engine = 'deparse' if (%prm<highlighter>:exists && %prm<highlighter> ~~ /:i 'Deparse' /);
            my %mapping := %mappings{ $engine };
            my $code;
            my $syntax-label;
            my Bool $hilite = %prm<syntax-highlighting> // True;
            if %prm<allow> {
                $syntax-label = '<b>allow</b> styling';
                $code = qq:to/NOHIGHS/;
                        <pre class="nohighlights">
                        $tmpl('escaped', %(:html-tags, :contents($code) ) )
                        </pre>
                    NOHIGHS
            }
            elsif $hilite {
                my $lang = %prm<lang> // 'RAKU';
                given $lang.uc {
                    when any( %!hilight-langs.keys ) {
                        $syntax-label = $lang ~  ' highlighting by highlight-js';
                        $code = qq:to/HILIGHT/;
                            <pre class="browser-hl">
                            <code class="language-{ %!hilight-langs{ $_ } }">
                            { $tmpl<escaped> }
                            </code></pre>
                            HILIGHT
                    }
                    when 'RAKUDOC' {
                        $syntax-label = 'RakuDoc';
                        # for the time being don't highlight RakuDoc
                        $code = qq:to/NOHIGHS/
                            <pre class="nohighlights">
                            { $tmpl<escaped> }
                            </pre>
                            NOHIGHS
                    }
                    when ! /^ 'RAKU' » / {
                        $syntax-label = $lang;
                        $code = qq:to/NOHIGHS/;
                            <pre class="nohighlights">
                            { $tmpl<escaped> }
                            </pre>
                            NOHIGHS
                    }
                    default {
                        $syntax-label = 'Raku highlighting';
                    }
                }
            }
            else { # no :allow and :!syntax-highlighting
                $syntax-label = %prm<lang>;
                $code = qq:to/NOHIGHS/;
                    <pre class="nohighlights">
                    { $tmpl<escaped> }
                    </pre>
                    NOHIGHS
            }
            without $code { # so need Raku highlighting
                my $source = %prm<contents>.Str;
                if $engine eq 'deparse' {
                    my $c = highlight( $source, :unsafe, %mapping);
                    if $c {
                        $code = $c
                    } else {
                        my $m = $c.exception.message;
                        $tmpl.globals.helper<add-to-warnings>( 'Error when highlighting ｢' ~
                            ( $source.chars > CUT-LENG
                                ?? ($source.substr(0,CUT-LENG) ~ ' ... ')
                                !! $source.trim ) ~
                            '｣' ~ "\nbecause\n$m" );
                        $code = $source;
                    }
                    CATCH {
                        default {
                            $tmpl.globals.helper<add-to-warnings>( 'Error in code block with ｢' ~
                                ( $source.chars > CUT-LENG
                                    ?? ($source.substr(0,CUT-LENG) ~ ' ... ')
                                    !! $source.trim ) ~
                                '｣' ~ "\nbecause\n" ~ .message );
                            $code = $tmpl('escaped', %(:contents($source) ) );
                        }
                    }
                }
                else {
                    $code = Rainbow::tokenize($source).map( -> $t {
                        my $col = %mapping{$t.type.key} // %mapping<TEXT>;
                        wrapper($col,$t.text);
                    }).join;
                }
                $code = qq:to/NOHIGHS/;
                        <pre class="nohighlights">
                        $tmpl('escape-code', %( :contents($code) ) )
                        </pre>
                        NOHIGHS
            }
            qq[
                <div class="raku-code">
                    <button class="copy-code" title="Copy code"><i class="far fa-clipboard"></i></button>
                    <label>$syntax-label\</label>
                    <div>$code\</div>
                </div>
            ]
        },
        ## the following was needed when deparse highlight had %allow
#        markup-B => -> %prm, $tmpl {
#            if %prm<in_code_context> {
#                # reconstitute the markup code
#                'B<' ~ %prm<contents> ~ '>'
#            }
#            else { $tmpl.prev }
#        },
#        markup-C => -> %prm, $tmpl {
#            if %prm<in_code_context> {
#                # reconstitute the markup code
#                'C<' ~ %prm<contents> ~ '>'
#            }
#            else { $tmpl.prev }
#        },
#        markup-H => -> %prm, $tmpl {
#            if %prm<in_code_context> {
#                # reconstitute the markup code
#                'H<' ~ %prm<contents> ~ '>'
#            }
#            else { $tmpl.prev }
#        },
#        markup-I => -> %prm, $tmpl {
#            if %prm<in_code_context> {
#                # reconstitute the markup code
#                'I<' ~ %prm<contents> ~ '>'
#            }
#            else { $tmpl.prev }
#        },
#        markup-J => -> %prm, $tmpl {
#            if %prm<in_code_context> {
#                # reconstitute the markup code
#                'J<' ~ %prm<contents> ~ '>'
#            }
#            else { $tmpl.prev }
#        },
#        markup-K => -> %prm, $tmpl {
#            if %prm<in_code_context> {
#                # reconstitute the markup code
#                'K<' ~ %prm<contents> ~ '>'
#            }
#            else { $tmpl.prev }
#        },
#        markup-N => -> %prm, $tmpl {
#            if %prm<in_code_context> {
#                $tmpl.global.add-to-warning('Cannot ALLOW N<> inside code block');
#                # reconstitute the markup code
#                'N<' ~ %prm<contents> ~ '>'
#            }
#            else { $tmpl.prev }
#        },
#        markup-O => -> %prm, $tmpl {
#            if %prm<in_code_context> {
#                # reconstitute the markup code
#                'O<' ~ %prm<contents> ~ '>'
#            }
#            else { $tmpl.prev }
#        },
#        markup-R => -> %prm, $tmpl {
#            if %prm<in_code_context> {
#                # reconstitute the markup code
#                'R<' ~ %prm<contents> ~ '>'
#            }
#            else { $tmpl.prev }
#        },
#        markup-S => -> %prm, $tmpl {
#            if %prm<in_code_context> {
#                $tmpl.global.add-to-warning('S<> inside code block is useless');
#                # reconstitute the markup code
#                'S<' ~ %prm<contents> ~ '>'
#            }
#            else { $tmpl.prev }
#        },
#        markup-T => -> %prm, $tmpl {
#            if %prm<in_code_context> {
#                # reconstitute the markup code
#                'T<' ~ %prm<contents> ~ '>'
#            }
#            else { $tmpl.prev }
#        },
#        markup-U => -> %prm, $tmpl {
#            if %prm<in_code_context> {
#                # reconstitute the markup code
#                'U<' ~ %prm<contents> ~ '>'
#            }
#            else { $tmpl.prev }
#        },
#        markup-V => -> %prm, $tmpl {
#            if %prm<in_code_context> {
#                # reconstitute the markup code
#                'V<' ~ $tmpl<escaped>
#                .subst(/ \h\h /, '&nbsp;&nbsp;', :g)
#                .subst(/ \v /, '<br>', :g)
#                ~ '>'
#            }
#            else { $tmpl.prev }
#        },
#        markup-L => -> %prm, $tmpl {
#            if %prm<in_code_context> {
#                my $target = %prm<target>.trim.subst(/ '.*' /, ".%prm<output-format>", :g);
#                my $text = %prm<link-label>;
#                given %prm<type> {
#                    when 'local' {
#                        if %prm<place>:exists {
#                            qq[L\<$text|{$target}#{%prm<place>}>]
#                        }
#                        else {
#                            qq[L\<$text|$target>]
#                        }
#                    }
#                    when 'internal' {
#                        qq[L\<$text|#{$target}">]
#                    }
#                    default {
#                        qq[L\<$text|$target>]
#                    }
#                }
#            }
#            else { $tmpl.prev }
#        },
#        markup-X => -> %prm, $tmpl {
#            if %prm<in_code_context> {
#                # reconstitute the markup code
#                qq[X\<{%prm<contents>}|{%prm<target>}>]
#            }
#            else { $tmpl.prev }
#        },
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
        padding-right: 50px;
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
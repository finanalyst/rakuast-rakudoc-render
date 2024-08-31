use experimental :rakuast;
use RakuAST::Deparse::Highlight;
use RakuDoc::Render;

unit class RakuDoc::Plugin::Hilite;
has %.config = %(
    :name-space<hilite>,
	:license<Artistic-2.0>,
	:credit<finanalyst, lizmat>,
	:author<<Richard Hainsworth, aka finanalyst\nElizabeth Mattijsen, aka lizmat>>,
	:version<0.1.1>,
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
my %allowables =
  L => { qq|<a href="$_.meta()">$_.atoms()\</a>| },
  X => { qq|<span class="indexed" id="$_.meta()">$_.atoms()\</span>| },
  B => { '<span class="basis">' ~ .atoms ~ '</span>' },
  C => { '<span class="code">' ~ .atoms ~ '</span>' },
  H => { '<span class="high">' ~ .atoms ~ '</span>' },
  I => { '<span class="important">' ~ .atoms ~ '</span>' },
  J => { '<span class="junior">' ~ .atoms ~ '</span>' },
  K => { '<span class="keyboard">' ~ .atoms ~ '</span>' },
  N => { '<span class="note">' ~ .atoms ~ '</span>' },
  O => { '<span class="overstrike">' ~ .atoms ~ '</span>' },
  R => { '<span class="replace">' ~ .atoms ~ '</span>' },
  S => { '<span class="space">' ~ .atoms ~ '</span>' },
  T => { '<span class="terminal">' ~ .atoms ~ '</span>' },
  U => { '<span class="unusual">' ~ .atoms ~ '</span>' },
  V => { .atoms }
;
sub default-mapper(str $color, str $c) {
    $c.trim ?? "<span style=\"color:var(--bulma-$color);font-weight:600;\">$c\</span>" !! $c
}
my %mapping = mapper
  black     => -> $c { default-mapper "black",   $c },
  blue      => -> $c { default-mapper "link",    $c },
  cyan      => -> $c { default-mapper "info",    $c },
  green     => -> $c { default-mapper "primary", $c },
  magenta   => -> $c { default-mapper "success", $c },
  none      => -> $c { default-mapper "none",    $c },
  red       => -> $c { default-mapper "danger",  $c },
  yellow    => -> $c { default-mapper "warning", $c },
  white     => -> $c { default-mapper "white",   $c },
;
method templates {
    constant CUT-LENG = 500;
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
                elsif %prm<lang> ~~ /:i rakudoc / {
                    $syntax-label = 'RakuDoc highlighting';
                    # for the time being don't highlight RakuDoc
                    $code = qq:to/NOHIGHS/
                        <pre class="nohighlights">
                        { $tmpl<escaped> }
                        </pre>
                        NOHIGHS
                }
                elsif %prm<lang> ~~ /:i 'raku' » / {
                    $syntax-label = 'Raku highlighting';
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
                my %allow;
                if %prm<allow>:exists {
                    %allow{ $_ } = %allowables{ $_ } for %prm<allow>.list;
                }
                my $c = highlight( $source, :unsafe, :default(&default-mapper), %mapping);
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
                $code = qq:to/NOHIGHS/;
                        <pre class="nohighlights">
                        $tmpl('escaped', %(:html-tags, :contents($code) ) )
                        </pre>
                        NOHIGHS
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
            qq[
                <div class="raku-code raku-lang">
                    <button class="copy-code" title="Copy code"><i class="far fa-clipboard"></i></button>
                    <label>$syntax-label\</label>
                    <div>$code\</div>
                </div>
            ]
        },
        markup-B => -> %prm, $tmpl {
            if %prm<in_code_context> {
                # reconstitute the markup code
                'B<' ~ %prm<contents> ~ '>'
            }
            else { $tmpl.prev }
        },
        markup-C => -> %prm, $tmpl {
            if %prm<in_code_context> {
                # reconstitute the markup code
                'C<' ~ %prm<contents> ~ '>'
            }
            else { $tmpl.prev }
        },
        markup-H => -> %prm, $tmpl {
            if %prm<in_code_context> {
                # reconstitute the markup code
                'H<' ~ %prm<contents> ~ '>'
            }
            else { $tmpl.prev }
        },
        markup-I => -> %prm, $tmpl {
            if %prm<in_code_context> {
                # reconstitute the markup code
                'I<' ~ %prm<contents> ~ '>'
            }
            else { $tmpl.prev }
        },
        markup-J => -> %prm, $tmpl {
            if %prm<in_code_context> {
                # reconstitute the markup code
                'J<' ~ %prm<contents> ~ '>'
            }
            else { $tmpl.prev }
        },
        markup-K => -> %prm, $tmpl {
            if %prm<in_code_context> {
                # reconstitute the markup code
                'K<' ~ %prm<contents> ~ '>'
            }
            else { $tmpl.prev }
        },
        markup-N => -> %prm, $tmpl {
            if %prm<in_code_context> {
                $tmpl.global.add-to-warning('Cannot ALLOW N<> inside code block');
                # reconstitute the markup code
                'N<' ~ %prm<contents> ~ '>'
            }
            else { $tmpl.prev }
        },
        markup-O => -> %prm, $tmpl {
            if %prm<in_code_context> {
                # reconstitute the markup code
                'O<' ~ %prm<contents> ~ '>'
            }
            else { $tmpl.prev }
        },
        markup-R => -> %prm, $tmpl {
            if %prm<in_code_context> {
                # reconstitute the markup code
                'R<' ~ %prm<contents> ~ '>'
            }
            else { $tmpl.prev }
        },
        markup-S => -> %prm, $tmpl {
            if %prm<in_code_context> {
                $tmpl.global.add-to-warning('S<> inside code block is useless');
                # reconstitute the markup code
                'S<' ~ %prm<contents> ~ '>'
            }
            else { $tmpl.prev }
        },
        markup-T => -> %prm, $tmpl {
            if %prm<in_code_context> {
                # reconstitute the markup code
                'T<' ~ %prm<contents> ~ '>'
            }
            else { $tmpl.prev }
        },
        markup-U => -> %prm, $tmpl {
            if %prm<in_code_context> {
                # reconstitute the markup code
                'U<' ~ %prm<contents> ~ '>'
            }
            else { $tmpl.prev }
        },
        markup-V => -> %prm, $tmpl {
            if %prm<in_code_context> {
                # reconstitute the markup code
                'V<' ~ $tmpl<escaped>
                .subst(/ \h\h /, '&nbsp;&nbsp;', :g)
                .subst(/ \v /, '<br>', :g)
                ~ '>'
            }
            else { $tmpl.prev }
        },
        markup-L => -> %prm, $tmpl {
            if %prm<in_code_context> {
                my $target = %prm<target>.trim.subst(/ '.*' /, ".%prm<output-format>", :g);
                my $text = %prm<link-label>;
                given %prm<type> {
                    when 'local' {
                        if %prm<place>:exists {
                            qq[L\<$text|{$target}#{%prm<place>}>]
                        }
                        else {
                            qq[L\<$text|$target>]
                        }
                    }
                    when 'internal' {
                        qq[L\<$text|#{$target}">]
                    }
                    default {
                        qq[L\<$text|$target>]
                    }
                }
            }
            else { $tmpl.prev }
        },
        markup-X => -> %prm, $tmpl {
            if %prm<in_code_context> {
                # reconstitute the markup code
                qq[X\<{%prm<contents>}|{%prm<target>}>]
            }
            else { $tmpl.prev }
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
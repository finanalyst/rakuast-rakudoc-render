use experimental :rakuast;
use RakuDoc::Templates;
use RakuDoc::PromiseStrings;
use RakuDoc::Render;

unit class RakuDoc::Plugin::Hilite;
has %.config = %(
    :name-space<hilite>,
	:license<Artistic-2.0>,
	:credit<finanalyst>,
	:author<Richard Hainsworth, aka finanalyst>,
	:version<0.1.0>,
	:css-link(['href="https://cdn.jsdelivr.net/npm/bulma@1.0.1/css/bulma.min.css"',1],),
	:js-link(['src="https://rawgit.com/farzher/fuzzysort/master/fuzzysort.js"',1],),
    :js(['',2],), # 1st element is replaced in TWEAK
    :css([]),
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
submethod TWEAK {
    %!config<js>[0][0] = self.js-text;
    %!config<css>.append: [self.chyron-css,1], [ self.toc-css, 1];
}
method enable( RakuDoc::Processor:D $rdp ) {
    $rdp.add-templates( $.templates );
    $rdp.add-data( %!config<name-space>, %!config );
}


method templates {
    %(
    block-code => sub (%prm, %tml) {
        my regex marker {
            "\xFF\xFF" ~ "\xFF\xFF" $<content> = (.+?)
        };
        # if :lang is set != raku / rakudoc, then enable highlightjs
        # otherwise pass through Raku syntax highlighter.
        my $code;
        my $syntax-label;
        if %prm<lang>:exists {
            if %prm<lang>.uc ~~ any( %!hilight-langs.keys ) {
                $syntax-label = %prm<lang>.tc ~  ' highlighting by highlight-js';
                $code = qq:to/HILIGHT/;
                    <pre class="browser-hl">
                    <code class="language-{ %!hilight-langs{ %prm<lang>.uc } }">{ %tml<escaped>(%prm<contents>) }
                    </code></pre>
                    HILIGHT
            }
            elsif %prm<lang> ~~ any( <Raku Rakudoc raku rakudoc> ) {
                $syntax-label = %prm<lang>.tc ~ ' highlighting';
            }
            else {
                $syntax-label = "｢{ %prm<lang> }｣ without highlighting";
                $code = qq:to/NOHIGHS/;
                    <pre class="nohighlights">
                    { %tml<escaped>( %prm<contents> ) }
                    </pre>
                    NOHIGHS
            }
        }
        else {
            $syntax-label = 'Raku highlighting';
        }
        without $code {
            my @tokens;
            my $t;
            my $parsed = %prm<contents> ~~ / ^ .*? [<marker> .*?]+ $/;
            if $parsed {
                for $parsed.chunks -> $c {
                    if $c.key eq 'marker' {
                        $t ~= "\xFF\xFF";
                        @tokens.push: $c.value<content>.Str;
                    }
                    else {
                        $t ~= $c.value
                    }
                }
                %prm<contents> = $t;
            }
            $code = &highlight(%prm<contents>);
            $code .= subst( / '<pre class="' /, '<pre class="nohighlights cm-s-ayaya ');
            $code .= subst( / "\xFF\xFF" /, { @tokens.shift }, :g );
        }
        qq[
            <div class="raku-code raku-lang">
                <button class="copy-code" title="Copy code"><i class="far fa-clipboard"></i></button>
                <label>$syntax-label\</label>
                <div>$code\</div>
            </div>
        ]
    },
}
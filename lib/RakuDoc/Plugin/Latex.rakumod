use v6.d;
use RakuDoc::Templates;
use RakuDoc::Render;
use RakuDoc::PromiseStrings;

unit class RakuDoc::Plugin::Latex;
has %.config =
    :name-space<latexformula>,
	:version<0.1.0>,
    :block-name('LatexFormula'),
	:license<Artistic-2.0>,
	:credit<https://editor.codecogs.com/ fair use provision with link-back>,
    :scss( [ self.scss-str, 1], ),
;
method enable( RakuDoc::Processor:D $rdp ) {
    $rdp.add-templates( $.templates, :source<Latex plugin> );
    $rdp.add-data( %!config<name-space>, %!config );
}
method templates {
    %(
        getLatexImage => -> %prm, $tmpl {
            my $proc = run <ping -c 1 latex.codecogs.com>, :err, :out;
            if $proc.out.slurp(:close) {
                my $data = %prm<raw>;
                qq:to/LATEX/;
                <img src="https://latex.codecogs.com/svg.image?{ $data }" />
                <a class="logo" href="https://www.codecogs.com"><img src="https://www.codecogs.com/images/poweredbycodecogs.png" border="0" alt="CodeCogs - An Open Source Scientific Library"></a>
                LATEX
            }
            else { # if url does not exist, then no output
                q:to/RSP/
                <div class="latex-render-error">
                    Internet access to ｢latex.codecogs.com｣ is needed for an image.
                </div>
                RSP
            }
        },
        LatexFormula => -> %prm, $tmpl {
            my $level = %prm<headlevel> // 1;
            my $head = $tmpl('head', %(:$level, :id(%prm<id>), :target(%prm<target>), :contents(%prm<caption>), :delta(%prm<delta>)));
            PStr.new: $head ~ '<div class="latex-equation">' ~ $tmpl<getLatexImage> ~ '</div>'
        },
        formula => -> %prm, $tmpl {
            $tmpl<LatexFormula>
        },
        markup-F => -> %prm, $tmpl {
            my $formula = $tmpl('getLatexImage', %(:raw(%prm<formula>),));
            qq[ <span class="latex-formula">$formula\</span>]
        },
    )
}
method scss-str {
    q:to/SCSS/
    /* Latex formula stying */
    div.latex-equation {
        display: flex;
        justify-content: space-around;
        align-items: center;
        a.logo {
            align-self: flex-last;
        }
    }
    span.latex-formula {
        display: inline-block;
        cursor: crosshair;
        a {
            display: none;
        }
        &:hover > a {
            display: inline-block;
            position: absolute;
            transform: translate(-3rem, -2rem);
            background: antiquewhite;
        }
    }
    .latex-render-error {
        color: red;
        font-weight: bold;
    }
    SCSS
}

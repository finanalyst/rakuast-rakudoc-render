use v6.d;
use RakuDoc::Templates;
use RakuDoc::Render;
use RakuDoc::PromiseStrings;

unit class RakuDoc::Plugin::HTML::Latex;
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
                ''
            }
        },
        formula => -> %prm, $tmpl {
            if $tmpl<getLatexImage> -> $rv {
                %prm<formula> = qq[<div class="latex-equation">$rv\</div>];
                %prm<alt> = ''
            }
            else {
                %prm<alt> = qq[<div title="No internet connection to https://codecogs.com">{ %prm<alt> }</div>]
            }
            $tmpl.prev(%prm)
        },
        markup-F => -> %prm, $tmpl {
            my $formula = $tmpl('getLatexImage', %(:raw(%prm<formula>),));
            qq[ <span {$formula ?? '' !! ' title="No internet connection to https://codecogs.com"'} class="latex-formula">{ $formula ?? $formula !! %prm<alt> }</span>]
        },
    )
}
method scss-str {
    q:to/SCSS/
    /* Latex formula stying */
    div.latex-equation {
        display: flex;
        justify-content: space-between;
        a.logo img {
            width: 60%;
            border: gray solid 1px;
            border-radius: 5px;
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

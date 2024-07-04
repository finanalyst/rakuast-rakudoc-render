use v6.d;
use RakuDoc::Templates;
use RakuDoc::Render;

unit class RakuDoc::Plugin::Latex;
has %.config =
    :name-space<latexformula>,
	:version<0.1.0>,
    :block-name('LatexFormula'),
	:license<Artistic-2.0>,
	:credit<https://editor.codecogs.com/ fair use provision with link-back>,
    :css<resources/css/latex-render.css>,
;
method enable( RakuDoc::Processor:D $rdp ) {
    $rdp.add-templates( $.templates );
    $rdp.add-data( %!config<name-space>, %!config );
}
method templates {
    %(
        LatexFormula => sub (%prm, $tmpl) {
            my $proc = run <ping -c 1 latex.codecogs.com>, :err, :out;
            unless $proc.out.slurp(:close) { # if url does not exist, then no output
                return q:to/RSP/
                <div class="latex-render error">
                    Internet access to ｢latex.codecogs.com｣ is needed for an image to be shown.
                </div>'
                RSP
            }
            my $data = %prm<raw>;
            qq:to/LATEX/;
                <div class="latex-render">
                <img src="https://latex.codecogs.com/svg.image?{ $data }" />
                <img class="logo" src="https://www.codecogs.com/images/poweredbycodecogs.png" border="0" alt="CodeCogs - An Open Source Scientific Library"></a>
                </div>
                LATEX
        },
        formula => -> %prm, $tmpl {
            my $formula = $tmpl<LatexFormula>;
            $tmpl.prev( %(%prm, :$formula, ) )
        }
    )
}
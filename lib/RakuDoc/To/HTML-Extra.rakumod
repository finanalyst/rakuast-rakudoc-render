use v6.d;
use RakuDoc::To::HTML;
use RakuDoc::Render;

unit class RakuDoc::To::HTML-Extra is RakuDoc::To::HTML;
use RakuDoc::Plugin::LeafletMaps;

submethod TWEAK {
    my $rdp := self.rdp;
    $rdp.add-templates(self.templates);
    RakuDoc::Plugin::LeafletMaps.enable($rdp);
    self.sort-flatten($rdp, 'css-link');
    self.sort-flatten($rdp, 'js-link');
}

method render($ast) {
    my $fn = $*PROGRAM;
    my %source-data = %(
        name     => ~$fn,
        modified => $fn.modified,
        path     => $fn.dirname,
    );
    self.new.rdp.render( $ast, :%source-data  )
}
#| plugins provide information about css/js & cdn as arrays of Str/order arrays
#| Templates expect a single ordered sequence of strings
method sort-flatten( $rdp, $key ) {
    my %d := $rdp.templates.globals.data;
    %d{ $key } = .list.sort({ .[1], .[0] }).map( *.[0] )
        with %d{ $key }
}
method templates {
    %( # replace the template that governs where CSS and JS go
        #| head-block, what goes in the head tab
        head-block => -> %prm, $tmpl {
            my %g-data := $tmpl.globals.data;
            # handle css first
            qq:to/HEAD/
                <title>{%prm<title>}</title>
                {%g-data<css>:exists ??
                   '<style>' ~ %g-data<css> ~ '</style>'
                !! ''
                }
                {%g-data<css-link>:exists ??
                    [~] %g-data<css-Link>.map({ '<link rel="stylesheet" ' ~ $_ ~ "/>\n" })
                !! ''
                }
                {%g-data<jss-link>:exists ??
                    [~] %g-data<css-Link>.map({ '<script ' ~ $_ ~ "/></script>\n" })
                !! ''
                }
            HEAD
        },
    )
}
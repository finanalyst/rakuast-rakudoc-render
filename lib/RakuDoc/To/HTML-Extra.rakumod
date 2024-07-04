use v6.d;
use RakuDoc::To::HTML;
use RakuDoc::PromiseStrings;

unit class RakuDoc::To::HTML-Extra is RakuDoc::To::HTML;
#| keys reserved for assets in HTML page, so Plugins may not claim any as a name-space.
has @!reserved = <css css-link js js-link>;
use RakuDoc::Plugin::LeafletMaps;
use RakuDoc::Plugin::Latex;
use RakuDoc::Plugin::Graphviz;
use RakuDoc::Plugin::Bulma;

submethod TWEAK {
    my $rdp := self.rdp;
    $rdp.add-templates(self.templates);
    RakuDoc::Plugin::LeafletMaps.new.enable($rdp);
    RakuDoc::Plugin::Latex.new.enable($rdp);
    RakuDoc::Plugin::Graphviz.new.enable($rdp);
    RakuDoc::Plugin::Bulma.new.enable($rdp);
    self.gather-flatten($rdp, 'css-link');
    self.gather-flatten($rdp, 'js-link');
}

method render($ast) {
    my $fn = $*PROGRAM;
    my %source-data =
        name     => ~$fn,
        modified => $fn.modified,
        path     => $fn.dirname,
    ;
    self.new.rdp.render( $ast, :%source-data  )
}
#| plugins provide config information about css/js & cdn as arrays of Str/order arrays
#| This needs to be gathered from all plugins, and processed for templates
method gather-flatten( $rdp, $key ) {
    my %d := $rdp.templates.data;
    my %valid = %d.pairs
        .grep({ .key ~~ none(@!reserved) })
        .grep({ .value.{ $key } ~~ Positional })
        .map( { .key => .value.{ $key } });
    my @p-tuples;
    for %valid.kv -> $k, $tuple-list {
        if $tuple-list ~~ Positional {
            for $tuple-list.list {
                if .[0] ~~ Str && .[1] ~~ Int {
                    @p-tuples.push: $_
                }
                else { note "Element ｢$_｣ of config attribute ｢$key｣ for plugin ｢$k｣ not a [Str, Int] tuple"}
            }
        }
        else { note "Config attribute ｢$key｣ for plugin ｢$k｣ must be a Positional, but got ｢$tuple-list｣"}
    }
    %d{ $key } = @p-tuples.sort({ .[1], .[0] }).map( *.[0] ).list;
}
my @allowed = <p span h div li ul ol>.map({ ($_, '/'~$_).Slip});
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
            {%g-data<css-link>:exists && %g-data<css-link>.elems ??
                [~] %g-data<css-link>.map({ '<link rel="stylesheet" ' ~ $_ ~ "/>\n" })
            !! ''
            }
            {%g-data<js-link>:exists && %g-data<js-link>.elems ??
                [~] %g-data<js-link>.map({ '<script ' ~ $_ ~ "></script>\n" })
            !! ''
            }
            HEAD
        },
        # escape contents
        escaped => -> %prm, $tmpl {
            my $cont = %prm<contents>;
            if $cont and %prm<html-tags> {
                $cont .= Str.trans( qw｢ & " ｣ => qw｢ &amp; &quot; ｣ );
                while $cont ~~ m:c/ '<' <!before @allowed> (.+? ) '>' / {
                    $cont = $/.replace-with( '&lt;' ~ $0 ~ '&gt;')
                }
                $cont
            }
            elsif $cont {
                $cont.Str.trans(
                   qw｢ <    >    &     "       ｣
                => qw｢ &lt; &gt; &amp; &quot;  ｣
                )
            }
            else { '' }
        },
        #| renders =code blocks
        code => -> %prm, $tmpl {
            %prm<html-tags> = True;
            my $del = %prm<delta> // '';
            PStr.new: ('<div class="delta">' ~ $del if $del) ~
            q[<pre class="code-block">] ~
            $tmpl('escaped', %(:html-tags, %prm) ) ~
            "\n</pre>\n" ~
            (</div> if $del)
        },
        #| renders implicit code from an indented paragraph
        implicit-code => -> %prm, $tmpl {
            %prm<html-tags> = True;
            my $del = %prm<delta> // '';
            PStr.new: q[<pre class="code-block">] ~
            $del ~
            $tmpl('escaped', %(:html-tags, %prm) ) ~
            "\n</pre>\n"
        },
        #| renders =input block
        input => -> %prm, $tmpl {
            %prm<html-tags> = True;
            my $del = %prm<delta> // '';
            PStr.new: q[<pre class="input-block">] ~
            $del ~
            $tmpl('escaped', %(:html-tags, %prm) ) ~
            "\n</pre>\n"
        },
        #| renders =output block
        output => -> %prm, $tmpl {
            %prm<html-tags> = True;
            my $del = %prm<delta> // '';
            PStr.new: q[<pre class="output-block">] ~
            $del ~
            $tmpl('escaped', %(:html-tags, %prm) ) ~
            "\n</pre>\n"
         },
    )
}
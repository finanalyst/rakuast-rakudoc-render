use experimental :rakuast;
use RakuDoc::Render;
use RakuDoc::To::HTML;
use RakuDoc::To::HTML-Extra;

proto sub MAIN(|) is export {*}

multi sub MAIN(
        :$src = 'docs',
        :$to = $*CWD,
        Bool :q($quiet) = False,
        Str :$format = 'md',
        Bool :$single = False,
        :$debug,
        Str :$verbose,
        Bool :$pretty,
    ) {
    my %docs = $src.IO.dir(test => *.ends-with('.rakudoc')).map({ .extension('').basename => .modified });
    my $extension = $format eq 'html' ?? ($single ?? '_singlefile.html' !! '.html') !! ".$format";
    my %rendered = $to.IO.dir(test => *.ends-with($extension)).map({ .extension('').basename => .modified });
    my @to-be-rendered = %docs.pairs.grep({
        %rendered{.key}:exists.not ||(%rendered{.key} < .value)
    })>>.key;
    say "Documents with .{ $format } in CWD, but not in docs/ : ", (%rendered.keys (-) %docs.keys).keys unless $quiet;
    my $nformat = ($format eq 'html' && $single) ?? 'html-extra' !! $format;
    render-files(@to-be-rendered, :$src, :$to, :$quiet, :$nformat, :$debug, :$verbose, :$pretty)
}
multi sub MAIN(
        Str:D $file,               #= a single file name that must exist in src directory
        Str :$src = 'docs',        #= the directory containing the source files, defaults to docs/
        :$to = $*CWD,              #= the directory to which the output is directed, defaults to $*CWD,
        Bool :q($quiet) = False,   #= Don't output info
        Str :$format = 'md',       #= Output file extension, must be 'html' if not 'md'
        Bool :$single = False,     #= Use ::HTML renderer, otherwise ::HTML-Extra renderer
        :$debug,                   #= apply debug parameters. Valid names are: None (default) All AstBlock BlockType Scoping Templates MarkUp
        Str :$verbose,             #= name of a template gives more detail about parameters / output
        Bool :$pretty              #= set Template response to pretty
     ) {
    exit note "｢$src\/$file.rakudoc｣ does not exist" unless "$src\/$file.rakudoc".IO ~~ :e & :f;
    my $nformat = ($format eq 'html' && $single) ?? 'html-single' !! $format;
    render-files([$file,], :$src, :$to, :$quiet, :$nformat, :$debug, :$verbose, :$pretty)
}
multi sub MAIN(
        Bool :version(:$v)! #= Return version of distribution
) { say 'Using version ', $?DISTRIBUTION.meta<version>, ' of rakuast-rakudoc-render distribution.' if $v };

multi sub render-files (@to-be-rendered, :$src, :$to, :$quiet, :$nformat where 'md', :$debug, :$verbose, :$pretty) {
    for @to-be-rendered.sort {
        my $dest = "$to\/$_";
        say "Processing ｢$src/$_.rakudoc｣ to ｢$dest.md｣" unless $quiet;
        my $p = shell ('RAKUDO_RAKUAST=1', $*EXECUTABLE, '-I.', '-MRakuDoc::Render', '--rakudoc=Markdown',
                       "$src/$_.rakudoc"), :err, :out;
        my $err = $p.err.slurp(:close);
        $err.say if $err;
        my $out = $p.out.slurp(:close);
        "$dest.md".IO.spurt($out) if $out;
    }
}
multi sub render-files (@to-be-rendered, :$src, :$to, :$quiet, :$nformat where 'html-single', :$debug, :$verbose, :$pretty) {
    for @to-be-rendered.sort {
        my $dest = "$to\/$_";
        my $from = "$src/$_.rakudoc";
        say "Processing ｢$from｣ to ｢{ $dest }_singlefile.html｣" unless $quiet;
        my $ast = $from.IO.slurp.AST;
        my %source-data = %(
            name     => $_,
            modified => $from.IO.modified,
            path     => $from.IO.path
        );
        my RakuDoc::Processor $rdp = RakuDoc::To::HTML.new.rdp;
        $rdp.debug( $debug ) with $debug;
        $rdp.verbose( $verbose ) with $verbose;
        $rdp.pretty( $pretty ) with $pretty;
        "{ $dest }_singlefile.html".IO.spurt($rdp.render($ast, :%source-data));
    }
}
multi sub render-files (@to-be-rendered, :$src, :$to, :$quiet, :$nformat where 'html', :$debug, :$verbose, :$pretty) {
    for @to-be-rendered.sort {
        my $dest = "$to\/$_";
        my $from = "$src/$_.rakudoc";
        say "Processing ｢$from｣ to ｢{ $dest }.html｣" unless $quiet;
        my $ast = $from.IO.slurp.AST;
        my %source-data = %(
            name     => $_,
            modified => $from.IO.modified,
            path     => $from.IO.path
        );
        my RakuDoc::Processor $rdp = RakuDoc::To::HTML-Extra.new.rdp;
        $rdp.debug( $debug ) with $debug;
        $rdp.verbose( $verbose ) with $verbose;
        $rdp.pretty( $pretty ) with $pretty;
        "{ $dest }.html".IO.spurt($rdp.render($ast, :%source-data));
    }
}
multi sub render-files (@to-be-rendered, :$src, :$to, :$quiet, :$nformat, :$debug, :$verbose, :$pretty) {
    note "The ｢$nformat｣ is not yet implemented, try ｢$*PROGRAM -h｣ for options"
}
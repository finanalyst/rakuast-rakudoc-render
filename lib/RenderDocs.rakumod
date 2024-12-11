use experimental :rakuast;
use RakuDoc::Render;
use RakuDoc::To::HTML;
use RakuDoc::To::HTML-Extra;
use File::Directory::Tree;

proto sub MAIN(|) is export {*}

multi sub MAIN(
        :$src = 'docs',
        :$rendered,
        Bool :q($quiet) = False,
        Str :$format = 'md',
        Bool :$single = False,
        :$debug,
        Str :$verbose,
        Bool :$pretty,
    ) {
    my $to = $rendered // $*CWD;
    my %docs = list-files( $src, < .rakudoc .rakumod >);
    my $extension = $format eq 'html' ?? ($single ?? '_singlefile.html' !! '.html') !! ".$format";
    mktree $to unless $to.IO ~~ :e & :d; # just make sure the rendered directory exist
    my %rendered = list-files( $to, ( $extension, ) );
    my @to-be-rendered = %docs.pairs.grep({
            %rendered{.key}:!exists || (%rendered{.key}<modified> < .value<modified>)
        })>>.key;
    @to-be-rendered.map({
        mktree "$to/$_".IO.dirname unless "$to/$_".IO.dirname.IO ~~ :e & :d;
    });
    unless $quiet {
        if +@to-be-rendered -> $n {
            say "New or modified files to render: $n"
        }
        else { say "All files in $src rendered to ｢$format｣ format in ｢$to/｣"}
    }
    my $nformat = ($format eq 'html' && $single) ?? 'html-extra' !! $format;
    render-files(@to-be-rendered, :$src, :$to, :$quiet, :$nformat, :$debug, :$verbose, :$pretty)
}
multi sub MAIN(
        Str:D $file,               #= a single file name that must exist in src directory
        Str :$src = 'docs',        #= the directory containing the source files, defaults to docs/
        :$rendered = 'to',         #= the directory to which the output is directed, defaults to $*CWD,
        Bool :q($quiet) = False,   #= Don't output info
        Str :$format = 'md',       #= Output file extension, must be 'html' if not 'md'
        Bool :$single = False,     #= Use ::HTML renderer, otherwise ::HTML-Extra renderer
        :$debug,                   #= apply debug parameters. Valid names are: None (default) All AstBlock BlockType Scoping Templates MarkUp
        Str :$verbose,             #= name of a template gives more detail about parameters / output
        Bool :$pretty              #= set Template response to pretty
     ) {
    exit note "｢$src\/$file.rakudoc｣ does not exist" unless "$src\/$file.rakudoc".IO ~~ :e & :f;
    my $to = $rendered.IO ~~ :e & :d ?? $rendered !! $*CWD;
    my $nformat = ($format eq 'html' && $single) ?? 'html-single' !! $format;
    render-files([$file,], :$src, :$to, :$quiet, :$nformat, :$debug, :$verbose, :$pretty)
}
multi sub MAIN(
        Bool :version(:$v)! #= Return version of distribution
) { say 'Using version ', $?DISTRIBUTION.meta<version>, ' of rakuast-rakudoc-render distribution.' if $v };

sub list-files( $src, @exts --> Hash ) {
    my @todo = $src.IO;
    my %docs;
    while @todo {
        for @todo.pop.dir -> $path {
            if $path.d { @todo.push: $path }
            elsif $path.ends-with( @exts.any ) {
                %docs{$path.relative($src).IO.extension('')} = %(
                    :$path,
                    modified => $path.modified
                )
            }
            # ignore all other files
        }
    }
    %docs
}

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
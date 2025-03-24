use experimental :rakuast;
use RakuDoc::Render;
use RakuDoc::To::HTML;
use RakuDoc::To::HTML-Extra;
use RakuDoc::To::Markdown;
use File::Directory::Tree;

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
        Bool :$force = False
    ) {
    my %docs = list-files( $src, < .rakudoc .rakumod >);
    my $extension = $format eq 'html' ?? ($single ?? '_singlefile.html' !! '.html') !! ".$format";
    mktree $to unless $to.IO ~~ :e & :d; # just make sure the rendered directory exist
    my %rendered = list-files( $to, ( $extension, ) );
    my @to-be-rendered = %docs.pairs.grep({
           $force or %rendered{.key}:!exists or (%rendered{.key}<modified> < .value<modified>)
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
        :$to = $*CWD,              #= the directory to which the output is directed, defaults to $*CWD,
        Bool :q($quiet) = False,   #= Don't output info
        Str :$format = 'md',       #= Output file extension, must be 'html' if not 'md'
        Bool :$single = False,     #= Use ::HTML renderer, otherwise ::HTML-Extra renderer
        :$debug,                   #= apply debug parameters. Valid names are: None (default) All AstBlock BlockType Scoping Templates MarkUp
        Str :$verbose,             #= name of a template gives more detail about parameters / output
        Bool :$pretty,             #= set Template response to pretty
        Bool :$force = False       #= force render of all files
     ) {
    exit note "｢$src\/$file.rakudoc｣ does not exist" unless "$src\/$file.rakudoc".IO ~~ :e & :f;
    mktree "$to/$file".IO.dirname unless "$to/$file".IO.dirname.IO ~~ :e & :d;
    my $nformat = ($format eq 'html' && $single) ?? 'html-single' !! $format;
    render-files([$file,], :$src, :$to, :$quiet, :$nformat, :$debug, :$verbose, :$pretty, :$force)
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

multi sub render-files (@to-be-rendered, :$src, :$to, :$quiet, :$nformat where 'md', :$debug, :$verbose, :$pretty, :$force) {
    # Markdown calls plugins that create extra files in the current directory, which need to be transferred
    for @to-be-rendered.sort {
        my $dest = "$to\/$_";
        my $from = "$src/$_.rakudoc";
        say "Processing ｢$from｣ to ｢{ $dest }.md｣" unless $quiet;
        my $ast = $from.IO.slurp.AST;
        my %source-data = %(
            name     => $_,
            modified => $from.IO.modified,
            path     => $from.IO.path
        );
        my RakuDoc::Processor $rdp = RakuDoc::To::Markdown.new.rdp;
        $rdp.debug( $debug ) with $debug;
        $rdp.verbose( $verbose ) with $verbose;
        $rdp.pretty( $pretty ) with $pretty;
        "$dest.md".IO.spurt($rdp.render($ast, :%source-data));
        for dir(test => *.ends-with('.svg')) {
            say "moving «$_» to «{$to}/{ .subst(/ '%2f' /, '/',:g ) }»" unless $quiet;
            .move("{$to}/{ .subst(/ '%2f' /, '/',:g ) }".IO)
        }
    }
}
multi sub render-files (@to-be-rendered, :$src, :$to, :$quiet, :$nformat where 'html-single', :$debug, :$verbose, :$pretty, :$force) {
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
multi sub render-files (@to-be-rendered, :$src, :$to, :$quiet, :$nformat where 'html', :$debug, :$verbose, :$pretty, :$force ) {
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
multi sub render-files (@to-be-rendered, :$src, :$to, :$quiet, :$nformat, :$debug, :$verbose, :$pretty, :$f ) {
    note "The ｢$nformat｣ is not yet implemented, try ｢$*PROGRAM -h｣ for options"
}

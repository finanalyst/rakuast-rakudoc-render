#!/usr/bin/env raku
use experimental :rakuast;
use RakuDoc::Render;
sub MAIN( $fn, :$test = False ) {
    my $f = $fn.ends-with('.rakudoc') ?? $fn !! $fn ~ '.rakudoc';
    exit note "$f doesn't exist" unless $f.IO ~~ :e & :f;
    my $ast = $f.IO.slurp.AST;
    my %source-data = %(
        name     => $fn,
        modified => $f.IO.modified,
        path     => $f.IO.path
    );
    my RakuDoc::Processor $rdp .= new( :$test );
    note "Using {$rdp.templates.source}";
    ($f ~ ( $test ?? '.test' !! '') ~ '.text').IO.spurt: $rdp.render($ast, :%source-data);
}
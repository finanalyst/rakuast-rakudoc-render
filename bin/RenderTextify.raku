#!/usr/bin/env raku
use experimental :rakuast;
use RakuDoc::Render;
sub MAIN( $fn, :$test = False ) {
    exit note "$fn\.rakudoc doesn't exist" unless "$fn.rakudoc".IO ~~ :e & :f;
    my $ast = "$fn.rakudoc".IO.slurp.AST;
    ("$fn.rakudoc".IO.basename ~ '.text').IO.spurt: RakuDoc::Processor.new(:$test).render($ast);
}
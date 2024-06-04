#!/usr/bin/env raku
use v6.d;

sub MAIN(:$module = 'lib/RakuDoc/Render.rakumod', :$method, :$dest="docs") {
    exit note "Could not find $module" unless $module.IO ~~ :e & :f;
    exit note "No directory $dest" unless $dest.IO ~~ :e & :d;
    with $method {
        process(:$module, :$method, :$dest )
    }
    else {
        for <test-text-templates default-text-templates > {
            process( :$module, :$dest, :method($_) )
        }
    }

}
sub process(:$module, :$method, :$dest ) {
    my %data;
    my Bool $code = False;
    my $ln;
    my @desc;
    my $start = False;
    for $module.IO.lines {
        if m/ 'method' \s+ $method / {
            $start = ! $start;
            next
        }
        next unless $start;
        next if m/ ^ \h* '%(' \h* $ /; # skip start of template hash defn
        next if m/ ^ \s* $ /; # skip blank line
        next if m/ ^ \s* '##' /; # skip template comment
        last if m/ ^ \h* '); # END OF TEMPLATES' /; # stop at end of template hash defn
        if m/
            $<name> = (<[\w] + [ \- ]>+ | '_name') \h*
            '=> -> %' 'prm'?
            ', $' 'tmpl'?
            \h* '{'
            /
        {
            %data{ ~$/<name>.trim } = @desc.clone;
            @desc = ()
        }
        elsif m/ ^ \s+ '#|' \s / {
            @desc.push: $/.postmatch.subst(/ '|' /, '&#124;', :g);
        }
    }
    my $rakudoc = qq:to/HEAD/;
        =begin rakudoc
        =TITLE Templates in C\<{ $method }>
        =SUBTITLE Auto generated from C\<{ $module }>
        =begin table
            =row :header
                =cell Name
                =cell Description
        HEAD
    for %data.sort(*.key)>>.kv -> ($name, @des) {
        my $descs = +@des;
        my $span = max(1, $descs);
        my $name-part;
        my $desc-part;

        if $span == 1 {
            $name-part = "=for cell \:label\n\t\t$name";
            $desc-part = "=cell V\«{ $descs[0] }»";
        }
        else {
            $name-part = "=column\n\t\t\t=for cell \:label \:row-span($span)\n\t\t\t$name";
            $desc-part = "=column\n\t\t\t" ~ (gather for @des.list { take "=cell V\«$_»" }).join("\n\t\t\t");
        $rakudoc ~= qq:to/ROW/;
                =row
                    $name-part
                    $desc-part
            ROW
        }
    }
    $rakudoc ~= q:to/END/;
        =end table
        =end rakudoc
        END

    "$dest/$method.rakudoc".IO.spurt($rakudoc);
}

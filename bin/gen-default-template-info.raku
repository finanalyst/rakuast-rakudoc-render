#!/usr/bin/env raku
use v6.d;

sub MAIN(:$module = 'lib/RakuDoc/Render.rakumod', :$method = 'default-text-templates', :$dest="docs") {
    exit note "Could not find $module" unless $module.IO ~~ :e & :f;
    exit note "No directory $dest" unless $dest.IO ~~ :e & :d;

    use lib '.';
    use RakuDoc::Render;
    my @check = RakuDoc::Processor.new.default-text-templates.keys;
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
    say "Keys in check, not in data: ", @check (-) %data.keys if @check (-) %data.keys;
    my $rakudoc = qq:to/HEAD/;
        =begin rakudoc
        =TITLE Templates in C\<{ $method }>
        =SUBTITLE Auto generated from C\<{ $module }>
        =begin table :caption<Documentation of default templates >
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
            $name-part = "=for cell \:label\n$name";
            if @des[0] {
                $desc-part = "=cell V\«{ @des[0] }»";
            }
            else {
                $desc-part = "=cell B<I<No documentation for this template>>"
            }
        }
        else {
            $name-part = "=column\n=for cell \:label \:row-span($span)\n$name";
            $desc-part = "=column\n" ~ (gather for @des.list { take "=cell V\«$_»" }).join("\n");
        }
        $rakudoc ~= qq:to/ROW/;
            =row
            $name-part
            $desc-part
            ROW
    }
    $rakudoc ~= q:to/END/;
        =end table
        =end rakudoc
        END

    "$dest/$method.rakudoc".IO.spurt($rakudoc);
}

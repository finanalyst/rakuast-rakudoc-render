use experimental :rakuast;
use RakuDoc::Render;
use RakuDoc::PromiseStrings;
use RakuAST::Deparse::Highlight;

unit class RakuDoc::To::PDF;
has RakuDoc::Processor $.rdp .=new;

submethod TWEAK {
}

#!/usr/bin/perl
use strict;
use warnings;
#use diagnostics;
use utf8;
my $PROGRAMNAME = "Unit Tester";
my $version = "inf";

use Getopt::Long;
use lib "./modules/";
use skrDebug;
my $conffilename = 'config.ini';
my $debug = 0; # verblevel
sub howVerbose { return $debug; }


print "\n[I] Loading modules...";

require Sui; # My Data stores
require Common;
require FIO;
require PGUI; # Prima GUI

FIO::loadConf($conffilename);
FIO::config('Debug','v',howVerbose());
# other defaults:
foreach (Sui::getDefaults()) {
	FIO::config(@$_) unless defined FIO::config($$_[0],$$_[1]);
}

use Prima qw(Application Buttons MsgBox FrameSet Edit );
my $gui = PGK::createMainWin($PROGRAMNAME,$version);
my $text = $$gui{status};

my $parent = $$gui{mainWin};
my $pagelen = 17;

my $files = $parent->insert( FilePager => name => 'pager for files',);
$files->build(control => 'buttons', mask => 'dsc', dir => 'lib', action => \&thiswith, pagelen => $pagelen);
$files->test();



#my $pages = $parent->insert( Pager => name => 'pager34');
#PGK::grow($pages, boxfill => 'none', boxex => 1, margin => 7);
#$pages->control('buttons');
#$pages->build();
my @colors = (10,12,13,14,5);
my @buttons = qw( red orange yellow green blue indigo violet solid striped dotted underlined focused witty slow fast big small good bad indifferent );
my $bgcol = Common::getColors($colors[0],1,1);
#my $a = $pages->insert_to_page(0,VBox => name => "page0", backColor => PGK::convertColor($bgcol), pack => { fill => 'both', expand => 1, } );
#$a->insert( Label => text => "Page 1 is here!");
#buildPageOf($a,\&thiswith,$pagelen,0,@buttons);
foreach my $c (1 .. $#colors) {
	next if $c > scalar @buttons / $pagelen;
#	$bgcol = Common::getColors($colors[$c],1,1);
#	my $b = $pages->insert_to_page($c,VBox => name => "page$c", backColor => PGK::convertColor($bgcol), pack => { fill => 'both', expand => 1, } );
#	$b->insert( Label => text => "Page " . ($c +1) . " is here!");
#	$pages->setSwitchAction("page$c",sub { buildPageOf($b,\&thiswith,$pagelen,$c * $pagelen,@buttons); $pages->setSwitchAction("page$c",sub {}); });
}

sub thiswith {
	my $file = shift;
	print "This is $file!\n";
}

sub buildPageOf {
	my ($target,$action,$count,$offset,@list) = @_;
	my $length = scalar @list -1;
	unless ($length >= $count + $offset) {
		unless ($length < $offset) {
			$count = scalar @list - $offset;
		} else {
			$count = 0;
		}
	}
	foreach my $i ($offset..$offset + $count - 1) {
		PGK::grow($target->insert(Button => text => $list[$i], onClick => sub { $action->($list[$i]) }, ),boxfill => 'x', boxex => 0, marginx => 7, marginy => 0);
	}
}

# skrDebug::dump($pages);

$text->push("Ready.");
Options::formatTooltips();
print "\n";
Prima->run();
print "Exiting normally\n";
1;

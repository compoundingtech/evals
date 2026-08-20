#!/usr/bin/env perl
use strict;
use warnings;

$| = 1;
system("stty raw -echo");
open(my $log, ">>", "$ENV{CATALOG}/deliveries.log") or die "open deliveries: $!";
select((select($log), $| = 1)[0]);

sub idle {
    print "\e[2J\e[H\e[1m›\e[1C\e[22;2mFind and fix a bug in \@filename\r\n\r\n";
    print "  \e[0mgpt-5.6-sol xhigh · /workspace";
}

sub staged {
    my ($text) = @_;
    print "\e[2J\e[H\e[1m›\e[1C\e[0m$text\r\n\r\n";
    print "  \e[0mgpt-5.6-sol xhigh · /workspace";
}

sub accepted {
    my ($text) = @_;
    print "\e[2J\e[H\e[1m›\e[1C\e[0m$text\r\n\r\n";
    print "\e[1m›\e[1C\e[22;2mFind and fix a bug in \@filename\r\n\r\n";
    print "  \e[0mgpt-5.6-sol xhigh · /workspace";
}

idle();

my $buffer = "";
my $payload;
while (1) {
    my $chunk = "";
    my $read = sysread(STDIN, $chunk, 4096);
    last if !defined($read) || $read == 0;
    $buffer .= $chunk;

    if (!defined($payload) && $buffer =~ s/.*?\e\[200~(.*?)\e\[201~//s) {
        $payload = $1;
        staged($payload);
    }
    if (defined($payload) && $buffer =~ s/^[^\r\n]*[\r\n]//s) {
        $payload =~ s/[\r\n]+/ /g;
        print {$log} "$payload\n";
        accepted($payload);
        undef($payload);
    }
}

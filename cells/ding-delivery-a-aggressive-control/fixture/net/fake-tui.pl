#!/usr/bin/env perl
use strict;
use warnings;

$| = 1;
system("stty raw -echo");
open(my $log, ">>", "$ENV{CATALOG}/deliveries.log") or die "open deliveries: $!";
select((select($log), $| = 1)[0]);
print "\e[2J\e[Hsynthetic aggressive composer ready\r\n";

my $buffer = "";
my $payload;
while (1) {
    my $chunk = "";
    my $read = sysread(STDIN, $chunk, 4096);
    last if !defined($read) || $read == 0;
    $buffer .= $chunk;

    if (!defined($payload) && $buffer =~ s/.*?\e\[200~(.*?)\e\[201~//s) {
        $payload = $1;
    }
    if (defined($payload) && $buffer =~ s/^[^\r\n]*[\r\n]//s) {
        $payload =~ s/[\r\n]+/ /g;
        print {$log} "$payload\n";
        undef($payload);
    }
}

#!/usr/bin/perl

package OSGi::Osgish::Command;
use strict;
use POSIX qw(strftime);
use Term::Clui;

use Getopt::Long qw(GetOptionsFromArray);

sub new { 
    my $class = shift;
    my $context = shift;
    my $self = ref($_[0]) eq "HASH" ? $_[0] : {  @_ };
    bless $self,(ref($class) || $class);
    $self->ctx($context);
    return $self;
}

sub global_commands { 
    return undef;
}

sub top_commands { 
    return undef;
}

sub ctx {
    my ($self,$val) = @_;
    my $ret = $self->{context};
    if ($#_ > 0) {
        $self->{context} = $val;
    }
    return $ret;
}

sub complete {
    return shift->{context}->complete;
}

sub osgish {
    return shift->{context}->osgish;
}

# For a command, extract args and options
sub extract_command_args {
    my ($self,$spec,@args) = @_;
    my $opts = {};
    GetOptionsFromArray(\@args, $opts,@{$spec});
    return ($opts,@args);
}

sub format_date {
    my $self = shift;
    my $time = shift;
    if (time - $time > 60*60*24*365) {
        return strftime "%b %d %Y",localtime($time);
    } else {
        return strftime "%b %d %H:%M",localtime($time);
    }
}

sub print_paged {
    my $self = shift;
    my $text = shift;
    my $nr = shift;
    if (defined($nr) && $nr < 24) {
        print $text;
    } else {
        view("",$text);
    }
}

sub trim_string {
    my $self = shift;
    my $string = shift;
    my $max = shift;
    return length($string) > $max ? substr($string,0,$max-3) . "..." : $string;
}

# Convert * and . to proper regexp
sub convert_wildcard_pattern_to_regexp {
    my $self = shift;
    my $wildcard = shift;
    $wildcard =~ s/\?/./g;
    $wildcard =~ s/\*/.*/g;
    return qr/^$wildcard$/;
}

1;

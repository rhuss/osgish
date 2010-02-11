#!/usr/bin/perl

package OSGi::Osgish;

use strict;
use Term::ANSIColor qw(:constants);
use OSGi::Osgish::Shell;
use OSGi::Osgish::ServerHandler;
use OSGi::Osgish::CompletionHandler;
use OSGi::Osgish::CommandHandler;
use Data::Dumper;
use vars qw($VERSION);

$VERSION = "0.1.0_3";

=head1 NAME 

OSGi::Osgish - Main osgish object 

=head1 DESCRIPTION

This object is pushed to commands and allows access to all relevant
informations shared between commands. A command should consult the 
osgish object when performing its operation for contacting the OSGi server. 
The osgish object gets updated in the background e.g. when the server changes. 

=cut

=head1 METHODS

=over

=item $osgish = new OSGi::Osgish(agent => $agent,...)


=cut

sub new { 
    my $class = shift;
    my $self = ref($_[0]) eq "HASH" ? $_[0] : {  @_ };
    bless $self,(ref($class) || $class);
    $self->_init();
    return $self;
}


=item $agent = $osgish->agent

Access to the agent object for accessing to the connected server. If there 
is no connected server, this methods returns C<undef>

=cut 

sub agent {
    my ($self,$val) = @_;
    my $ret = $self->{agent};
    if ($#_ > 0) {
        $self->{agent} = $val;
    }
    return $ret;
}

sub complete {
    return shift->{complete};
}

sub commands {
    return shift->{commands};
}

sub servers {
    return shift->{servers};
}

sub server {
    return shift->{servers}->{server};
}

sub color { 
    return shift->{shell}->color(@_);
}

sub run {
    my $self = shift;
    $self->{shell}->run;
}

sub last_error {
    my $self = shift;
    my $osgi = $self->agent;
    return $osgi->last_error if $osgi && $osgi->last_error;
    return $self->{last_error};
}

sub _init {
    my $self = shift;
    $self->{complete} = new OSGi::Osgish::CompletionHandler($self);
    $self->{servers} = new OSGi::Osgish::ServerHandler($self);
    $self->{shell} = $self->_create_shell;
    $self->{commands} = new OSGi::Osgish::CommandHandler($self,$self->{shell});
}

sub _create_shell {
    my $self = shift;
    my $use_color;
    if (exists $self->{args}->{color}) {
        $use_color = $self->{args}->{color};
    } elsif (exists $self->{config}->{use_color}) {
        $use_color = $self->{args}->{color};
    } else {
        $use_color = 1;
    }
    return new OSGi::Osgish::Shell(use_color => $use_color);
}

1;



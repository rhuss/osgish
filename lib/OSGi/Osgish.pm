#!/usr/bin/perl

package OSGi::Osgish;

use strict;
use Term::ANSIColor qw(:constants);
use OSGi::Osgish::ServerHandler;
use OSGi::Osgish::Completion;
use OSGi::Osgish::CommandHandler;
use Data::Dumper;

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
    return shift->_get_set("agent",@_);
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

sub run {
    my $self = shift;
    $self->{commands}->run;
}

sub use_color {
    my $self = shift;
    my $use_color = $self->{opts}->{color} || 1;
    $use_color = 0 if $use_color =~ /^(no|never|false)$/i;
    return $use_color;
}

sub color { 
    my $self = shift;
    my @colors = @_;
    my $args = ref($colors[$#colors]) eq "HASH" ? pop @colors : {};
    if ($self->use_color) {
        if ($args->{escape}) {
            return map { "\01" . $self->_resolve_color($_) . "\02" } @colors;
        } else {
            return map { $self->_resolve_color($_) } @colors;
        }
    } else {
        return map { "" } @colors;
    }
}

sub last_error {
    my $self = shift;
    my $osgi = $self->agent;
    return $osgi->last_error if $osgi && $osgi->last_error;
    return $self->{last_error};
}

sub color_theme {
    return shift->_get_set("color_theme",@_);
}

sub _init {
    my $self = shift;
    $self->{complete} = new OSGi::Osgish::Completion($self);
    $self->{servers} = new OSGi::Osgish::ServerHandler($self);
    $self->{commands} = new OSGi::Osgish::CommandHandler($self);
    $self->{commands}->register_commands($self);

    # For now, we return a fixed theme:
    $self->{color_theme} = { 
                            host => YELLOW,
                            bundle_active => GREEN,
                            bundle_inactive => RED,
                            service_id => GREEN,
                            service_interface => undef,
                            service_using => RED,
                            prompt_context => CYAN,
                            prompt_empty => RED,
                            upload_installed => GREEN,
                            upload_uninstalled => RED
                           };
}

sub _init_term {
    my $self = shift;
    # Force pipe, quit if less than a screen-full.
    my @args = ('-f','-E','-X');
    if ($self->use_color) {
        # Raw characters
        push @args,'-r';
    }
    if ($ENV{LESS}) {
        my $l = "";
        for my $a (@args) {
            $l .= $a . " " unless $ENV{LESS} =~ /$a/;
        }
        if (length($l)) {
            chop $l;
            $ENV{LESS} .= " " . $l;
        }
    } else {
        $ENV{LESS} = join " ",@args;
    }
}

sub _get_set {
    my ($self,$key,$val) = @_;
    my $ret = $self->{$key};
    if ($#_ > 1) {
        $self->{$key} = $val;
    }
    return $ret;
}

sub _resolve_color {
    my $self = shift;
    my $c = shift;
    my $color = $self->{color_theme}->{$c};
    if (exists($self->{color_theme}->{$c})) {
        return defined($color) ? $color : "";
    } else {
        return $c;
    }
}



1;



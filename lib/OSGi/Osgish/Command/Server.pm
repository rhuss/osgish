#!/usr/bin/perl

package OSGi::Osgish::Command::Server;
use strict;
use vars qw(@ISA);
use Term::ANSIColor qw(:constants);

@ISA = qw(OSGi::Osgish::Command);

sub name { "server" }


sub top_commands {
    my $self = shift;
    return {
            "servers" => { 
                          desc => "Show all configured servers",
                          proc => $self->cmd_server_list
                         },
            "connect" => { 
                          desc => "Connect to a server by its URL or symbolic name",
                          minargs => 1, maxargs => 2,
                          args => $self->complete->servers,
                          proc => $self->cmd_connect
                         },
           };
}

# Connect to a server
sub cmd_connect {
    my $self = shift;
    return sub {
        my $arg = shift;
        my $name = shift;
        my $osgish = $self->osgish;
        $osgish->servers->connect_to_server($arg,$name);
        $osgish->commands->reset_stack;
        my ($yellow,$reset) = $osgish->color("host",RESET);
        print "Connected to " . $yellow . $osgish->server . $reset .  " (" . $osgish->agent->url . ").\n";
    }
}

# Show all servers
sub cmd_server_list {
    my $self = shift;
    return sub {
        my $osgish = $self->osgish;
        my $server_list = $osgish->servers->list;
        for my $s (@$server_list) {
            my ($ms,$me) = $osgish->color("host",RESET);
            my $sep = $s->{from_config} ? "-" : "*";
            printf " " . $ms . '%30.30s' . $me . ' %s %s' . "\n",$s->{name},$sep,$s->{url};
        }
    }
}

1;

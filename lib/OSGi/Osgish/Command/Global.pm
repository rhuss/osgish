#!/usr/bin/perl

package OSGi::Osgish::Command::Global;
use strict;
use vars qw(@ISA);
use Term::ANSIColor qw(:constants);
use Term::Clui;

@ISA = qw(OSGi::Osgish::Command);

sub name { "global" }

sub global_commands {
    my $self = shift;
    my $osgi = $self->osgish;
    
    return 
        {
         "error" => {
                     desc => "Show last error (if any)",
                     proc => $self->cmd_last_error
                    },
         "help" => {
                    desc => "Print online help",
                    args => sub { shift->help_args(undef, @_); },
                    method => sub { shift->help_call(undef, @_); }
                   },
         "h" => { alias => "help", exclude_from_completion=>1},
         "quit" => {
                    desc => "Quit",
                    maxargs => 0,
                    method => sub { shift->exit_requested(1); }
                   },
         "q" => { alias => 'quit', exclude_from_completion => 1 },
         $osgi ? ("shutdown" => {
                                 desc => "Shutdown server",
                                 proc => $self->cmd_shutdown
                                }) : ()
        };
}

# Shutdown a server
sub cmd_shutdown {
    my $self = shift;
    return sub {
        my $ctx = $self->ctx;
        my $osgi = $ctx->osgish;
        unless ($osgi) {
            print "Not connected to a server\n";
            return;
        }
        my ($yellow,$reset) = $ctx->color("host",RESET);
        my $server = $ctx->server;
        my $answer = &choose("Really shutdown " . $yellow . $server . $reset . " ?","yes","no");
        if ($answer eq "yes") {
            $osgi->shutdown;
            $ctx->osgish(undef);
            $ctx->commands->reset_stack;
        } else {
            print "Shutdown of ". $yellow . $server . $reset . " cancelled\n";
        }
    }
}


sub cmd_last_error {
    my $self = shift;
    return sub {
        my $osgi = $self->ctx->osgish;
        my $txt = $self->ctx->last_error;
        if ($txt) { 
            chomp $txt;
            print "$txt\n";
        } else {
            print "No errors\n";
        }
    }
}

1;

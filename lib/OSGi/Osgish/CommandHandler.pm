#!/usr/bin/perl

package OSGi::Osgish::CommandHandler;

use strict;
use Term::ANSIColor qw(:constants);
use Term::ShellUI;
use Data::Dumper;

sub new { 
    my $class = shift;
    my $osgish = shift || "No osgish object given";    
    my $self = {
                osgish => $osgish
               };
    $self->{stack} = [];
    bless $self,(ref($class) || $class);
    my $term = new Term::ShellUI(
                                 commands => sub { $self->top_commands },
                                 history_file => "~/.agent_history",
                                 prompt => $self->prompt
                                );
    $self->{term} = $term;
    return $self;
}

sub register_commands { 
    my $self = shift;
    my $context = shift || die "No context given";

    # TODO: For now a fix list of commands, let them be looked up dynamically
    my @modules = ( "OSGi::Osgish::Command::Bundle",
                    "OSGi::Osgish::Command::Global",
                    "OSGi::Osgish::Command::Server",
                    "OSGi::Osgish::Command::Service",
                    "OSGi::Osgish::Command::Upload",                    
                  );
    my $commands = {};
    my $top = {};
    my $globals = {};
    for my $module (@modules) {
        my $file = $module;
        $file =~ s/::/\//g;
        require $file . ".pm";
        $module->import;
        my $command = eval "$module->new(\$context)";
        die "Cannot register $module: ",$@ if $@;
        $commands->{$command->name} = $command;
        my $top_cmd = $command->top_commands;
        if ($top_cmd) {
            $top->{$command->name} = $command;
        }
        my $global_cmd = $command->global_commands;
        if ($global_cmd) {
            $globals->{$command->name} = $command;
        }
    }
    $self->{commands} = $commands;
    $self->{top_commands} = $top;
    $self->{global_commands} = $globals;
}

# Run ShellUI and never return. Provide some special
# ReadLine treatment
sub run {
    my $self = shift;
    my $t = $self->{term};
    $t->{term}->ornaments(0);
    
    # Special readline customization for Term::ReadLine::Perl
    if ($t->{term}->ReadLine eq "Term::ReadLine::Perl") {
        $self->{no_color_prompt} = 1;
    }
    #$t->{debug_complete}=5;
    $self->reset_stack;
    $t->run;
}

sub prompt {
    my $self = shift;
    my $osgish = $self->{osgish};
    return sub {
        my $term = shift;
        my $stack = $self->{stack};
        my $osgi = $osgish->agent;
        my ($yellow,$cyan,$red,$reset) = 
          $self->{no_color_prompt} ? ("","","","") : $osgish->color("host","prompt_context","prompt_empty",RESET,{escape => 1});
        my $p = "[";
        $p .= $osgi ? $yellow . $osgish->server : $red . "osgish";
        $p .= $reset;
        $p .= ":" . $cyan if @$stack;
        for my $i (0 .. $#{$stack}) {
            $p .= $stack->[$i]->{name};
            $p .= $i < $#{$stack} ? "/" : $reset;
        }
        $p .= "] : ";
        return $p;
    };
}

sub update_stack {
    my $self = shift;
    # The new context
    my $context = shift;
    # Sub-commands within the context
    my $sub_cmds = shift;
    # Don't update context
    my $skip_context = shift;
    my $contexts = $self->{stack};
    push @$contexts,{ name => $context, cmds => $sub_cmds } unless $skip_context;
    #print Dumper(\@contexts);

    my $term = $self->{term};
    # Set sub-commands
    $term->commands
      ({
        %$sub_cmds,
        %{$self->global_commands},
        %{$self->navigation_commands},
       }
      );    
}

sub navigation_commands {
    my $self = shift;
    my $term = $self->{term};
    my $contexts = $self->{stack};
    if (@$contexts > 0) {
        return 
            {".." => {
                      desc => "Go up one level",
                      proc => 
                      sub { 
                          my $stack = $self->{stack};
                          my $parent = pop @$stack;
                          if (@$stack > 0) {
                              $term->commands
                                ({
                                  %{$stack->[$#{$stack}]->{cmds}},
                                  %{$self->global_commands},
                                  %{$self->navigation_commands},
                                 }
                                );    
                          } else { 
                              $term->commands($self->top_commands);
                          }
                      }
                     },
             "/" => { 
                     desc => "Go to the top level",
                     proc => 
                     sub { 
                         $self->reset_stack();
                     }
                    }
            };
    } else {
        return {};
    }
}

sub command {
    my $self = shift;
    my $name = shift || die "No command name given";
    return $self->{commands}->{$name};
}

sub global_commands {
    my $self = shift;
    my $globals = $self->{global_commands};
    my @ret = ();
    for my $command (values %$globals) {
        push @ret, %{$command->global_commands};        
    }
    return { @ret };
}

sub top_commands {
    my $self = shift;
    my $top = $self->{top_commands};
    my @ret = ();
    for my $command (values %$top) {
        push @ret, %{$command->top_commands};        
    }
    return { @ret };
}

sub _merged_commands {
    my $self = shift;
    my $context = 
    my $commands = shift;
}

sub reset_stack {
    my $self = shift;
    my $term = $self->{term};
    $term->commands({ %{$self->top_commands}, %{$self->global_commands}});
    $self->{stack} = [];
}

1;



1;



#!/usr/bin/perl

package OSGi::Osgish::Command::Service;
use strict;
use vars qw(@ISA);
use Term::ANSIColor qw(:constants);
use Data::Dumper;

@ISA = qw(OSGi::Osgish::Command);

sub name { "service" }

sub top_commands {
    my $self = shift;
    return $self->agent ? $self->commands : {};
}

# Commands in context "service"
sub commands {
    my $self = shift;
    my $cmds = $self->sub_commands;
    return {
            "service" => { 
                          desc => "Service related operations",
                          proc => $self->push_on_stack("service",$cmds),
                          cmds => $cmds 
                         },
            "s" => { alias => "service", exclude_from_completion => 1},
            "serv" => { alias => "service", exclude_from_completion => 1}
           };
}

sub sub_commands {
    my $self = shift;
    return 
        { 
         "ls" => { 
                  desc => "List all services",
                  proc => $self->cmd_service_list,
                  args => $self->complete->services(no_ids => 1) 
                 },
#         "bls" => { 
#                   desc => "List bundles",
#                   proc => \&cmd_bundle_list,
#                   args => sub { &complete_bundles(@_,no_ids => 1) }                      
#                  },
        };    
}


# =================================================================================================== 

sub cmd_service_list { 
    my $self = shift;
    return sub {
        my $osgish = $self->osgish;
        my $osgi = $osgish->agent;
        print "Not connected to a server\n" and return unless $osgi;
        my $services = $osgi->services;
        my ($opts,@filters) = $self->extract_command_options(["u=s","b=s"],@_);
        
        my $filtered_services = $self->filter_services($services,$opts,@filters);
        return unless @$filtered_services;
        
        my $text = sprintf("%4.4s  %-62.62s  %5.5s | %s\n","Id","Classes","Bd-Id","Using bundles");
        $text .= "-" x 76 . "+" . "-" x 24 . "\n";
        my $nr = 0;
        for my $s (sort { $a->{Identifier} <=> $b->{Identifier} } @{$filtered_services}) {
            my $id = $s->{Identifier};
            my ($c_id,$c_interf,$c_using,$r) = $osgish->color("service_id","service_interface","bundle_id",RESET);
            my $using_bundles = $s->{UsingBundles} || [];
            my $using = $using_bundles ? join (", ",sort { $a <=> $b } @$using_bundles) : "";
            my $bundle_id = $s->{BundleIdentifier};
            my $classes = $s->{objectClass};
            $text .= sprintf "%s%4d%s  %s%-65.65s%s %s%3d%s | %s\n",$c_id,$id,$r,$c_interf,$self->trim_string($classes->[0],65),$r,$c_using,$bundle_id,$r,$using;
            for my $i (1 .. $#$classes) {
                $text .= sprintf "      %s%-69.69s%s |\n",$c_interf,$self->trim_string($classes->[$i],69),$r;
            }
            $nr++;
        }
        $self->print_paged($text,$nr);
    }
}

# Filter services according to one or more criteria
sub filter_services {
    my $self = shift;
    my ($services,$opts,@filters) = @_;
    my %found = ();
    my $rest = [values %$services];
    my $filtered = undef;
    if (defined($opts->{u})) {
        die "No numeric bundle-id ",$opts->{u} unless $opts->{u} =~ /^\d+$/;
        for my $s (@$rest) {
            if (grep { $_ == $opts->{u} } @{$s->{UsingBundles}}) {
                $found{$s->{Identifier}} = $s;
            } 
        }
        $filtered = 1;
        $rest = [values %found];
    } 
    if ($opts->{b}) {
        die "No numeric bundle-id ",$opts->{b} unless $opts->{b} =~ /^\d+$/;
        for my $s (@$rest) {
            if ($s->{BundleIdentifier} == $opts->{b}) {
                $found{$s->{Identifier}} = $s;
            } elsif ($filtered) {
                delete $found{$s->{Identifier}};
            }
        }
        $filtered = 1;
        $rest = [values %found];
    }
    if (@filters) {
        for my $f (@filters) {
            my $regexp = $self->convert_wildcard_pattern_to_regexp($f);
            for my $s (@$rest) {
                if (grep { $_ =~ $regexp } @{$s->{objectClass}}) {
                    $found{$s->{Identifier}} = $s;
                } elsif ($filtered) {
                    delete $found{$s->{Identifier}};
                }
            }
        }
        $filtered = 1;
        $rest = [values %found];
    }
    return $rest;
}

1;

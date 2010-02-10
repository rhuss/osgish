#!/usr/bin/perl

package OSGi::Osgish::Command::Bundle;
use strict;
use vars qw(@ISA);
use Term::ANSIColor qw(:constants);
use OSGi::Osgish::Command;
use Data::Dumper;

@ISA = qw(OSGi::Osgish::Command);

sub name { "bundle" }

sub top_commands {
    my $self = shift;
    return $self->agent ? $self->sub_commands : {};
}

# Commands in context "bundle"
sub commands {
    my $self = shift;
    my $cmds = $self->sub_commands; 
    return  {
             "bundle" => { 
                          desc => "Bundles related operations",
                          proc => sub { 
                              $self->osgish->commands->update_stack("bundle",$cmds) 
                          },
                          cmds => $cmds
                         },
                      "b" => { alias => "bundle", exclude_from_completion => 1},
            };
}

sub sub_commands {
    my $self = shift;
    return {
            "ls" => { 
                     desc => "List bundles",
                     proc => $self->cmd_bundle_list,
                     args => $self->complete->bundles(no_ids => 1)
                    },
            "start" => { 
                        desc => "Start a bundle",
                        proc => $self->cmd_bundle_start,
                        args => $self->complete->bundles
                       },
            "stop" => { 
                       desc => "Stop a bundle",
                       proc => $self->cmd_bundle_stop,
                       args => $self->complete->bundles
                      }
           };
}

# =================================================================================================== 

# List bundles
sub cmd_bundle_list {
    my $self = shift; 
    
    return sub {
        my $osgish = $self->osgish;
        my $osgi = $osgish->agent;
        print "Not connected to a server\n" and return unless $osgi;
        my ($opts,@filters) = $self->extract_command_args(["s!"],@_);
        my $bundles = $osgi->bundles;
        my $text = sprintf("%4.4s   %-11.11s %3s %s\n","Id","State","Lev","Name");
        $text .= "-" x 87 . "\n";
        my $nr = 0;
        
        my $filtered_bundles = $self->filter_bundles($bundles,$opts,@filters);
        return unless @$filtered_bundles;
        
        if (@$filtered_bundles == 1) {
            # Print single info for bundle
            $self->print_bundle_info($filtered_bundles->[0],$opts);
        } else {
            for my $b (sort { $a->{Identifier} <=> $b->{Identifier} } @$filtered_bundles) {
                my $id = $b->{Identifier};
                my ($green,$red,$reset) = $osgish->color("bundle_active","bundle_inactive",RESET);
                my $state = lc $b->{State};
                my $color = "";
                $color = $red if $state eq "installed";
                $color = $green if $state eq "active";
                my $state = uc(substr($state,0,1)) . substr($state,1);
                my $level = $b->{StartLevel};
                
                my $name = $b->{Headers}->{'[Bundle-Name]'}->{Value};
                my $sym_name = $b->{SymbolicName};
                my $version = $b->{Version};
                my $location = $b->{Location};
                my $desc = $opts->{s} ? 
                  $sym_name || $location :
                    $name || $sym_name || $location;
                $desc .= " ($version)" if $version && $version ne "0.0.0";
                
                $text .= sprintf "%s%4d   %-11s%s %3d %s%s%s\n",$color,$id,$state,$reset,$level,$desc; 
                $nr++;
            }
            $self->print_paged($text,$nr);
        }
        #print $text;
        #print Dumper($bundles);
    }
}

sub cmd_bundle_start {
    my $self = shift;
    return sub { 
        my $bundle = shift;
        $self->agent->start_bundle($bundle);
    }
}

sub cmd_bundle_stop {
    my $self = shift;
    return sub { 
        my $bundle = shift;
        $self->agent->stop_bundle($bundle);
    }
}

sub print_bundle_info {
    my $self = shift;

    my $bu = shift;
    my $opts = shift;
    my $name = $bu->{Headers}->{'[Bundle-Name]'}->{Value};
    printf("Name:          %s\n",$name) if $name;
    printf("Symbolic-Name: %s\n",$bu->{SymbolicName});
    printf("Location:      %s (%s)\n",$bu->{Location},$self->format_date($bu->{LastModified}/1000));
    my $imports = $bu->{ImportedPackages};
    my $label = "Imports:";
    for my $i (sort @$imports) {
        my ($p,$v) = ($1,$2) if $i =~ /(.*?);(.*)?/;
        printf("%-14.14s %s (%s)\n",$label,$p,$v);
        $label = "";
    }
    my $headers = $bu->{Headers};
    $label = "Headers:";
    #print Dumper($headers);
    for my $h (sort { $headers->{$a}->{Key} cmp $headers->{$b}->{Key} } keys %$headers) {
        printf("%-14.14s %s = %s\n",$label,$headers->{$h}->{Key},$headers->{$h}->{Value});
        $label = "";
    }
    #print Dumper($bu);
}

# Filter bundles according to some criteria
sub filter_bundles {
    my $self = shift;
    my ($bundles,$opts,@filters) = @_;

    if (@filters) {
        my %filtered_bundles;
        for my $f (@filters) {
            my $regexp = $self->convert_wildcard_pattern_to_regexp($f);
            for my $b (values %$bundles) {
                if ($b->{SymbolicName} =~ $regexp || ($f =~ /^\d+$/ && $b->{Identifier} == $f)) {
                    $filtered_bundles{$b->{Identifier}} = $b;
                }
            }
        }
        return [values %filtered_bundles];
    } else {
        return [values %$bundles];
    }
}



1;

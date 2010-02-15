#!/usr/bin/perl

package OSGi::Osgish::Command::Bundle;
use strict;
use vars qw(@ISA);
use Term::ANSIColor qw(:constants);
use OSGi::Osgish::Command;
use Data::Dumper;

@ISA = qw(OSGi::Osgish::Command);

=head1 NAME 

OSGi::Osgish::Command::Bundle - Bundle related commands

=head1 DESCRIPTION

This collection of shell commands provided access to bundle related
operations. I.e. these are

=over

=item * 

List of bundles ('ls')

=item * 

Start and Stopping of bundles ('start'/'stop')

=back

=cut

=head1 COMMANDS

=over

=cut 


sub new { 
    my $class = shift;
    my $self = $class->SUPER::new(@_); 
    $self->{csv_comma} = new Text::CSV({sep_char => ",",allow_whitespace => 1,allow_loose_quotes => 1,quote_char => '"',escape_char => "\\" });
    $self->{csv_semicolon} = new Text::CSV({ sep_char => ";",allow_whitespace => 1, allow_loose_quotes => 1,quote_char => '"',escape_char => "\\" });
    return $self;
}


# Name of this command
sub name { "bundle" }

# We hook into as top-level commands
sub top_commands {
    my $self = shift;
    return $self->agent ? $self->sub_commands : {};
}

# Context command "bundle"
sub commands {
    my $self = shift;
    my $cmds = $self->sub_commands; 
    return  {
             "bundle" => { 
                          desc => "Bundles related operations",
                          proc => $self->push_on_stack("bundle",$cmds),
                          cmds => $cmds
                         },
             "b" => { alias => "bundle", exclude_from_completion => 1},
            };
}

# The 'real' commands
sub sub_commands {
    my $self = shift;
    return {
            "ls" => { 
                     desc => "List bundles",
                     proc => $self->cmd_bundle_list,
                     args => $self->complete->bundles(no_ids => 1)
                    },
            "start" => { 
                        desc => "Start bundles",
                        proc => $self->cmd_bundle_start,
                        args => $self->complete->bundles
                       },
            "stop" => { 
                       desc => "Stop bundles",
                       proc => $self->cmd_bundle_stop,
                       args => $self->complete->bundles
                      },
            "resolve" => {
                          desc => "Resolve bundles",
                          proc => $self->cmd_bundle_resolve,
                          args => $self->complete->bundles
                         },
            "update" => {
                         desc => "Update a bundle optionally from a new location",
                         proc => $self->cmd_bundle_update,
                         args => $self->complete->bundles
                        },
            "install" => {
                            desc => "Install a bundle",
                            proc => $self->cmd_bundle_install,
                          #args => $self->complete->bundles
                           },
            "uninstall" => {
                            desc => "Uninstall bundles",
                            proc => $self->cmd_bundle_uninstall,
                            args => $self->complete->bundles
                           },
            "refresh" => {
                          desc => "Refresh bundles",
                          proc => $self->cmd_bundle_refresh,
                          args => $self->complete->bundles
                        }
           };
}

# =================================================================================================== 


=item cmd_bundle_list

List commands which can filter bundles by wildcard and knows about the
following options:

=over

=item -s

Show symbolic names instead of descriptive names

=back

If a single bundle is given as argument its details are shown.

=cut

sub cmd_bundle_list {
    my $self = shift; 
    
    return sub {
        my $osgish = $self->osgish;
        my $osgi = $osgish->agent;
        print "Not connected to a server\n" and return unless $osgi;
        my ($opts,@filters) = $self->extract_command_options(["s!"],@_);
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


=item cmd_bundle_start

Resolve one or more bundles by its id or symbolicname

=cut 

sub cmd_bundle_resolve {
    my $self = shift;
    return sub { 
        my @args = @_;
        $self->agent->resolve_bundle(@args);
    }
}


=item cmd_bundle_start

Start one or more bundles by its id or symbolicname

=cut 

sub cmd_bundle_start {
    my $self = shift;
    return sub { 
        my @args = @_;
        $self->agent->start_bundle(@args);
    }
}

=item cmd_bundle_stop

Stop one or more bundles by its id or symbolicname

=cut 

sub cmd_bundle_stop {
    my $self = shift;
    return sub { 
        my @args = @_;
        $self->agent->stop_bundle(@args);
    }
}

=item cmd_bundle_update

Update a bundle from its current location

=cut

sub cmd_bundle_update {
    my $self = shift;
    return sub {
        my $bundle = shift;
        my $location = shift;
        $self->agent->update_bundle($bundle,$location);
    }
}

=item cmd_bundle_install

Install one or more bundles

=cut

sub cmd_bundle_install {
    my $self = shift;
    return sub {
        my @args = @_;
        $self->agent->install_bundle(@args);
    }
}

=item cmd_bundle_uninstall

Uninstall one or more bundles

=cut

sub cmd_bundle_uninstall {
    my $self = shift;
    return sub {
        my @args = @_;
        $self->agent->uninstall_bundle(@args);
    }
}

=item cmd_bundle_refresh

Refresh one or more bundles

=cut

sub cmd_bundle_refresh {
    my $self = shift;
    return sub {
        my @args = @_;
        $self->agent->refresh_bundle(@args);
    }
}


# Print a single bundle's info
sub print_bundle_info {
    my $self = shift;
    my $osgish = $self->osgish;

    my $bu = shift;
    my $opts = shift;
    my $name = $bu->{Headers}->{'[Bundle-Name]'}->{Value};
    printf("Name:          %s\n",$name) if $name;
    printf("Symbolic-Name: %s\n",$bu->{SymbolicName});
    printf("Location:      %s (%s)\n",$bu->{Location},$self->format_date($bu->{LastModified}/1000));
    my $label = "Imports:";
    my $imports = $self->_extract_imports($bu->{ImportedPackages},$bu->{Headers});
    #my $exports = $self->_extract_exports($bu->{ExportedPackages});
    #$imports = $bu->{ImportedPackages};
    my ($pr,$pv,$po,$re) = $osgish->color("package_resolved","package_version","package_optional",RESET);
    for my $k (sort { $a cmp $b } keys %$imports) {
        my $val = $imports->{$k};
        my $version = $val->{version};
        if ($val->{version}) {
            $version = $pv . $version . $re;
            $version .= " " . $val->{version_spec} if $val->{version_spec};
        } else {
            $version = $val->{version_spec} if $val->{version_spec};
        }
        my $optional = $val->{optional} ? $po . "*" . $re : "";
        my $package = $k;
        $package = $pr . $package . $re if ($val->{resolved});
        printf("%-14.14s %s %s %s\n",$label,$package,$version,$optional);
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

sub _extract_imports {
    my $self = shift;
    my ($imp,$headers) = @_;
    my $imp_headers = {};
    for my $i (grep { $_->{Key} eq 'Import-Package' } values %{$headers}) {
        my $val = $i->{Value};
        $imp_headers = { %$imp_headers, %{$self->_split_property($val)} };
    }
    my $imports = {};
    for my $i (@$imp) {
        my ($package,$version) = $self->_split_package($i);
        my $e = {};
        $e->{version} = $version;
        $e->{resolved} = 1;
        if ($imp_headers->{$package}) {
            $self->_add_imp_header_info($e,$imp_headers->{$package});
        }
        $imports->{$package} = $e;
    }

    # Add unresolved imports mentioned in the header
    for my $k (keys %$imp_headers) {
        if (!$imports->{$k}) {
            my $e = $self->_add_imp_header_info({},$imp_headers->{$k});
            $e->{resolved} = 0;
            $imports->{$k} = $e;
        }
    }
    return $imports;
    #print Dumper($imports);
}

sub _add_imp_header_info {
    my $self = shift;
    my $e = shift;
    my $imp = shift;
    my $attrs = $imp->{attributes};
    my $dirs = $imp->{directives};
    ($e->{optional} = 1) && delete $dirs->{resolution} if $dirs->{resolution} eq "optional";
    $e->{version_spec} = delete $attrs->{version} if $attrs->{version};
    $e->{directives} = $dirs if %{$dirs};
    $e->{attributes} = $attrs if %{$dirs};
    return $e;
}

sub _split_package {
    my $self = shift;
    return split /;/,shift,2;
}

sub _split_property {
    my $self = shift;
    my $prop = shift;
    my $csv_c = $self->{csv_comma};
    my $csv_s = $self->{csv_semicolon};
    my $l = $prop;
    my $ret = {};
    while ($l) {
        $l =~ s/([^,]*?(".*?")*)(,|$)//;
        my $part = $1;
        my @targets = ();
        my $attrs = {};
        my $directives = {};
        while ($part) {
            $part =~ s/([^;]*?(".*?")*)(;|$)//;
            my $sub = $1;
            if ($sub =~ /^(.*):=\"?(.*?)\"?$/) {
                $directives->{$1} = $2;
            } elsif ($sub =~ /^(.*)=\"?(.*?)\"?$/) {
                $attrs->{$1} = $2;
            } else {
                push @targets,$sub;
            }
            for my $t (@targets) {
                $ret->{$t} = { }; 
                $ret->{$t}->{attributes} = $attrs if $attrs;
                $ret->{$t}->{directives} = $directives if $directives;
            }            
        }
    }
    return $ret;
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

=back

=cut


1;

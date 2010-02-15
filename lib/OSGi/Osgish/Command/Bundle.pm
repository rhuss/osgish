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
        my ($opts,@filters) = $self->extract_command_options(["s!","i!","e!","h!"],@_);
        my $bundles = $osgi->bundles;
        my $text = sprintf("%4.4s   %-11.11s %3s %s\n","Id","State","Lev","Name");
        $text .= "-" x 87 . "\n";
        my $nr = 0;
        
        my $filtered_bundles = $self->filter_bundles($bundles,@filters);
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
        my ($opts,@filters) = $self->extract_command_options(["l=s"],@_);
        my $agent = $self->osgish->agent;
        my $filtered_bundles = [map { $_->{SymbolicName} } @{$self->filter_bundles($agent->bundles,@filters)} ];
        die "No bundle to update given\n" unless @$filtered_bundles;
        #print Dumper($filtered_bundles);
        if ($opts->{l} || @$filtered_bundles == 1) {
            die "Can only update a single bundle with -l. Given : ",join(",",@$filtered_bundles),"\n"
              if @$filtered_bundles > 1;
            my $ret = $self->agent->update_bundle($filtered_bundles->[0],$opts->{l});
            print "Updated ",$filtered_bundles->[0],"\n";
        } else {
            my $ret = $self->agent->update_bundles(@$filtered_bundles);
            if ($ret->{Success} eq "true") {
                print "Updated bundles ",(join ", ",@{$ret->{Completed}}),"\n";
            } else {
                print "Error during update: ",$ret->{Error},"\n";
                print Dumper($ret);
            }
        }
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
    my $txt = "";

    $self->_dump_main_info(\$txt,$bu);
    $txt .= "\n";

    my $imports = $self->_extract_imports($bu->{ImportedPackages},$bu->{Headers},$opts->{i});
    $self->_dump_imports(\$txt,$imports,$opts);


    my $exports = $self->_extract_exports($bu->{ExportedPackages},$opts->{e});
    $self->_dump_exports(\$txt,$exports,$opts);

    $self->_dump_headers(\$txt,$bu->{Headers}) if ($opts->{h});

    $self->print_paged($txt);

    #print Dumper($bu);
}

sub _dump_main_info {
    my $self = shift;
    my $ret = shift;
    my $bu = shift;
    my $osgish = $self->osgish;

    my $name = $bu->{Headers}->{'[Bundle-Name]'}->{Value};
    my ($c_id,$c_active,$c_inactive,$c_reset) = $osgish->color("bundle_info_id","bundle_active","bundle_inactive",RESET);    
    my $sym = $bu->{SymbolicName} || $bu->{Location};
    my $color = "";
    $color = $c_inactive if lc $bu->{State} eq "installed";
    $color = $c_active if lc $bu->{State} eq "active";
    $sym = $color . $sym . $c_reset;
    $$ret .= sprintf("Name:          %s %s\n",$c_id.$bu->{Identifier}.$c_reset,$name ? $name : $sym) if $name;
    $$ret .= sprintf("               %s\n",$sym) if $name;
    $$ret .= sprintf("Location:      %s (%s)\n",$bu->{Location},$self->format_date($bu->{LastModified}/1000));
}

sub _dump_imports {
    my $self = shift;
    my $ret = shift;
    my $imports = shift;
    my $opts = shift;
    my $osgish = $self->osgish;

    my $label = "Imports:";
    my ($c_pr,$c_pv,$c_po,$c_ps,$c_re) = $osgish->color("package_resolved","package_version","package_optional","package_source",RESET);
    for my $k (sort { $a cmp $b } keys %$imports) {
        my $val = $imports->{$k};
        my $version = $val->{version};
        if ($val->{version}) {
            $version = $c_pv . $version . $c_re;
            $version .= " " . $val->{version_spec} if $val->{version_spec};
        } else {
            $version = $val->{version_spec} if $val->{version_spec};
        }
        my $optional = $val->{optional} ? $c_po . " * " . $c_re : "";
        my $package = $k;
        $package = $c_pr . $package . $c_re if ($val->{resolved});
        my $src = "";
        if ($val->{source}) {
            $src = " <-- " . $c_ps . ($opts->{s} ? $val->{source}->{name} : $val->{source}->{id}) . $c_re;
        }
        $$ret .= sprintf("%-14.14s %s %s%s%s\n",$label,$package,$version,$optional,$src);
        $label = "";
    }
}

sub _dump_exports {
    my $self = shift;
    my $ret = shift;
    my $exports = shift;
    my $opts = shift;
    my $osgish = $self->osgish;

    my $label = "Exports:";
    my ($c_pv,$c_pr,$c_ps,$c_re) = $osgish->color("package_version","package_resolved","package_source",RESET);
    for my $k (sort { $a cmp $b } keys %$exports) {
        my $val = $exports->{$k};
        my $version = $val->{version};
        $version = $c_pv . $version . $c_re if ($val->{version});
        my $package = $k;
        $package = $c_pr . $package . $c_re if ($val->{source});
        my $src = "";
        if ($val->{source}) {
            $src = " <-- " . $c_ps . ($opts->{s} ? $val->{source}->{name} : $val->{source}->{id}) . $c_re;
        }
        $$ret .= sprintf("%-14.14s %s %s%s\n",$label,$package,$version,$src);
        $label = "";
    }
}

sub _dump_headers {
    my $self = shift;
    my $ret = shift;
    my $headers = shift;
    my $osgish = $self->osgish;
    my $label = "Headers:";
    #print Dumper($headers);
    my ($c_h,$c_v,$c_r) = $osgish->color("header_name","header_value",RESET);
    for my $h (sort { $headers->{$a}->{Key} cmp $headers->{$b}->{Key} } keys %$headers) {
        my $val = $headers->{$h}->{Value};
        my $key = $headers->{$h}->{Key};
        if ($key =~ /^(Export|Import)-Package$/ || ($val =~ /[,;]\s*version=/)) {
            my $prop = $val;
            my @props;
            while ($prop) {
                $prop =~ s/([^,]*?(".*?")*)(,|$)//;
                push @props,$1;
            }
            my $l = length $key;
            $key = $c_h . $key . $c_r;
            $$ret .= sprintf("%-14.14s %s = %s%s%s,\n",$label,$key,$c_v,shift @props,$c_r);
            $label = "";
            while (@props) {
                $$ret .= sprintf("%-14.14s %${l}.${l}s   %s%s%s%s\n",$label,"",$c_v,shift @props,$c_r,@props ? "," : "");
            }
        } else {
            $key = $c_h . $key . $c_r;
            $$ret .= sprintf("%-14.14s %s = %s%s%s\n",$label,$key,$c_v,$val,$c_r);
            $label = "";
        }
    }
}

sub _extract_imports {
    my $self = shift;
    my ($imp,$headers,$lookup_sources) = @_;
    my $imp_headers = {};
    for my $i (grep { $_->{Key} eq 'Import-Package' } values %{$headers}) {
        my $val = $i->{Value};
        $imp_headers = { %$imp_headers, %{$self->_split_property($val)} };
    }
    my $imports = {};
    my $sources = $self->_lookup_sources() if $lookup_sources;
    for my $i (@$imp) {
        my ($package,$version) = $self->_split_package($i);
        my $e = {};
        $e->{version} = $version;
        $e->{resolved} = 1;
        if ($imp_headers->{$package}) {
            $self->_add_imp_header_info($e,$imp_headers->{$package});
        }
        $e->{source} = $sources->{$package} if $lookup_sources;
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
}

sub _extract_exports {
    my $self = shift;
    my ($exp,$lookup_sources) = @_;
    my $exports = {};
    my $sources = $self->_lookup_sources() if $lookup_sources;
    for my $e (@$exp) {
        my ($package,$version) = $self->_split_package($e);
        my $e = {};
        $e->{version} = $version;
        $e->{source} = $sources->{$package} if $lookup_sources;
        $exports->{$package} = $e;
    }
    return $exports;
}


sub _lookup_sources {
    my $self = shift;
    my $agent = $self->agent;
    my $bundles = $agent->bundles;
    print Dumper($bundles);
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
    my ($bundles,@filters) = @_;

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

#!/usr/bin/perl

package OSGi::Osgish::Command::Bundle;
use strict;
use vars qw(@ISA);
use Term::ANSIColor qw(:constants);
use OSGi::Osgish::Command;
use Data::Dumper;

@ISA = qw(OSGi::Osgish::Command);

my %BUNDLE_STATE_COLOR = (
                          "installed" => "bundle_installed",
                          "resolved" => "bundle_resolved",
                          "active" => "bundle_active"
                         );

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
        my $agent = $osgish->agent;
        print "Not connected to a server\n" and return unless $agent;
        my ($opts,@filters) = $self->extract_command_options(["s!","i!","e!","h!"],@_);
        my $bundles = $agent->bundles;
        my $text = sprintf("%4.4s   %-11.11s  %3s %s\n","Id","State","Lev","Name");
        $text .= "-" x 87 . "\n";
        my $nr = 0;
        
        my $filtered_bundles = $self->_filter_bundles($bundles,@filters);
        return unless @$filtered_bundles;
        if (@$filtered_bundles == 1) {
            # Print single info for bundle
            $self->print_bundle_info($filtered_bundles->[0],$opts);
        } else {
            for my $b (sort { $a->{Identifier} <=> $b->{Identifier} } @$filtered_bundles) {
                my $id = $b->{Identifier};
                my ($c_frag,$reset) = $osgish->color("bundle_fragment",RESET);
                my $state = lc $b->{State};
                my $color = $self->_bundle_state_color($b);
                my $state = $self->_state_info($b);
                my $level = $b->{StartLevel};
                my $fragment = $b->{Fragment} eq "true" ?  $c_frag . "F" . $reset : " ";
                my $name = $b->{Headers}->{'[Bundle-Name]'}->{Value};
                my $sym_name = $b->{SymbolicName};
                my $version = $b->{Version};
                my $location = $b->{Location};
                my $desc = $opts->{s} ? 
                  $sym_name || $location :
                    $name || $sym_name || $location;
                $desc .= " ($version)" if $version && $version ne "0.0.0";
                
                $text .= sprintf "%s%4d   %-11s%s %s%3d %s%s%s\n",$color,$id,$state,$reset,$fragment,$level,$desc; 
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
        my $filtered_bundles = [map { $_->{SymbolicName} } @{$self->_filter_bundles($agent->bundles,@filters)} ];
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
    my $agent = $self->agent;

    my $bu = shift;
    my $opts = shift;
    my $txt = "";

    $self->_dump_main_info(\$txt,$bu,$opts);
    $txt .= "\n";

    my $imports = $self->_extract_imports($bu->{ImportedPackages},$bu->{Headers},$opts->{i});
    $self->_dump_imports(\$txt,$imports,$opts);

    my $exports = $self->_extract_exports($bu->{ExportedPackages},$opts->{e});
    $self->_dump_exports(\$txt,$exports,$opts);

    $self->_dump_services(\$txt,$bu,$opts);
    $self->_dump_required(\$txt,$bu,$opts);
    $self->_dump_headers(\$txt,$bu->{Headers}) if ($opts->{h});

    $self->print_paged($txt);

    #print Dumper($bu);
}

sub _extract_services {
    my $self = shift;
    my $ids = shift;
    my $agent = $self->agent;
    my $ret = {};
    for my $id (@$ids) {
        my $service = $agent->service($id);
        $ret->{$id} = { 
                       id => $id,
                       class => $service->{classes}->[0],
                       bundle => $service->{bundle},
                       using => $service->{using}
                      };
    }
    return $ret;
}

sub _dump_services {
    my $self = shift;
    my $ret = shift;
    my $bu = shift;
    my $opts = shift;
    my $osgish = $self->osgish;
    my $agent = $self->agent;

    my $s = "";
    my $services = $agent->services; # Update if necessary
    my $services = $self->_extract_services($bu->{RegisteredServices});
    my ($c_bundle,$c_using,$c_registered,$c_reset) = $osgish->color("bundle_id","service_using","service_registered",RESET);
    my $label = " Registered:";
    for my $id (keys %{$services}) {
        #print Dumper($services->{$id});
        my @bundles = @{$services->{$id}->{using}};
        my $class = $services->{$id}->{class};
        $s .= $self->_dump_bundle_using($class,$services->{$id}->{using},
                                          {label => $label, use_sym => $opts->{s},color => $c_using,
                                           prefix => sprintf("%3.3s: ",$id)});
        $label = "";
    }
    $services = $self->_extract_services($bu->{ServicesInUse});
    $label = " Using:";
    for my $id (keys %{$services}) {
        my $bundle = $services->{$id}->{bundle};
        $bundle = $agent->bundle_name($bundle,use_cached => 1) if $opts->{s};
        $s .= sprintf("%-14.14s %3.3s: %s <- %s\n",$label,$id,$c_using . $services->{$id}->{class} . $c_reset,$c_bundle . $bundle . $c_reset);
        $label = "";
    }

    $$ret .= "\nServices:\n" . $s if length $s;
}

sub _dump_required {
    my $self = shift;
    my $ret = shift;
    my $bu = shift;
    my $opts = shift;
    my $osgish = $self->osgish;
    my $agent = $self->agent;
    
    my $s = "";
    my ($c_id,$c_reset) = 
      $osgish->color("bundle_id",RESET);
    for my $e ([ "RequiredBundles","Required" ],[ "RequiringBundles", "Required by" ]) {
        my $bundles = $bu->{$e->[0]};
        if (@$bundles) {
            my $label = $e->[1];
            for my $id (@$bundles) {
                my $id_c = $c_id . $id . $c_reset;
                my $bundle = $opts->{s} ? $agent->bundle_name($id,use_cached => 1) . " " . $id_c : $id_c;
                $s .= sprintf("%-14.14s %s\n",$label,$bundle);
            }
        }
    }
    $$ret .= "\n" .  $s  if length($s);
}

sub _dump_bundle_using {
    my $self = shift;
    my $main = shift;
    my $bundles = shift;
    my $args = shift;
    my $agent = $self->agent;
    my ($c_bundle,$c_reset) = $self->osgish->color("bundle_id",RESET);
    my $ret = "";
    my $prefix = $args->{prefix} || "";
    my $len = $args->{length} || length($main . $prefix);
    my $main_c = $args->{color} ? $args->{color} . $main . $c_reset : $main;
    if ($args->{use_sym}) {
        if (@$bundles) {
            my @names = map { $agent->bundle_name($_,use_cached => 1) } @$bundles;
            $ret .= sprintf("%-14.14s %s -> %s\n",$args->{label},$prefix . $main_c,
                            $c_bundle . shift(@names) . $c_reset);
            my $indent = " " x (19 + $len);
            while (@names) {
                $ret .= $indent . $c_bundle . (shift @names) . $c_reset . "\n";
            }               
        } else {
            $ret .= sprintf("%-14.14s %s\n",$args->{label},$prefix . $main);
        }
    } else {
        #my @bundles = map { $c_ps . $_->{id} . $c_re } @{$val->{using}};
        my $src = "";
        my $c = $main;
        if (@$bundles) {
            my $txt = join ", ", map { $c_bundle . $_ . $c_reset } @$bundles;
            $src = " -> " . $txt;
        }
        $ret .= sprintf("%-14.14s %s%s\n",$args->{label},$prefix . $main_c,$src);
    }
    return $ret;
}
    
sub _dump_main_info {
    my $self = shift;
    my $ret = shift;
    my $bu = shift;
    my $opts = shift;
    my $osgish = $self->osgish;
    my $agent = $self->agent;

    my $name = $bu->{Headers}->{'[Bundle-Name]'}->{Value};
    my ($c_id,$c_version,$c_fragment,$c_reset) = $osgish->color("bundle_id","bundle_version","bundle_fragment",RESET);    
    my $sym = $bu->{SymbolicName} || $bu->{Location};
    my $version = $bu->{Version} ? $c_version . $bu->{Version} . $c_reset : "";
    my $fragment = $bu->{Fragment} eq "true" ? "(" . $c_fragment . "Fragment" . $c_reset . ")" : "";
    my $rest = join(" ",$version,$fragment);
    my $state_color = $self->_bundle_state_color($bu);
    my $state = "[" . $state_color . $self->_state_info($bu) . $c_reset . "]";
    $sym = $c_id . $sym . $c_reset;
    $$ret .= sprintf("%-14.14s %s %s\n","Name:",$c_id.$bu->{Identifier}.$c_reset,$name ? $name : $sym) if $name;
    $$ret .= sprintf("%-14.14s %s %s %s\n","",$name ? $sym : "",$state,$rest);
    $$ret .= sprintf("%-14.14s %s\n","Location:",$bu->{Location});
    $$ret .= sprintf("%-14.14s %s\n","Modified:",$self->format_date($bu->{LastModified}/1000));
    $self->_add_fragment($ret,$bu->{Hosts},"Hosts:");
    $self->_add_fragment($ret,$bu->{Fragments},"Fragments:");

    my @flags = ();
    for my $flag ("RemovalPending", "PersistentlyStarted", "Required") {
        push @flags,$flag if $bu->{$flag} eq "true";
    } 
    if (@flags) {
        $$ret .= sprintf("%-14.14s %s\n","Flags:",join ", ",@flags);
    }
    if (length($bu->{StartLevel})) {
        $$ret .= sprintf("%-14.14s %s\n","Start-Level:",$bu->{StartLevel});
    }
    #print Dumper($bu);
}

sub _add_fragment {
    my $self = shift;
    my $ret = shift;
    my $list = shift;
    my $label = shift;
    my $osgish = $self->osgish;
    my $agent = $self->agent;
    my ($c_id,$c_fragment,$c_reset) = $osgish->color("bundle_id","bundle_fragment",RESET);    
    
    if ($list && @{$list}) {
        for my $f (@$list) {
            my $name = $c_fragment . $agent->bundle_name($f,use_cached => 1) . $c_reset . " (${c_id}${f}${c_reset})";
            $$ret .= sprintf("%-14.14s %s\n",$label,$name);
            $label = "";
        }
    }
}

sub _header {
    my $self = shift;
    my $bu = shift;
    my $key = shift;
    my $headers = $bu->{Headers};
    my @prop  = grep { $_->{Key} eq $key } values %$headers;
    return "" unless @prop;
    return (shift @prop)->{Value};
}

sub _dump_imports {
    my $self = shift;
    my $ret = shift;
    my $imports = shift;
    my $opts = shift;
    my $osgish = $self->osgish;

    my $label = "Imports:";
    my ($c_pr,$c_pv,$c_po,$c_ps,$c_re) = $osgish->color("package_resolved","package_version","package_optional","package_imported_from",RESET);
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
            my $b = $val->{source};
            $src = " <- " . $c_ps . ($opts->{s} ? $b->{name} : $b->{id}) . $c_re;
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
    my ($c_pv,$c_pr,$c_ps,$c_re) = $osgish->color("package_version","package_resolved","package_exported_to",RESET);
    for my $k (sort { $a cmp $b } keys %$exports) {
        my $val = $exports->{$k};
        my $version = $val->{version};
        $version = $c_pv . $version . $c_re if ($val->{version});
        my $len = length($k . " " . $val->{version});
        my $package = $k;
        $package = $c_pr . $package . $c_re if ($val->{using} && @{$val->{using}});
        if ($val->{using}) {
            $$ret .= $self->_dump_bundle_using($package . " " . $version,[map { $_->{id} } @{$val->{using}} ],
                                                 {length => $len,label => $label, use_sym => $opts->{s}});
            $label = "";
        } else {
            $$ret .= sprintf("%-14.14s %s %s\n",$label,$package,$version);
        }
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
    my $agent = $self->agent;
    my ($imp,$headers,$lookup_sources) = @_;
    my $imp_headers = {};
    for my $i (grep { $_->{Key} eq 'Import-Package' } values %{$headers}) {
        my $val = $i->{Value};
        $imp_headers = { %$imp_headers, %{$self->_split_property($val)} };
    }
    my $imports = {};
    my $first = 1;
    for my $i (@$imp) {
        my ($package,$version) = $self->_split_package($i);
        my $e = {};
        $e->{version} = $version;
        $e->{resolved} = 1;
        if ($imp_headers->{$package}) {
            $self->_add_imp_header_info($e,$imp_headers->{$package});
        }
        if ($lookup_sources) {
            $e->{source} = $agent->exporting_bundle($package,$version,use_cached => !$first);
            $first = 0;
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
}

sub _extract_exports {
    my $self = shift;
    my $agent = $self->agent;
    my ($exp,$lookup_sources) = @_;
    my $exports = {};
    my $first = 1;
    for my $e (@$exp) {
        my ($package,$version) = $self->_split_package($e);
        my $e = {};
        $e->{version} = $version;
        if ($lookup_sources) {
            $e->{using} = $agent->importing_bundles($package,$version,use_cached => !$first);
            $first = 0;
        }
        $exports->{$package} = $e;
    }
    return $exports;
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

sub _bundle_state_color {
    my $self = shift;
    my $bu = shift;
    my $osgish = $self->osgish;
    my $c_name = $BUNDLE_STATE_COLOR{lc($bu->{State})};
    return "" unless $c_name;
    return ($osgish->color($c_name))[0];
}

sub _state_info {
    my $self = shift;
    my $bu = shift;
    my $state = lc $bu->{State};
    return uc(substr($state,0,1)) . substr($state,1);
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
        $l =~ s/([^,]*?("[^"]+"[^,]*)*)(\s*,\s*|$)//;
        my $part = $1;
        my @targets = ();
        my $attrs = {};
        my $directives = {};
        while ($part) {
            $part =~ s/([^;]*?("[^"]+"[^,]*)*)(\s*;\s*|$)//;
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
sub _filter_bundles {
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

#!/usr/bin/perl

=head1 NAME 

OSGi::Osgish - Access to the OSGi agent bundle

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

package OSGi::Osgish;

use strict;
use vars qw($VERSION);
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Request;
use Data::Dumper;

$VERSION = "0.1.0_1";

my $MBEANS_MAP = 
    { 
     "framework" => { key => "type", version => "1.5", domain => "osgi.core" },
     "bundleState" => { key => "type", version => "1.5", domain => "osgi.core" },
     "serviceState" => { key => "type", version => "1.5", domain => "osgi.core" },
     "packageState" => { key => "type", version => "1.5", domain => "osgi.core" },
     "permissionadmin" => { key => "service", version => "1.2", domain => "osgi.core" },
     "cm" => { key => "service", version => "1.3", domain => "osgi.compendium" },
     "provisioning" => { key => "service", version => "1.2", domain => "osgi.compendium" },
     "useradmin" => { key => "service", version => "1.1", domain => "osgi.compendium" }
    };

my $OSGISH_SERVICE_NAME = "osgish:type=Service";

sub new { 
    my $class = shift;
    my $cfg = ref($_[0]) eq "HASH" ? $_[0] : {  @_ };
    
    my $jmx4perl = new JMX::Jmx4Perl($cfg);
    my $self = { 
                j4p => $jmx4perl
               };
    bless $self,(ref($class) || $class);
    return $self;
}

sub url { 
    my $self = shift;
    my $j4p = $self->{j4p};
    return $j4p->url;
}

sub init {
    my $self = shift;
    my $old_bundle = delete $self->{bundle};
    my $old_service = delete $self->{service};
    eval {
        $self->{bundle} = $self->_fetch_list("bundleState","listBundles");
        $self->{service} = $self->_fetch_list("serviceState","listServices");
    };
    if ($@) {
        $self->{bundle} = $old_bundle;
        $self->{service} = $old_service;
        die $@;
    }
}

sub bundles {
    my $self = shift;
    $self->_update_bundles(@_);
    return $self->{bundle}->{list};
}

sub services { 
    my $self = shift;
    $self->_update_services(@_);
    return $self->{service}->{list};
}

sub symbolic_names { 
    my $self = shift;
    $self->_update_bundles(@_);
    return $self->{bundle}->{symbolic_names};
}

sub ids {
    my $self = shift;
    $self->_update_bundles(@_);
    return $self->{bundle}->{ids};
}

sub start_bundle {
    shift->_start_stop_bundle("start",@_);
}

sub stop_bundle {
    shift->_start_stop_bundle("stop",@_);
}

sub shutdown {
    my $self = shift;
    $self->_execute($self->_mbean_name("framework"),"shutdownFramework");
}


sub _execute {
    my $self = shift;
    my $mbean = shift || die "No MBean name given";
    my $operation = shift || die "No operation given for MBean $mbean";
    my @args = @_;

    my $j4p = $self->{j4p};

    my $request = new JMX::Jmx4Perl::Request(EXEC,$mbean,$operation,@args);
    my $response = $j4p->request($request);
    if ($response->is_error) {
        #print Dumper($response);
        die "No osgish-agent running [Not found: $mbean,$operation].\n"
          if $response->status == 404;
        if ($response->status >= 500) {
            $self->{last_error} = $response->{error} . 
              ($response->stacktrace ? "\nStacktrace:\n" . $response->stacktrace : "");
            die "Connection refused\n" if $response->{error} =~ /Connection\s+refused/i;
            die "Internal Server Error: " . $response->{error} . "\n";
        }
    }
    return $response->value;
}

sub last_error {
    my $self = shift;
    return $self->{last_error};
}

sub _start_stop_bundle {
    my $self = shift;
    my $cmd = shift;
    my $what = shift;

    my $id = $what =~ /^\d+$/ ? $what : $self->symbolic_names->{$what};
    unless ($id) {
        die "Cannot $cmd bundle '$what': Not an id nor a symbolic name\n";
    }
    $self->_execute($self->_mbean_name("framework"),"${cmd}Bundle",$id);
}

sub _mbean_name {
    my $self = shift;
    my $short_name = shift;
    
    my $d = $MBEANS_MAP->{$short_name} || die "No MBean defined for shortname $short_name";
    return $d->{domain} . ":" . $d->{key} . "=$short_name,version=" . $d->{version};
}

sub _update_services {
    my $self = shift;
    my $args = shift;
    $args = { $args, @_ } unless ref($args) eq "HASH";

    return if ($self->{service} && $args->{use_cached});

    # TODO: Update policy

    # Cache bundle list
    if ($self->_server_state_changed("services")) {
        my $service = $self->_fetch_list("serviceState","listServices");
        $self->{service} = $service;
    }    
}

sub _update_bundles {
    my $self = shift;
    my $args = shift;
    $args = { $args, @_ } unless ref($args) eq "HASH";

    return if ($self->{bundle} && $args->{use_cached});

    # TODO: Update policy

    # Cache bundle list
    if ($self->_server_state_changed("bundles")) {
        my $bundle = $self->_fetch_list("bundleState","listBundles");
        $bundle->{symbolic_names} = $self->_extract_symbolic_names($bundle->{list});
        $self->{bundle} = $bundle;
    }
}

sub _fetch_list {
    my $self = shift;
    my ($mbean,$operation) = @_;
    my $ret = {};
    $ret->{list} = $self->_execute($self->_mbean_name($mbean),$operation);
    $ret->{timestamp} = time;
    $ret->{ids} = [ map { $_->{Identifier} } values %{$ret->{list}} ];
    return $ret;
}

sub _server_state_changed {
    my $self = shift;
    my $type = shift;
    my $state = $self->_execute($OSGISH_SERVICE_NAME,"hasStateChanged",$type,$self->{bundle}->{timestamp});
    return $state eq "true" ? 1 : 0;
}

sub _extract_symbolic_names {
    my $self = shift;
    my $bundles = shift;
    my $ret = {};
    for my $e (keys %$bundles) {
        my $sym = $bundles->{$e}->{SymbolicName};
        next unless $sym;
        my $id = $bundles->{$e}->{Identifier};
        $ret->{$sym} = $id;
    }
    return $ret;
}

1;

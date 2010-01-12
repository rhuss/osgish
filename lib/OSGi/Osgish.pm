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

$VERSION = "0.1_1";

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

sub list_bundles {
    my $self = shift;
    my $j4p = $self->{j4p};
    return $j4p->execute($self->_mbean_name("bundleState"),"listBundles");
}

sub _mbean_name {
    my $self = shift;
    my $short_name = shift;
    
    my $d = $MBEANS_MAP->{$short_name} || die "No MBean defined for shortname $short_name";
    return $d->{domain} . ":" . $d->{key} . "=$short_name,version=" . $d->{version};
}

1;

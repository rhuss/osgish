package OSGi::Osgish::ServerHandler;

use strict;
use Term::ANSIColor qw(:constants);
use OSGi::Osgish;
use Data::Dumper;

sub new { 
    my $class = shift;
    my $context = shift || die "No context given";
    my $self = {
                context => $context
               };
    bless $self,(ref($class) || $class);
    my $server = $self->_init_server_list($context->{config},$context->{args});
    $self->connect_to_server($server) if $server;
    return $self;
}

sub connect_to_server {
    my $self = shift;    
    my $server = shift;
    my $name = shift;

    my $server_map = $self->{server_map};
    my $s = $server_map->{$server};
    unless ($s) {
        unless ($server =~ m|^\w+://[\w:]+/|) {
            print "Invalid URL $server\n";
            return;
        }
        $name ||= $self->prepare_server_name($server);
        my $entry = { name => $name, url => $server };
        push @{$self->{server_list}},$entry;
        $self->{server_map}->{$name} = $entry;
        $s = $entry;
    }
    my $ctx = $self->{context};
    my ($old_server,$old_osgi) = ($self->server,$ctx->osgish);
    eval { 
        my $osgi = $self->_create_osgi($server) || die "Unknown $server (not an alias nor a proper URL).\n";;
        $osgi->init();
        $ctx->osgish($osgi);
        $self->{server} = $server;
        $ctx->{last_error} = undef;
    };
    if ($@) {
        if ($ctx->osgish && $ctx->osgish->last_error) {
            $ctx->{last_error} = $ctx->osgish->last_error;
        } else {
            $ctx->{last_error} = $@;
        }
        $self->{server} = $old_server;
        $ctx->osgish($old_osgi);
        die $@;
    }   
}

sub server {
    return shift->{server};
}

sub _init_server_list {
    my $self = shift;
    my $config = shift;
    my $args = shift;
    my @servers = map { { name => $_->{name}, url => $_->{url}, from_config => 1 } } @{$config->get_servers};
    my $ret_server;
    if ($args->{server}) {
        my $config_s = $config->get_server_config($args->{server});
        if ($config_s) {
            my $found = 0;
            my $i = 0;
            my $entry = { name => $config_s->{name}, url => $config_s->{url}, from_config => 1 } ;
            for my $s (@servers) {
                if ($s->{name} eq $args->{server}) {
                    $servers[$i] = $entry;
                    $found = 1;                 
                    last;
                }
                $i++;
            } 
            push @servers,$entry unless $found;
            $ret_server = $config_s->{name};
        } else {
            die "Invalid URL ",$args->{server} unless ($args->{server} =~ m|^\w+://|);
            my $name = $self->_prepare_server_name($args->{server});
            push @servers,{ name => $name, url => $args->{server} };
            $ret_server = $name;
        }
    }
    $self->{server_list} = \@servers;
    $self->{server_map} = { map { $_->{name} => $_ } @servers };
    return $ret_server;
}

sub list {
    my $self = shift;
    return $self->{server_list};
}

sub _prepare_server_name {
    my $self = shift;
    my $url = shift;
    if ($url =~ m|^\w+://([^/]+)/?|) { 
        return $1;
    } else {
        return $url;
    }
}

sub _create_osgi {
    my $self = shift;
    my $server = shift;
    return undef unless $server;
    # TODO: j4p_args, jmx_config;
    my $ctx = $self->{context};
    my $j4p_args = $self->_j4p_args($ctx->{args} || {});
    my $jmx_config = $ctx->{config} || {};
    my $sc = $self->{server_map}->{$server};
    return undef unless $sc;
    if ($sc->{from_config}) {
        return new OSGi::Osgish({ %$j4p_args, server => $server, config => $jmx_config});
    } else {
        return new OSGi::Osgish({ %$j4p_args, url => $sc->{url}});
    }
}

sub _j4p_args {
    my $self = shift;
    my $o = shift;
    my $ret = { };
    
    for my $arg qw(user password) {
        if (defined($o->{$arg})) {
            $ret->{$arg} = $o->{$arg};
        }
    }
    
    if (defined($o->{proxy})) {
        my $proxy = {};
        $proxy->{url} = $o->{proxy};
        for my $k (qw(proxy-user proxy-password)) {
            $proxy->{$k} = defined($o->{$k}) if $o->{$k};
        }
        $ret->{proxy} = $proxy;
    }        
    if (defined($o->{target})) {
        $ret->{target} = {
                          url => $o->{target},
                          $o->{'target-user'} ? (user => $o->{'target-user'}) : (),
                          $o->{'target-password'} ? (password => $o->{'target-password'}) : (),
                         };
    }
    return $ret;
}

1;

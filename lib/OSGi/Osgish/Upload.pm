#!/usr/bin/perl

=head1 NAME 

OSGi::Osgish::Upload - Upload a bundle to the osgish upload directory

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

package OSGi::Osgish;

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request::Common;
use JMX::Jmx4Perl::Agent::UserAgent;
use vars qw($HAS_PROGRESS_BAR);

BEGIN {
    eval {
        require "Term/ProgressBar.pm";
        $HAS_PROGRESS_BAR = 1;
    };
}

sub new { 
    my $class = shift;
    my $cfg = ref($_[0]) eq "HASH" ? $_[0] : {  @_ };
    die "No upload URL provided" unless $cfg->{url};
    my $ua = new JMX::Jmx4Perl::Agent::UserAgent();
    $ua->jjagent_config($cfg);
    my $self = { 
                cfg => $cfg,
                ua => $ua
               };
    bless $self,(ref($class) || $class);
    return $self;
}

sub upload { 
    my $self = shift;
    my $file = shift;
    my $cfg = {};
    if (@_) {
        $cfg = ref($_[0]) eq "HASH" ? $_[0] : { @_ };
    }
    die "No file $file\n" unless -f $file;
    my $ua = $self->{ua};
    
    {
        local $HTTP::Request::Common::DYNAMIC_FILE_UPLOAD = 1;
        
        my $req = 
          POST 
            $self->{cfg}->{url}, 
              'Content_Type' => 'form-data', 
                'Content' => { "upload" => [ $file ] };
        my $reader = $self->_content_reader($req->content(),$cfg,$req->header('Content_Length'));
        $req->content($reader);
        my $resp = $ua->request($req);
        die "Error while uploading $file: ",$resp->message if $resp->is_error;
    }
}

sub _content_reader {
    my $self = shift;
    my $gen = shift;
    my $cfg = shift;
    my $len = shift;
    if ($HAS_PROGRESS_BAR && $cfg->{progress_bar}) {
        my $progress = new Term::ProgressBar({name => "Upload",count => $len,remove => 1,term_width => 65});
        $progress->minor(0);
        my $size = 0;
        my $next_update = 0;
        sub {
            my $chunk = &$gen();
            $size += length($chunk) if $chunk;
            $next_update = $progress->update($size)
              if $size >= $next_update;
            return $chunk;
        }
    } else {
        return sub {
            return &$gen();
        }
    }
}

#my $u = new OSGi::Osgish(url => "http://localhost:8080/j4p-upload");
#$u->upload("n",progress_bar => 1);
1; 

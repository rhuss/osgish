#!/usr/bin/perl

package OSGi::Osgish::Command::Upload;
use strict;
use vars qw(@ISA);
use Term::ANSIColor qw(:constants);
use File::Glob ':glob';
use Data::Dumper;

@ISA = qw(OSGi::Osgish::Command);

sub name { "upload" }

sub top_commands {
    my $self = shift;
    return $self->agent ? $self->commands : {};
}

sub commands {
    my $self = shift;
    my $cmds = $self->sub_commands;
    return 
        {
         "upload" => { 
                      desc => "Upload related operations",
                      proc => $self->push_on_stack("upload",$cmds),
                      cmds => $cmds                       
                     },
         "u" => { alias => "upload", exclude_from_completion => 1},
        };
}

sub sub_commands {
    my $self = shift;
    return { 
            "ls" => { 
                     desc => "List upload directory",
                     proc => $self->cmd_list,
                    },
            "put" => {
                      desc => "Upload a bundle",
                      proc => $self->cmd_put,
                      args => $self->complete->files_extended
                     },
            "rm" => {
                     desc => "Remove a bundle",
                     proc => $self->cmd_delete,
                     args => sub { $self->agent->upload->complete_files_in_upload_dir(@_) }
                    },
            "install" => {
                          desc => "Install a bundle",
                          proc => $self->cmd_install,
                          args => sub { $self->agent->upload->complete_files_in_upload_dir(@_) }
                         },
            "update" => {
                     desc => "Update a bundle",
                     proc => $self->cmd_update,
                     args => sub { $self->agent->upload->complete_files_in_upload_dir(@_) }
                    },
           };
}

sub cmd_install {
    my $self = shift;

    return sub {
        my $file = shift || die "No file given"; 
        my $osgish = $self->osgish;
        my $agent = $osgish->agent;
        print "Not connected to a server\n" and return unless $agent;
        my $list = $agent->upload->list;
        my $uf = $list->{$file} || die "No file $file uploaded\n";
        my $ret = $agent->install_bundle("file://" . $uf->{canonicalPath});
        my ($color,$reset) = $osgish->color("bundle_id",RESET);
        if (!ref($ret)) {
            print "Installed bundle " . $color . $ret . $reset . ".\n";
        }
    }
}

sub cmd_update {
    my $self = shift;

    return sub {
        my $file = shift || die "No file given"; 
        my $osgish = $self->osgish;
        my $agent = $osgish->agent;
        print "Not connected to a server\n" and return unless $agent;
        my ($color,$reset) = $osgish->color("bundle_id",RESET);
        if ($file =~ /^\d+$/) {
            $agent->update_bundle($file);
            print "Updated bundle " . ($color . $file . $reset) . ".\n";
        } else {
            my $list = $agent->upload->list;
            my $installed = $self->uploaded_installed_bundles($list);
            my $b_id = $installed->{$file} || die "No bundle $file installed.\n";
            $agent->update_bundle($b_id);
            print "Updated bundle $file (" . ($color . $b_id . $reset) . ").\n";
        }
    }
}

# =========================================================================================
sub cmd_list {
    my $self = shift;
    return sub {
        my $osgish = $self->osgish;
        my $osgi = $osgish->agent;
        print "Not connected to a server\n" and return unless $osgi;
        my $list = $osgi->upload->list;
        #print Dumper($list);
        my $installed = $self->uploaded_installed_bundles($list);
        for my $file (sort keys %$list) {
            my $time = $list->{$file}->{modified} / 1000;
            my $date = $self->format_date($time);
            if ($installed->{$file}) {
                my ($bundle_id,$color_start,$color_end) = 
                  ($installed->{$file},$osgish->color("upload_installed",RESET));
                printf "%s%3.3s %10.10s %12.12s %s%s\n",$color_start,$bundle_id,$list->{$file}->{length},$date,$file,$color_end;
            } else {
                my ($color_start,$color_end) = 
                  ($osgish->color("upload_uninstalled",RESET));
                printf "    %10.10s %12.12s %s%s%s\n",$list->{$file}->{length},$date,$color_start,$file,$color_end;
            }
        }
    }
}

sub cmd_put {
    my $self = shift;
    return sub {
        my $file = shift || die "No file given";
        my $osgi = $self->agent;
        my @files = bsd_glob($file, GLOB_TILDE | GLOB_ERR);
        for my $f (@files) {
            if (-f $f && -s $f) {
                $osgi->upload->upload($f,progress_bar => 1);
                print "Uploaded $f\n";
            } 
        }
        $osgi->upload->cache_update;
    }
}

sub cmd_delete {
    my $self = shift;
    return sub {
        my $osgish = $self->osgish;
        my $osgi = $osgish->agent;
        my $file = shift || die "No file given"; 
        die "Filepath must not be absolute" if $file =~ /^\//;
        my @files;
        my $list = $osgi->upload->list;
        my $installed = $self->uploaded_installed_bundles($list);
        if ($file =~ /\*/) {
            # It's a glob, we need to expand it and do multiple removes
            my $pattern = $file;
            $pattern =~ s/\./\\./g;
            $pattern =~ s/\*/.*/g;
            $pattern =~ s/\?/./g;
            @files = grep { /^$pattern$/ } sort keys %$list;
        } else {
            @files = ( $file );
        }
        for my $f (@files) {
            if ($installed->{$f}) {
                print "$f is still installed as bundle. Uninstall it first\n";
                next;
            }
            my $error = $osgi->upload->remove($f);
            print $error ? "rm: $error\n" : "Removed $f.\n";
        }
        $osgi->upload->cache_update;
    }
}

sub uploaded_installed_bundles {
    my $self = shift;
    my $list = shift;
    my $osgi = $self->agent;
    my $bundles = $osgi->bundles();
    my %locations = map { "file://" . $list->{$_}->{canonicalPath} => $_} keys %$list;
    #print Dumper(\%locations);
    my %installed;
    for my $b (values %$bundles) {
        my $file = $locations{$b->{Location}};
        $installed{$file} = $b->{Identifier} if $file;
    }
    return \%installed;
}

1;

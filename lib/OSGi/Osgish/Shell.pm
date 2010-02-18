package OSGi::Osgish::Shell;

use strict;
use Term::ShellUI;
use Term::ANSIColor qw(:constants);

sub new { 
    my $class = shift;
    my $self = ref($_[0]) eq "HASH" ? $_[0] : {  @_ };
    bless $self,(ref($class) || $class);
    $self->_init;
    return $self;
}

sub term {
    return shift->{term};
}

sub commands {
    my $self = shift;
    $self->{term}->commands(@_);
}

# Run ShellUI and never return. Provide some special
# ReadLine treatment
sub run {
    my $self = shift;
    my $t = $self->term;
    
    #$t->{debug_complete}=5;
    $t->run;
}

sub color { 
    my $self = shift;
    my @colors = @_;
    my $args = ref($colors[$#colors]) eq "HASH" ? pop @colors : {};
    if ($self->use_color) {
        if ($args->{escape}) {
            return map { "\01" . $self->_resolve_color($_) . "\02" } @colors;
        } else {
            return map { $self->_resolve_color($_) } @colors;
        }
    } else {
        return map { "" } @colors;
    }
}


sub color_theme {
    return shift->_get_set("color_theme",@_);
}

sub use_color {
    my $self = shift;
    my $value = shift;
    if ($value) {
        my $use_color = $value;
        $use_color = 0 if $use_color =~ /^(no|never|false)$/i;
        $self->{use_color} = $use_color;
    }
    return $self->{use_color};
}

sub _resolve_color {
    my $self = shift;
    my $c = shift;
    my $color = $self->{color_theme}->{$c};
    if (exists($self->{color_theme}->{$c})) {
        return defined($color) ? $color : "";
    } else {
        return $c;
    }
}

# ===========================================================================

sub _init {
    my $self = shift;

    # Create shell object
    my $term = new Term::ShellUI(
                                 history_file => "~/.agent_history",
                                );
    $self->{term} = $term;
    $term->{term}->ornaments(0);
    # Initial theme
    my $theme_light = { 
                       host => YELLOW,
                       bundle_active =>  GREEN . ON_WHITE,
                       bundle_installed => RED,
                       bundle_resolved => DARK . YELLOW,
                       bundle_fragment => CYAN,
                       service_id => DARK . GREEN,
                       service_interface => undef,
                       service_using => RED,
                       prompt_context => BLUE,
                       prompt_empty => RED,
                       upload_installed => DARK . GREEN,
                       upload_uninstalled => RED,
                       package_resolved => DARK . GREEN,
                       package_optional => DARK . YELLOW,
                       package_version => BLUE,
                       package_imported_from => RED,
                       package_exported_to => RED,
                       bundle_id => RED,
                       header_name => DARK . YELLOW,
                       header_value => ""
                      };
    my $theme_dark = { 
                      host => YELLOW,
                      bundle_id => RED,
                      bundle_active => GREEN,
                      bundle_installed => RED,
                      bundle_resolved => YELLOW,
                      bundle_fragment => CYAN,
                      bundle_referenced => YELLOW,
                      bundle_version => CYAN,
                      service_id => GREEN,
                      service_interface => undef,
                      service_using => YELLOW,
                      service_registered => YELLOW,
                      prompt_context => CYAN,
                      prompt_empty => RED,
                      upload_installed => GREEN,
                      upload_uninstalled => RED,
                      package_resolved => GREEN,
                      package_optional => YELLOW,
                      package_version => CYAN,
                      package_imported_from => RED,
                      package_exported_to => RED,
                      header_name => YELLOW,
                      header_value => ""
                     };
    
    $self->{color_theme} = $theme_dark;

    # Force pipe, quit if less than a screen-full.
    my @args = (
                '-f',  # force, needed for color output
#                '-E',  # Exit automatically at end of output
                '-X'   # no init
               );
    if ($self->use_color) {
        # Raw characters
        push @args,'-r';
    }
    if ($ENV{LESS}) {
        my $l = "";
        for my $a (@args) {
            $l .= $a . " " unless $ENV{LESS} =~ /$a/;
        }
        if (length($l)) {
            chop $l;
            $ENV{LESS} .= " " . $l;
        }
    } else {
        $ENV{LESS} = join " ",@args;
    }
}


1;

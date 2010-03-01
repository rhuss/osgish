=head1 LICENSE

This file is part of osgish.

Osgish is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

osgish is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with osgish.  If not, see <http://www.gnu.org/licenses/>.

A commercial license is available as well. Please contact roland@cpan.org for
further details.

=head1 PROFESSIONAL SERVICES

Just in case you need professional support for this module (or JMX or OSGi in
general), you might want to have a look at www.consol.com Contact
roland.huss@consol.de for further information (or use the contact form at
http://www.consol.com/contact/)

=head1 AUTHOR

roland@cpan.org

=cut



#!/usr/bin/perl

package OSGi::Osgish::Command;
use strict;
use POSIX qw(strftime);
use Term::Clui;

use Getopt::Long qw(GetOptionsFromArray);

=head1 NAME 

OSGi::Osgish::Command - Base object for commands

=head1 DESCRIPTION

This is the base command from which all osgish commands should be extended.  It
provides registration hooks so that the command handler can determine the
position of this command in the menu structure. Additionally it provides common
methods useful for each command to perform its action.

A L<OSGi::Osgish::Command> is a collection of shell commands, grouped in a
certain context. E.g L<OSGi::Osgish::Command::Bundle> groups all bundle related
actions. It can be reused in different contexts and hence can occur at
different places in the menu structure. 

=cut

=head1 METHODS

=over

=item $command_handler = new OSGi::Osgish::Command($osgish)

Constructor, which should not called be directly on this module but on a
submodule. In fact, it will be called (indirectly) only by the
L<OSGi::Osgish::CommandHandler> during the command registration process. 
The single argument required is the central osgish object. 

=cut 

sub new { 
    my $class = shift;
    my $osgish = shift;
    my $self = ref($_[0]) eq "HASH" ? $_[0] : {  @_ };
    bless $self,(ref($class) || $class);
    $self->{osgish} = $osgish;
    return $self;
}

=item $global_commands = $cmd->global_commands

This method is called by the command handler during registration in order to
obtain the global commands which are always present in the menu. The default
implementation returns C<undef> which means that no global commands should be
registered. Overwrite this to provide a command hashref as known to
L<Term::ShellUI> for setting the global commands. 

=cut

sub global_commands { 
    return undef;
}

=item $top_commands = $cmd->top_commands

This method is called by the command handler during registration in order to
obtain the top commands which are present in the top level menu. The default
implementation returns C<undef> which means that no top commands are to be
registered. Overwrite this to provide a command hashref as known to
L<Term::ShellUI> for setting the top commands. 

=cut

sub top_commands { 
    return undef;
}

=item $osgish = $cmd->osgish

Get the osgish object used during construction. This is a convenience method
for sublassed commands.

=cut

sub osgish {
    return shift->{osgish};
}

=item $complete_handler = $cmd->complete

Convenience method to get the L<OSGi::Osgish::CompletionHandler> for getting
various command line completions.

=cut

sub complete {
    return shift->{osgish}->complete;
}

=item $agent = $cmd->agent

Convenience method to get the L<OSGi::Osgish::Agent> in order to 
contact the server agent bundle (via L<JMX::Jmx4Perl>)


=cut

sub agent {
    return shift->{osgish}->agent;
}

=item $cmd->push_on_stack("context",$cmds) 

Rerturn a sub (closure) which can be used as a command to update the context
stack managed by the command handler. Update in this sense means push the given
context ("C<context>") on the stack, remembering the provided shell commands
C<$cmds> for later use when traversing the stack upwards via C<..>

=cut 

sub push_on_stack {
    my $self = shift;
    my @args = @_;
    return sub {
        $self->{osgish}->{commands}->push_on_stack(@args);
    };
}

=item ($opts,@args) = $cmd->extract_command_options($spec,@args);

Extract any options from a command specified via C<$spec>. This method uses
L<Getopt::Long> for extrating the options. It returns a hashref with the
extracted options and an array of remaining arguments

=cut 

sub extract_command_options {
    my ($self,$spec,@args) = @_;
    my $opts = {};
    GetOptionsFromArray(\@args, $opts,@{$spec});
    return ($opts,@args);
}

=item $label = $cmd->format_date($time)

Formats a date like for C<ls -l>:

 Dec  2 18:21
 Jun 23  2009

This format is especially useful when used in listing.

=cut 

sub format_date {
    my $self = shift;
    my $time = shift;
    if (time - $time > 60*60*24*365) {
        return strftime "%b %d %Y",localtime($time);
    } else {
        return strftime "%b %d %H:%M",localtime($time);
    }
}

=item $cmd->print_paged($txt,$nr_lines)

Use a pager for printing C<$txt> which has C<$nr_lines> lines. Only if
C<$nr_lines> exceeds a certain limit (default: 24), then the pager is used,
otherwise C<$txt> is printed directly.

=cut 

sub print_paged {
    my $self = shift;
    my $text = shift;
    my $nr = shift;
    if (!$nr) {
        $nr = scalar(split /\n/s,$text);
    }
    if (defined($nr) && $nr < 24) {
        print $text;
    } else {
        view("",$text);
    }
}

=item $trimmed = $cmd->trim_string($string,$max)

Trim a string C<$string> to a certain length C<$max>, i.e. if C<$string> is
larger than C<$max>, then it is truncated to to C<$max-3> and C<...> is
appended. If it is less or equal, than C<$string> is returned unchanged. 

=cut 

sub trim_string {
    my $self = shift;
    my $string = shift;
    my $max = shift;
    return length($string) > $max ? substr($string,0,$max-3) . "..." : $string;
}

=item $converted = $cmd->convert_wildcard_pattern_to_regexp($orig)

Convert the wildcards C<*> and C<.> to their regexp equivalent and return a
regular expression.

=cut 

sub convert_wildcard_pattern_to_regexp {
    my $self = shift;
    my $wildcard = shift;
    $wildcard =~ s/\?/./g;
    $wildcard =~ s/\*/.*/g;
    return qr/^$wildcard$/;
}

=back

=cut

=head1 LICENSE

This file is part of osgish.

Osgish is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

osgish is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with osgish.  If not, see <http://www.gnu.org/licenses/>.

A commercial license is available as well. Please contact roland@cpan.org for
further details.

=head1 PROFESSIONAL SERVICES

Just in case you need professional support for this module (or JMX or OSGi in
general), you might want to have a look at www.consol.com Contact
roland.huss@consol.de for further information (or use the contact form at
http://www.consol.com/contact/)

=head1 AUTHOR

roland@cpan.org

=cut



1;


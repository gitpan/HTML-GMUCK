# $Id: Makefile.PL,v 1.2 2002/04/05 21:31:54 scop Exp $

use ExtUtils::MakeMaker;

$| = 1;

print "\n";

print "Checking for Regex::PreSuf...";
eval {
  require Regex::PreSuf;
};
if ($@) {
  print " failed\n";
  print <<EOT;
  Regex::PreSuf is _not_ required.
  But if you had it installed, most gmuck tests would run slightly faster.
EOT
  sleep(2);
} else {
  print "ok\n";
}

print "\n";

WriteMakefile(
              NAME              => 'HTML::GMUCK',
              VERSION_FROM      => 'lib/HTML/GMUCK.pm',
              PREREQ_PM         => { 'Getopt::Long' => 0,
                                     'Carp'         => 0,
                                     'HTML::Tagset' => 3.03,
                                   },
              EXE_FILES         => ['bin/gmuck'],
              MAN1PODS          => { 'docs/gmuck.pod' =>
                                     '$(INST_MAN1DIR)/gmuck.$(MAN1EXT)',
                                   },
              MAN3PODS          => { 'docs/HTML-GMUCK.pod' =>
                                     '$(INST_MAN3DIR)/HTML::GMUCK.$(MAN3EXT)',
                                   },
              ($] >= 5.005 ?
               (ABSTRACT_FROM   => 'docs/HTML-GMUCK.pod',
                AUTHOR    => 'Ville Skyttä <ville . skytta @ iki . fi>') : ()),

              dist              => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
             );

# Stuff below happily stolen from libwww-perl :)

package MY;

# Pass HTML::GMUCK version to pod2man
sub manifypods
{
  my $self = shift;
  my $ver = $self->{VERSION} || "";
  local($_) = $self->SUPER::manifypods(@_);
  s/pod2man\s*$/pod2man --release HTML-GMUCK-$ver/m;
  $_;
}

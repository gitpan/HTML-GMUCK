package HTML::GMUCK;

# $Id: GMUCK.pm,v 1.2 2002/04/05 21:31:54 scop Exp $

use strict;

require 5.00503;

use vars qw($VERSION $Tag_End $URI_Attrs $End_Omit $All_Elems $Min_Elems
            $Compat_Elems $Min_Attrs $MIME_Type @MIME_Attrs %Req_Attrs
            $All_Attrs $Depr_Elems);

use Carp qw(carp);
use HTML::Tagset 3.03 ();

BEGIN
{

  $VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

  # We can use Regex::PreSuf for a small runtime speed gain.
  local *presuf;
  eval {
    local $SIG{__DIE__};
    require Regex::PreSuf;
    *presuf = \&Regex::PreSuf::presuf;
  };
  *presuf = sub { return join('|', sort(@_)); } if $@;

  sub make_re {
    return '\b(?:' . presuf(@_) . ')\b';
  }


  # --- Preload regexps.


  $Tag_End = qr/(?<!\\-)>/o; # Protect Perl's "->".

  my $tmp = '';
  my %tmp = ();

  foreach my $attr (values(%HTML::Tagset::linkElements)) {
    %tmp = (%tmp, map { $_ => 1 } @$attr) if (ref($attr) eq 'ARRAY');
    $tmp{xmlns} = 1;
    $tmp{profile} = 1;
  }
  $URI_Attrs = make_re(keys(%tmp));


  %tmp = %HTML::Tagset::optionalEndTag;
  $tmp{option} = 1;
  $End_Omit = make_re(keys(%tmp));


  # isKnown contains some entries like "~pi" etc, hence the grep
  $All_Elems = make_re(grep(!/^~/, keys %HTML::Tagset::isKnown));


  %tmp = ();
  foreach my $attr (values(%HTML::Tagset::boolean_attr)) {
    if (ref($attr) eq 'HASH') {
      foreach my $a (keys %$attr) {
        $tmp{$a} = 1;
      }
    } elsif (! ref($attr)) {
      $tmp{$attr} = 1;
    }
    $tmp{noresize} = 1;
    $tmp{readonly} = 1;
    $tmp{declare}  = 1;
    $tmp{defer}    = 1;
  }
  $Min_Attrs = make_re(keys %tmp);


  # HTML elements that have forbidden end tag.
  $Min_Elems = make_re(qw(area base basefont br col embed frame hr img input
                          isindex link meta param));


  # This contains elements that are commonly left empty, but require end tag.
  $Compat_Elems = make_re(qw(p script textarea));


  # RFC 2046 says x-foo top-level types are allowed, but discouraged...
  $MIME_Type =
    qr|
    ^
    make_re(qw(application audio image message multipart text video))
    /\w+[-\w\.]+\w+\b
    $
    |iox;


  # Elements that have attributes with multiple (comma-separated) MIME types:
  #   form, input: accept
  # Parens in these regexps:
  #   1: element, 2: attribute, 3:first quote,
  #   4: value (including possible end quote), 5: value
  $tmp = '<(%s)\s[^>]*\b(%s)=(\\\?["\'])?((.*?)(?:\3|\s|' . $Tag_End . '))';
  @MIME_Attrs =
    map { qr/$_/i }
    ( sprintf($tmp, make_re(qw(a link param style script)), 'type'),
      sprintf($tmp, 'object',                               '(?:code)type'),
      sprintf($tmp, 'form',                                 'enctype'),
    );


  # All known attributes.
  $All_Attrs =
    make_re(qw(abbr accept accept-charset accesskey action align alink alt
               archive axis background bgcolor border cellpadding cellspacing
               char charoff charset checked cite class classid clear code
               codebase codetype color cols colspan compact content coords
               data datetime declare defer dir disabled enctype face for frame
               frameborder headers height href hreflang hspace http-equiv id
               ismap label lang language leftmargin link longdesc marginheight
               marginwidth maxlength media method multiple name nohref
               noresize noshade nowrap object onblur onchange onclick
               ondblclick onfocus onkeydown onkeypress onkeyup onload
               onmousedown onmousemove onmouseout onmouseover onmouseup
               onreset onselect onsubmit onunload profile prompt readonly rel
               rev rows rowspan rules scheme scope scrolling selected shape
               size span src standby start style summary tabindex target text
               title topmargin type usemap valign value valuetype version
               vlink vspace width wrap));


  # This has some special cases which are handled by code later.
  # See _attributes()
  $tmp = '<((%s)\s.*?(?:(%s)=|' . $Tag_End . '))';
  %tmp =
    ( action  => sprintf($tmp, 'form',                       'action' ),
      alt     => sprintf($tmp, make_re(qw(area img)),        'alt'    ),
      cols    => sprintf($tmp, 'textarea',                   'cols'   ),
      content => sprintf($tmp, 'meta',                       'content'),
      dir     => sprintf($tmp, 'bdo',                        'dir'    ),
      height  => sprintf($tmp, 'applet',                     'height' ),
      href    => sprintf($tmp, 'base',                       'href'   ),
      id      => sprintf($tmp, 'map',                        'id'     ), # *
      label   => sprintf($tmp, 'optgroup',                   'label'  ),
      name    => sprintf($tmp, make_re(qw(input map param)), 'name'   ), # *
      rows    => sprintf($tmp, 'textarea',                   'rows'   ),
      size    => sprintf($tmp, 'basefont',                   'size'   ),
      src     => sprintf($tmp, 'img',                        'src'    ),
      type    => sprintf($tmp, make_re(qw(script style)),    'type'   ),
      width   => sprintf($tmp, 'applet',                     'width'  ),
    );
  %Req_Attrs = map { $_ => qr/$tmp{$_}/i } keys(%tmp);


  # Deprecated elements as of HTML 4.01.
  # Parens: 1: for pos(), 2: element
  $tmp = make_re(qw(applet basefont center dir font isindex menu s strike u));
  $Depr_Elems = qr/<(($tmp)(?:\s|$Tag_End|\Z))/io; # \Z) wont mess indent :)

  # Deprecated attributes as of HTML 4.01, not including deprecated elements
  # and their attributes.
  #%Depr_Attrs =
  #  ( align      => make_re(qw(caption iframe img input object legend
  #                             table hr div h1 h2 h3 h4 h5 h6 p)),
  #    alink      => 'body',
  #    background => 'body',
  #    bgcolor    => make_re(qw(body table tr td th)),
  #    border     => make_re(qw(img object)),
  #    clear      => 'br',
  #    compact    => make_re(qw(dir dl ol ul)),
  #    height     => make_re(qw(td th)), # TODO: table in XHTML ???
  #    hspace     => make_re(qw(img object)),
  #    language   => 'script',
  #    link       => 'body',
  #    noshade    => 'hr',
  #    nowrap     => make_re(qw(td th)),
  #    start      => 'ol',
  #    text       => 'body',
  #    type       => make_re(qw(li ol ul)),
  #    value      => 'li',
  #    version    => 'html',
  #    vlink      => 'body',
  #    vspace     => make_re(qw(img object)),
  #    width      => make_re(qw(hr td th pre)),
  #  );

}

# ----- Constructors -------------------------------------------------------- #

sub new
{
  my ($class, %attr) = @_;

  my $this = bless({
                    _mode         => undef,
                    _xml          => undef,
                    _xhtml        => undef,
                    _html         => undef,
                    _tab_width    => undef,
                    _num_errors   => undef,
                    _num_warnings => undef,
                    _quote        => undef,
                   },
                   (ref($class) || $class));

  my $tab_width = delete($attr{tab_width});
  $tab_width = 4 unless defined($tab_width);
  $this->tab_width($tab_width) or $this->tab_width(4);

  my $mode = delete($attr{mode});
  $mode = 'XHTML' unless defined($mode);
  $this->mode($mode) or $this->mode('XHTML');

  my $quote = delete($attr{quote});
  $this->quote(defined($quote) ? $quote : '"');

  $this->reset();

  if (my @unknown = keys(%attr)) {
    carp("** Unrecognized attributes: " . join(',', sort(@unknown)));
  }

  return $this;
}

# ---------- Check: deprecated ---------------------------------------------- #

sub deprecated { return shift->_wrap('_deprecated', @_);}

sub _deprecated
{
  my ($this, $line) = @_;
  my @errors = ();

  while ($line =~ /\b(document\.location)\b/go) {
    push(@errors, { col  => $this->_pos($line, pos($line) - length($1)),
                    type => 'W',
                    mesg =>
                    'document.location is deprecated, use window.location ' .
                    'instead',
                  },
        );
  }

  # ---

  while ($line =~ /$Depr_Elems/g) {
    push(@errors, { col  => $this->_pos($line, pos($line) - length($1)),
                    elem => $2,
                    mesg => 'deprecated element',
                    type => 'W',
                  },
        );
  }


  return @errors;
}

# ----- Check: attributes --------------------------------------------------- #

sub attributes { return shift->_wrap('_attributes', @_); }

#
# Note that minimized attributes are forbidden only in XHTML, but it
# is legal to have them in HTML too.
#
sub _attributes
{
  my ($this, $line) = @_;
  return () unless $this->{_html};

  my @errors = ();
  my $type = $this->{_xhtml} ? 'E' : 'W';

  # BUG: Does not catch non-lowercase minimized attributes, like CHECKED.
  while ($line =~ /
         (?:(?<=[\w\"\'])\s+)
         (
          ($All_Attrs)
          =
          (.\S?) # Would like to see ['"], possibly backslashed.
         )
         /giox) {

    my ($pos, $att, $q) = (pos($line) - length($1), $2, $3);

    if ($att ne lc($att)) {
      push(@errors, { col  => $this->_pos($line, $pos),
                      attr => $att,
                      type => $type,
                      mesg => 'non-lowercase attribute',
                    },
          );
    }

    if (my $tq = $this->{_quote}) {
      my $pos = $this->_pos($line, $pos + length($att) + 1);
      if ($q =~ /\\?([\"\'])/o) {
        if ($1 ne $tq) {
          push(@errors, { col  => $pos,
                          type => 'W',
                          attr => $att,
                          mesg => 'quote values with $tq',
                        },
              );
        }
      } else {
        push(@errors, { col  => $pos,
                        attr => $att,
                        type => 'W',
                        mesg => 'unquoted value',
                      },
            );
      }
    }
  }


  # Optimization.
  return @errors unless $line =~ /<\w\w../o;


  # Not doing this check inside <>'s would result in too much bogus.
  while ($line =~ /
         <.+?
         [^.] # Protect eg. "foo.checked" javascript constructs.
         (
          ($Min_Attrs)
          ([=\s]|$Tag_End)
         )
         /giox) {
    my ($m, $attr, $eq) = ($1, $2, $3);
    if ($eq ne '=') {
      push(@errors, { col  => $this->_pos($line, pos($line) - length($m)),
                      attr => $attr,
                      type => $type,
                      mesg => 'minimized attribute',
                    },
          );
    }
  }

  while (my ($attr, $re) = each(%Req_Attrs)) {

    my $msg = 'missing required attribute: "%s"';

    # Parens: 1: for pos(), 2:element, 3: attribute (or undef if not found)
    while ($line =~ /$re/g) {

      my ($m, $el, $att) = ($1, $2, $3);

      if (! $att
          &&
          (
           # Special cases:

           # input/@name not required if input/@type = "submit" or "reset".
           ($el eq 'input' &&
            # TODO: this is crap
            $line !~ /\btype=(\\?[\"\'])?(submi|rese)t\b/io)

           ||

           # map/@id required only in XHTML 1.0+.
           ($this->{_xhtml} && $el eq 'map' && $attr eq 'id')

          )) {
        push(@errors, { col  => $this->_pos($line, pos($line) - length($m)),
                        type => 'E',
                        mesg => sprintf($msg, $attr),
                        elem => $el,
                      },
            );
      }
    }
  }

  return @errors;
}

# ----- Check: MIME types --------------------------------------------------- #

sub mime_types { return shift->_wrap('_mime_types', @_); }

sub _mime_types
{
  my ($this, $line) = @_;
  return () unless $this->{_html};

  # Optimization. "<a type=" is the shortest we know nowadays.
  return () unless $line =~ /<\w.{6}/;

  my @errors = ();
  my $msg = 'bad media type: "%s"';
  my $jsmsg =
    'unregistered media type: "%s", use application/x-javascript instead';

  foreach my $re (@MIME_Attrs) {

    while ($line =~ /$re/g) {

      my ($elem, $attr, $m, $mtype) = ($1, $2, $4, $5);
      my $pos = $this->_pos($line, pos($line) - length($m));

      if ($mtype !~ $MIME_Type) {
        push(@errors, { col  => $pos,
                        type => 'E',
                        elem => $elem,
                        attr => $attr,
                        mesg => sprintf($msg, $mtype),
                      },
            );
      } elsif (lc($elem) eq 'script' &&
               $mtype =~ /(ecm|jav)ascript/io &&
               lc($mtype) ne 'application/x-javascript') {
        push(@errors, { col  => $pos,
                        type => 'W',
                        elem => $elem,
                        attr => $attr,
                        mesg => sprintf($jsmsg, $mtype),
                      },
            );
      }
    }
  }

  return @errors;
}

# ----- Check: elements ----------------------------------------------------- #

sub elements { return shift->_wrap('_elements', @_); }

sub _elements
{
  my ($this, $line) = @_;
  return () unless $this->{_html};

  my @errors = ();

  # ---

  my $type = $this->{_xhtml} ? 'E' : 'W';
  my $msg = 'non-lowercase element%s';

  while ($line =~ /
         <
         (\/?)
         (
          ($All_Elems)
          (\s|$Tag_End|\Z)   # \Z) because $) would screw my indentation :)
         )
         /giox) {
    my ($slash, $pos, $elem) = ($1, pos($line) - length($2), $3);
    if ($elem ne lc($elem)) {
      push(@errors, { col  => $this->_pos($line, $pos),
                      type => $type,
                      elem => $elem,
                      mesg => sprintf($msg, ($slash ? ' end' : '')),
                    },
          );
    }
  }

  # ---

  $msg = 'missing end tag';

  while ($line =~ /
         <
         (
          ($End_Omit)
          .*?
          $Tag_End
          [^<]*
          <
          (.?)
          ($End_Omit)
         )
         /giox) {
    my ($m, $start, $slash, $end) = ($1, $2, $3, $4);
    if ((lc($start) eq lc($end) && $slash ne '/') ||
        # TODO: this needs tuning.  See t/002endtag.t, line 6.
        (lc($start) ne lc($end))) {
      push(@errors, { col  => $this->_pos($line, pos($line) - length($m)),
                      mesg => $msg,
                      elem => $start,
                      type => 'W',
                    },
          );
    }
  }

  # ---

  # We also allow a backslashed "/", they're common in eg. Perl regexps.
  # Consider
  #   $foo =~ s/bar/baz<br \/>/;
  while ($line =~ /
         <                # TODO: Do we really need to see a known
         ($All_Elems)     #       element here?
         .*?
         (\s?\\?\/?$Tag_End)
         /giox) {
    my ($el, $end) = ($1, $2);
    my $pos = $this->_pos(pos($line) - length($end));
    if ($end =~ m|/>$|o) {
      if ($this->{_xhtml} &&
          $el !~ /^$Compat_Elems$/io &&   # These don't apply here, see later.
          $end !~ m|\s\\?/|o) {
        push(@errors, { col  => $pos,
                        type => 'W',
                        mesg => 'use space before "/>" for compatibility',
                        elem => $el,
                      },
            );
      } elsif (! $this->{_xml} && $end =~ m|/>$|o) {
        push(@errors, { col  => $pos,
                        type => 'E',
                        mesg => 'element end "/>" is allowed in X(HT)ML only',
                        elem => $el,
                      },
            );
      }
    }
  }

  # ---

  # Check for missing " />".
  if ($this->{_xhtml}) {

    while ($line =~ /
           <
           ($Min_Elems)
           .*?
           (\/?$Tag_End)
           /giox) {
      my ($el, $end) = ($1, $2);
      if ($end ne '/>') {
        push(@errors, { col  => $this->_pos($line, pos($line) - length($end)),
                        elem => $el,
                        mesg => 'missing " />"',
                        type => 'E',
                      },
            );
      }
    }

    while ($line =~ /
           <
           ($Compat_Elems)
           .*?
           (\s?.?$Tag_End)
           /giox) {
      my ($el, $end) = ($1, $2);
      $msg = 'use "<%s></%s>" instead of <%s for compatibility';
      if ($end =~ m|(\s?/>)$|o) {
        my $e = lc($el);
        push(@errors, { col  => $this->_pos($line, pos($line) - length($end)),
                        elem => $el,
                        mesg => sprintf($msg, $e, $e, $e . $1),
                        type => 'W',
                      },
            );
      }
    }
  }

  return @errors;
}

# ----- Check: entities ----------------------------------------------------- #

# Check for unterminated entities in URIs (usually & instead of &amp;).
sub entities { return shift->_wrap('_entities', @_);}

sub _entities
{
  my ($this, $line) = @_;
  return () unless $this->{_html};

  # Optimization. "src=&" is the shortest we know of.
  return () unless $line =~ /\w{3}=./;

  my @errors = ();
  my $msg = 'unterminated entity: %s';

  while ($line =~ /
         ($URI_Attrs)
         =
         (
          (.+?)
          (?:
           (?<!\[%) # Protect Template Toolkit's "[% ".
           \s       # A space terminates here.
           (?!%\])  # Protect Template Toolkit's " %]".
           |
           $Tag_End
          )
         )
         /giox) {
    my ($attr, $pos, $val) = ($1, pos($line) - length($2), $3);
    while ($val =~ /(&([^;]*?))[=\"\'\#\s]/go) {
      push(@errors, { col =>
                      $this->_pos($line, $pos + pos($val) - length($2) - 1),
                      type => 'E',
                      mesg => sprintf($msg, $1),
                      attr => $attr,
                    },
          );
    }
  }

  return @errors;
}

# ----- Check: DOCTYPE ------------------------------------------------------ #

# Check for doctype declaration errors.
sub doctype { return shift->_wrap('_doctype', @_); }

sub _doctype
{
  my ($this, $line) = @_;
  my @errors = ();

  while ($line =~ /<!((DOCTYPE)\s+([^>]+)>)/gio) {
    my ($pos, $dt, $rest) = (pos($line) - length($1), $2, $3);
    if ($dt ne "DOCTYPE") {
      push(@errors, { col  => $this->_pos($line, $pos),
                      type => 'E',
                      mesg => "DOCTYPE must be uppercase: $dt",
                    },
          );

      $pos = pos($line) - length($rest) - 1;

      if ($this->{_html} &&
          (my ($p1, $html, $t) = ($rest =~ /^((html)\s+)(\w+)?/io))) {

        # TODO: better message, maybe this should not be XHTML-only.
        if ($this->{_xhtml} && $html ne 'html') {
          my $msg = "\"html\" in DOCTYPE should be lowercase in XHTML: $html";
          push(@errors, { col  => $this->_pos($line, $pos),
                          type => 'W',
                          mesg => $msg,
                        },
              );
        }

        $pos += length($p1);

        if ($t =~ /^(PUBLIC|SYSTEM)$/io) {
          if ($t ne uc($t)) {
            my $msg = uc($t) . " must be uppercase: \"$t\"";
            push(@errors, { col  => $this->_pos($line, $pos),
                            type => 'E',
                            mesg => $msg,
                          },
                );

            if ($this->{_xml} && uc($t) eq 'PUBLIC') {
              # TODO: In XML, you can't declare public ID without
              # system ID.  Check this.
            }
          }
        } else {
          my $msg = "PUBLIC or SYSTEM should follow root element name: \"$t\"";
          push(@errors, { col  => $this->_pos($line, $pos),
                          type => 'W',
                          mesg => $msg,
                        },
              );
        }
      }
    }
  }

  return @errors;
}


# ---------- Accessors and mutators ----------------------------------------- #

sub mode
{
  my ($this, $mode) = @_;
  if ($mode) {
    my $was_xml = $this->{_xml};
    if ($mode eq 'HTML') {
      $this->{_xhtml} = 0;
      $this->{_xml}   = 0;
      $this->{_html}  = 1;
      $this->{_mode}  = $mode;
    } elsif ($mode eq 'XML') {
      $this->{_xhtml} = 0;
      $this->{_xml}   = 1;
      $this->{_html}  = 0;
      $this->{_mode}  = $mode;
      $this->quote('"') unless $was_xml;
    } elsif ($mode eq 'XHTML') {
      $this->{_xhtml} = 1;
      $this->{_xml}   = 1;
      $this->{_html}  = 1;
      $this->{_mode}  = $mode;
      $this->quote('"') unless $was_xml;
    } else {
      carp("** Mode must be one of XHTML, HTML, XML (resetting to XHTML)");
      $this->mode('XHTML');
    }
  }
  return $this->{_mode};
}

sub tab_width
{
  my ($this, $tw) = @_;
  if (defined($tw)) {
    if ($tw > 0) {
      $this->{_tab_width} = $tw;
    } else {
      carp("** TAB width must be > 0.");
    }
  }
  return $this->{_tab_width};
}

sub stats
{
  my $this = shift;
  return ($this->{_num_errors}, $this->{_num_warnings});
}

sub reset
{
  my $this = shift;
  my ($e, $w) = $this->stats();
  $this->{_num_errors} = 0;
  $this->{_num_warnings} = 0;
  return ($e, $w);
}

sub quote
{
  my ($this, $q) = @_;
  if (defined($q)) {
    # We always allow " and ', and empty when non-xml, refuse others.
    my $is_ok = ($q eq '"'       || $q eq "'"   );
    $is_ok  ||= (! $this->{_xml} && ! length($q));
    if ($is_ok) {
      $this->{_quote} = $q;
    } else {
      carp("** Refusing to set quote to ", ($q || '[none]'),
           " when in " . $this->mode() . " mode");
    }
  }
  return $this->{_quote};
}

# ---------- Utility methods ------------------------------------------------ #

sub _pos
{
  my ($this, $line, $pos) = @_;
  $pos = 0 unless (defined($pos) && $pos > 0);
  if ($this->{_tab_width} > 1 && $pos > 0) {
    my $pre = substr($line, 0, $pos);
    while ($pre =~ /\t/g) {
      $pos += $this->{_tab_width} - 1;
    }
  }
  return $pos;
}

sub _wrap
{
  my ($this, $method, @lines) = @_;
  my @errors = ();
  my $ln = 0;

  for (my $ln = 0; $ln < scalar(@lines); $ln++) {
    foreach my $err ($this->$method($lines[$ln])) {
      $err->{line}   = $ln;
      if (! $err->{mesg}) {
        $err->{mesg} = "no error message, looks like you found a bug";
        carp("** " . ucfirst($err->{mesg}));
      }
      $err->{col}  ||= 0;
      if (! $err->{type}) {
        carp("** No error type, looks like you found a bug");
        $err->{type} = '?';
      }
      push(@errors, $err);
      if ($err->{type} eq 'W') {
        $this->{_num_warnings}++;
      } else {
        $this->{_num_errors}++;
      }
    }
  }

  return @errors;
}

1;

package require::case;
use strict;
use warnings;

our $VERSION = '0.001000';
$VERSION =~ tr/_//d;

BEGIN {
  *_HAVE_IS_UTF8 = defined &utf8::is_utf8 ? sub(){1} : sub(){0};
}

sub import {
  shift;
  for my $arg (@_) {
    if ($arg eq '-inc') {
      my $hook = \&_inc_hook;
      @INC = ($hook, grep !(ref $_ eq ref $hook && $_ == $hook), @INC);
    }
    elsif ($arg eq '-global_require') {
      require Sub::Uplevel;
      *CORE::GLOBAL::require = \&_global_require;
    }
    else {
      die sprintf "%s at %s line %s.", "Unsupported argument '$arg'", (caller)[1,2];
    }
  }
}

sub _is_version {
  my $check = shift;
  no warnings 'numeric';
  return
      ! defined $check          ? 0
    : length ref $check         ? 0
    : ref \$check eq 'VSTRING'  ? 1
    : (
      !(_HAVE_IS_UTF8 && utf8::is_utf8($check))
      && length( (my $dummy = '') & $check )
      && 0 + $check eq $check
    )                           ? 1
                                : 0;
}

sub _check_inc {
  my $want = shift;
  for my $inc (@_) {
    if (ref $inc) {
      # assume it's ok
    }
    else {
      my @real = _real_case($inc, $want);
      if (@real) {
        shift @real;
        my $real = join '/', @real;
        if ($real ne $want) {
          my @c = caller(2);
          die sprintf '%s at %s line %s.',
            'incorrect case', $c[1], $c[2];
        }
      }
    }
  }
}

sub _inc_hook {
  my ($hook, $want) = @_;
  my @inc = @INC;
  my ($found) = grep ref $inc[$_] eq ref $hook && $inc[$_] == $hook, 0 .. $#inc;
  if (defined $found) {
    splice @inc, 0, $found + 1;
  }
  _check_inc($want, @inc);
}

my $searchable
  = $^O eq 'VMS' ? 
    qr{\A(?:\.?\.?/|[<\[][^.\-\]>]|[A-Za-z0-9_\$\-\~]+(?<!\^):)}
  : $^O eq 'MSWin32' ? 
    qr{\A(?:\.?\.?/|\\\\|.:|\.\.?\\)}
  : $^O eq 'NetWare' ?
    qr{\A(?:\.?\.?/|\\\\|.:|...:)}
  : $^O eq 'dos' ?
    qr{\A(?:\.?\.?/|.:)}
  :
    qr{\A\.?\.?/};

sub _global_require {
  my $want = shift;

  if (_is_version($want)) {
    # do nothing
  }
  elsif ($want =~ $searchable) {
    # relative or absolute path, not a module
    # do nothing
  }
  else {
    _check_inc($want, @INC);
  }

  my (@c) = caller;

  my $code;
  my $e;
  {
    local $@;
    $code = eval <<"END" or $e = $@;
package $c[0];
#line $c[2] "$c[1]"
sub { CORE::require(\$_[0]) }
END
  }
  die $e if defined $e;
  Sub::Uplevel::uplevel(2, $code, $want);
}

sub _real_case {
  my ($base, $file) = @_;
  my @base = $base;
  $file =~ s{\A/+}{};
  for my $part (split m{/+}, $file) {
    opendir my $dh, join('/', @base) or return;
    my @items = readdir $dh;
    closedir $dh;
    my @possible = grep lc $_ eq lc $part, @items;
    if (@possible > 1) {
      push @base, $part;
    }
    elsif (@possible) {
      push @base, @possible;
    }
    else {
      return;
    }
  }

  return
    if !-e join('/', @base);

  return @base;
}

1;
__END__

=head1 NAME

require::case - Require case of modules to match file system

=head1 SYNOPSIS

  use require::case -inc;

=head1 DESCRIPTION

Require the case of a module to match the case found on disk, even on case
insensitive file systems.

=head1 AUTHOR

haarg - Graham Knop (cpan:HAARG) <haarg@haarg.org>

=head1 CONTRIBUTORS

None so far.

=head1 COPYRIGHT

Copyright (c) 2021 the require::case L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself. See L<https://dev.perl.org/licenses/>.

=cut

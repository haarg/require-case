use strict;
use warnings;
use Test::More;
use File::Spec;

my $lib;
BEGIN {
  # real file name is MyTest.pm
  my $canary = 'mytest.pm';

  my $tlib = File::Spec->rel2abs('t/lib');
  if ($ENV{TEST_NO_REQUIRE_CASE} || -f "$tlib/$canary") {
    $lib = $tlib;
  }
  # try using a temp directory
  else {
    require File::Temp;
    require File::Find;
    require File::Copy;

    my $tmpdir = File::Temp::tempdir('require-case-XXXXXX', CLEANUP => !$ENV{TEST_REQUIRE_CASE_KEEP}, TMPDIR => 1);
    $lib = File::Spec->catdir($tmpdir, 'lib');
    File::Find::find({
      no_chdir => 1,
      wanted => sub {
        my $file = $_;
        my $relname = File::Spec->abs2rel($file, $tlib);
        my $target = File::Spec->rel2abs($relname, $lib);
        if (-d $file) {
          mkdir $target;
        }
        else {
          File::Copy::copy($file, $target);
        }
      },
    }, $tlib);

    if (-f "$lib/$canary") {
    }
    elsif ($ENV{RELEASE_TESTING}) {
      diag 'Case insensitive file system required under RELEASE_TESTING!';
    }
    else {
      plan skip_all => 'Unable to find case insensitive file system';
    }
  }
  unshift @INC, $lib;

  if (!$ENV{TEST_NO_REQUIRE_CASE}) {
    ok -f "$lib/$canary", 'Found a case insensitive file system' or do {
      done_testing;
      exit;
    };
  }
}

my $warnings;
BEGIN {
  $warnings = 0;
  $SIG{__WARN__} = sub { 
    warn @_;
    $warnings++;
  };
}

sub exception (&) {
  my $cb = shift;
  my $e;
  local $@;
  eval {
    $cb->();
    1;
  } or $e = $@;
  return $e;
}

BEGIN {
  if ($ENV{TEST_ACME_REQUIRE_CASE}) {
    require Acme::require::case;
    Acme::require::case->import;
  }
  elsif ($ENV{TEST_NO_REQUIRE_CASE}) {
  }
  elsif ($ENV{TEST_REQUIRE_CASE_INC_HOOK}) {
    require require::case;
    require::case->import(-inc);
  }
  else {
    require require::case;
    require::case->import(-global_require);
  }
}

if (!$ENV{TEST_NO_REQUIRE_CASE}) {
  like exception { require mytest }, qr/incorrect case/,
    'caught wrong case for simple file';

  like exception { require MyTest::sub1::Sub2 }, qr/incorrect case/,
    'caught wrong case for mid directory';
}

is exception { require MyTest::Sub1::Sub2 }, undef,
  'require of correct case succeeds';

is join(', ', grep m{\AMyTest.Sub1.Sub2\.pm\z}i, keys %INC),
  'MyTest/Sub1/Sub2.pm',
  'correct entries in %INC';

is exception { require MyTest::RequireCount }, undef,
  'require of MyTest::RequireCount succeeds';

is exception { require MyTest::RequireCount }, undef,
  'require of MyTest::RequireCount succeeds again';

is $MyTest::RequireCount::count = $MyTest::RequireCount::count,
  1,
  'MyTest::RequireCount only loaded once';

is exception { require File::Spec->rel2abs('MyTest.pm', $lib) }, undef,
  'require of absolute path succeeds';

like exception { require MyTest::CompileFailure },
  qr{\A\Qerror loading MyTest::CompileFailure at $lib/MyTest/CompileFailure.pm},
  'compile failure thrown';

like exception { require MyTest::CompileFailure },
  qr{\A\QAttempt to reload MyTest/CompileFailure.pm},
  'correct error reloading after compile failure';

like exception { require MyTest::FalseReturn },
  qr{\A\QMyTest/FalseReturn.pm did not return a true value},
  'correct error for module returning false';

{
  my $next_perl = int($] + 1);
  my $this_perl = int($]);
  my $n;
  no warnings qw(numeric void);

  for my $vf (
    '%s',
    '%s.000',
    '%s.0.0',
    'v%s',
    'do { $n = %s; $n + 0; $n }',
    'do { $n = \'%s\'; $n + 0; $n }',
  ) {
    my $code = sprintf "require $vf", $this_perl;
    is exception { eval "$code; 1" or die $@ },
      undef,
      "$code succeeds";

    $code = sprintf "require $vf", $next_perl;
    like exception { eval "$code; 1" or die $@ },
      qr/\APerl .* required--this is only/,
      "$code gives version error";
  }

  for my $perl ($this_perl, $next_perl) {
    for my $vf (
      '"v%s.pm"',
      '"%s"',
    ) {
      my $code = sprintf "require $vf", $perl;

      like exception { eval "$code; 1" or die $@ },
        qr/\ACan't locate/,
        "$code gives failure to locate";
    }

    for my $vf (
      'do { $n = \'%sa\'; $n + 0; $n }',
    ) {
      my $code = sprintf "require $vf", $perl;

      like exception { eval "$code; 1" or die $@ },
        qr/\AInvalid version format/,
        "$code gives invalid version format";
    }
  }

}

require MyTest::Stack1;

my @stack1 = @{ $MyTest::Stack2::stack[0] || [] };

is $stack1[0], 'MyTest::Stack1',
  'require caller stack level 1 is correct package';

is $stack1[1], "$lib/MyTest/Stack1.pm",
  'require caller stack level 1 is correct file';

my @main = @{ $MyTest::Stack2::stack[1] || [] };

is $main[0], __PACKAGE__,
  'require caller stack level 2 is correct package';

is $main[1], __FILE__,
  'require caller stack level 2 is correct file';

is $warnings, 0, 'no warnings';

done_testing;

package MyTest::Stack2;

our @stack = ();
my $c = 0;
while (my @c = caller($c++)) {
  push @stack, \@c;
}

1;

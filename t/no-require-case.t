$ENV{TEST_NO_REQUIRE_CASE} = 1;
do './t/require.t' or die $@ || $!;

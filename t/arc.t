$ENV{TEST_ACME_REQUIRE_CASE} = 1;
do './t/require.t' or die $@ || $!;

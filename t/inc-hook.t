$ENV{TEST_REQUIRE_CASE_INC_HOOK} = 1;
do './t/require.t' or die $@ || $!;

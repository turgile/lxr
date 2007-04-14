package AllTests;

use ConfigTest;

use Test::Unit::TestRunner;
use Test::Unit::TestSuite;

sub new {
	my $class = shift;
	return bless {}, $class;
}

sub suite {
	my $class = shift;
	my $suite = Test::Unit::TestSuite->empty_new("LXR Tests");
	$suite->add_test(Test::Unit::TestSuite->new("ConfigTest"));
	$suite->add_test(Test::Unit::TestSuite->new("SecurityTest"));
#	$suite->add_test(Test::Unit::TestSuite->new("CVSTest"));
	$suite->add_test(Test::Unit::TestSuite->new("PlainTest"));
#	$suite->add_test(Test::Unit::TestSuite->new("BKTest"));
	return $suite;
}

1;

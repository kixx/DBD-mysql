use strict;
use warnings;

use DBI;
use Test::More;
use lib 't', '.';
require 'lib.pl';

use vars qw($test_dsn $test_user $test_password);

my $dbh;
eval {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 1 });};
if ($@) {
    plan skip_all => "no database connection";
}
if ($dbh->{mysql_serverversion} < 50000) {
    plan skip_all => "You must have MySQL version 5.0.0 and greater for this test to run";
}

for my $mysql_server_prepare (0, 1) {
eval {$dbh= DBI->connect("$test_dsn;mysql_server_prepare=$mysql_server_prepare;mysql_server_prepare_disable_fallback=1", $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 1 });};

ok $dbh->do("DROP TABLE IF EXISTS dbd_mysql_t50chopzeroes"), "drop table if exists dbd_mysql_t50chopzeroes";

my $create= <<EOT;
CREATE TABLE dbd_mysql_t50chopzeroes (
  id INT(4),
  d_decimal DECIMAL(6,4),
  d_numeric NUMERIC(6,4),
  i_integer INTEGER
)
EOT

ok $dbh->do($create), "create table dbd_mysql_t50chopzeroes";

my @fields = qw(d_decimal d_numeric i_integer);
my $numfields = scalar @fields;
my $fieldlist = join(', ', @fields);

ok (my $sth= $dbh->prepare("INSERT INTO dbd_mysql_t50chopzeroes (id, $fieldlist) VALUES (".('?, ' x $numfields)."?)"));

ok (my $sth2= $dbh->prepare("SELECT $fieldlist FROM dbd_mysql_t50chopzeroes WHERE id = ?"));

my $rows;

$rows = [ [1, 0], [2, 1], [3, 2.0], [4, 3.05] ];

for my $ref (@$rows) {
	my ($id, $value) = @$ref;
	ok $sth->execute($id, ($value) x $numfields), "insert into dbd_mysql_t50chopzeroes values ($id ".(", '$value'" x $numfields).")";
	ok $sth2->execute($id), "select $fieldlist from dbd_mysql_t50chopzeroes where id = $id";

	ok $sth2->execute($id);

	$ret_ref = [];
	ok ($ret_ref = $sth2->fetchrow_arrayref);
	for my $i (0 .. $#{$ret_ref}) {
		my $choppedvalue = $value;
		my $decimal_field = ($fields[$i] =~ /^d/);
		$choppedvalue =~ s/\.?0+$// if $decimal_field; # only chop decimal, not non-decimal
		cmp_ok $ret_ref->[$i], 'eq', $choppedvalue, "ChopZeroes: $fields[$i] should ".($decimal_field ? "" : "not ")."have zeroes chopped";
	}

}
ok $sth->finish;
ok $sth2->finish;
ok $dbh->do("DROP TABLE dbd_mysql_t50chopzeroes"), "drop dbd_mysql_t50chopzeroes";
ok $dbh->disconnect;
}
done_testing;

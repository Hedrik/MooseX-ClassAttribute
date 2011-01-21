use strict;
use warnings;

use Test::More;

{
    package Role;

    use Moose::Role;
    use MooseX::ClassAttribute;

    class_has 'CA' => (
        is      => 'ro',
        isa     => 'HashRef',
        default => sub { {} },
    );
}

{
    package Role2;
    use Moose::Role;
}

{
    package Bar;
    use Moose;

    with( 'Role2', 'Role' );
}

{
    can_ok( 'Bar', 'CA', );
}

done_testing();

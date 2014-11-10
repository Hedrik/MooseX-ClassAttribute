#package Moose::Util::MetaRole;
package MooseX::ClassAttribute::Util::MetaRole;
#$Moose::Util::MetaRole::VERSION = '2.1402';
$MooseX::ClassAttribute::Util::MetaRole::VERSION = '2.1402001';
use strict;
use warnings;
use Scalar::Util 'blessed';

use List::Util 1.33 qw( first all );
use Moose::Deprecated;
#use Moose::Util 'throw_exception';
use MooseX::Util 'throw_exception';

use base 'Moose::Util::MetaRole';

sub apply_metaroles {
    my %args = @_;

    my $for = _metathing_for( $args{for} );

    if ( $for->isa('Moose::Meta::Role') ) {
        return _make_new_metaclass( $for, $args{role_metaroles}, 'role' );
    }
    else {
        return _make_new_metaclass( $for, $args{class_metaroles}, 'class' );
    }
}

sub _metathing_for {
    my $passed = shift;

    my $found
        = blessed $passed
        ? $passed
        : Class::MOP::class_of($passed);

    return $found
        if defined $found
            && blessed $found
            && (   $found->isa('Moose::Meta::Role')
                || $found->isa('Moose::Meta::Class') );

    local $Carp::CarpLevel = $Carp::CarpLevel + 1;

    throw_exception( InvalidArgPassedToMooseUtilMetaRole => argument => $passed );
}

sub _make_new_metaclass {
    my $for     = shift;
    my $roles   = shift;
    my $primary = shift;

    return $for unless keys %{$roles};

    my $new_metaclass
        = exists $roles->{$primary}
        ? _make_new_class( ref $for, $roles->{$primary} )
        : blessed $for;

    my %classes;

    for my $key ( grep { $_ ne $primary } keys %{$roles} ) {
        my $attr = first {$_}
            map { $for->meta->find_attribute_by_name($_) } (
            $key . '_metaclass',
            $key . '_class'
        );

        my $reader = $attr->get_read_method;

        $classes{ $attr->init_arg }
            = _make_new_class( $for->$reader(), $roles->{$key} );
    }

    my $new_meta = $new_metaclass->reinitialize( $for, %classes );

    return $new_meta;
}

sub apply_base_class_roles {
    my %args = @_;

    my $meta = _metathing_for( $args{for} || $args{for_class} );
    throw_exception( CannotApplyBaseClassRolesToRole => params    => \%args,
                                                        role_name => $meta->name,
                   )
        if $meta->isa('Moose::Meta::Role');

    my $new_base = _make_new_class(
        $meta->name,
        $args{roles},
        [ $meta->superclasses() ],
    );

    $meta->superclasses($new_base)
        if $new_base ne $meta->name();
}

sub _make_new_class {
    my $existing_class = shift;
    my $roles          = shift;
    my $superclasses   = shift || [$existing_class];

    return $existing_class unless $roles;

    my $meta = Class::MOP::Class->initialize($existing_class);

    return $existing_class
        if $meta->can('does_role') && all  { $meta->does_role($_) }
                                      grep { !ref $_ } @{$roles};

#    return Moose::Meta::Class->create_anon_class(
    return MooseX::Util::Meta::Class->create_anon_class(
        superclasses => $superclasses,
        roles        => $roles,
        cache        => 1,
    )->name();
}

1;
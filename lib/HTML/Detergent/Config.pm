package HTML::Detergent::Config;

=head1 NAME

HTML::Detergent::Config - Configuration object for HTML::Detergent

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use namespace::autoclean;

use MooseX::Types -declare => [qw(PathMap PathList Metadata ICB Config)];

use MooseX::Types::Moose qw(Undef Str ArrayRef HashRef);

use XML::LibXML;

our $VERSION = '0.02';

=head1 METHODS

=head2 new

=over 4

=item match

This is an ARRAY reference of XPath expressions to try against the
document, in order of preference. Entries optionally may be
two-element ARRAY references themselves, the second element being a
URL where an XSLT stylesheet may be found.

    match => [ '/some/xpath/expression',
               [ '/other/expr', '/url/of/transform.xsl' ],
             ],

=cut

subtype PathMap, as HashRef[Str|Undef];
coerce PathMap, from ArrayRef, via {
    my $x = { map { ref $_ ? @{$_}[0,1] : ($_ => undef) }  @{$_[0]} };
    $x;
};

has _match_map => (
    is       => 'ro',
    isa      => PathMap,
    required => 1,
    traits   => ['Hash'],
    default  => sub { { } },
    coerce   => 1,
    init_arg => 'match',
    handles  => {
# this whines when the key is undef
#        stylesheet  => 'get',
        stylesheets => 'values',
    },
);

sub stylesheet {
    my ($self, $key) = @_;
    return unless defined $key;
    $self->_match_map->{$key};
}

subtype PathList, as ArrayRef[Str];
coerce PathList, from ArrayRef[Str|ArrayRef],
    via { [ map { ref $_ ? @{$_}[0] : $_ } @{$_[0]} ] };

has _match_sequence => (
    is      => 'ro',
    isa     => PathList,
#    lazy    => 1,
    traits  => ['Array'],
    default => sub { [ ] },
    coerce  => 1,
    handles => {
        match_sequence => 'elements',
    },
);

=item link

This is a HASH reference where the keys correspond to C<rel>
attributes and the values to C<href> attributes of C<E<lt>linkE<gt>>
elements. If the values are ARRAY references, they will be processed
in document order. C<rel> attributes will be sorted lexically. If a
callback is supplied instead, the caller expects a result of the same
form.

    link => { rel1 => 'href1', rel2 => [ qw(href2 href3) ] },

    # or

    link => \&_link_cb,

=cut

subtype Metadata, as HashRef[ArrayRef[Str]];
coerce Metadata, from HashRef, via {
    #require Data::Dumper;
    #warn Data::Dumper::Dumper(\@_);

    # for some reason this needed an explicit return. go figure.
    return {
        map { $_ => (ref $_[0]{$_} eq 'ARRAY' ? $_[0]{$_} : [$_[0]{$_}] ) }
            keys %{$_[0]}
        };
};

has links => (
    is       => 'ro',
    isa      => Metadata,
    default  => sub { {} },
    traits   => ['Hash'],
#    lazy     => 1,
    coerce   => 1,
    init_arg => 'link',
);

=item meta

This is a HASH reference where the keys correspond to C<name>
attributes and the values to C<content> attributes of
C<E<lt>metaE<gt>> elements. If the values are ARRAY references, they
will be processed in document order. C<name> attributes will be sorted
lexically. If a callback is supplied instead, the caller expects a
result of the same form.

    meta => { name1 => 'content1',
              name2 => [ qw(content2 content3) ] },

    # or

    meta => \&_meta_cb,

=cut

has metadata => (
    is       => 'ro',
    isa      => Metadata,
    default  => sub { {} },
    traits   => ['Hash'],
#    lazy     => 1,
    coerce   => 1,
    init_arg => 'meta',
    
);

=item callback

These callbacks will be passed into the internal L<XML::LibXSLT>
processor. See L<XML::LibXML::InputCallback> for details.

    callback => [ \&_match_cb, \&_open_cb, \&_read_cb, \&_close_cb ],

    # or

    callback => $icb, # isa XML::LibXML::InputCallback

=back

=cut

class_type ICB, { class => 'XML::LibXML::InputCallback' };
coerce ICB, from ArrayRef, via {
    my $x = XML::LibXML::InputCallback->new;
    $x->register_callbacks(shift);
    $x;
};

has callback => (
    is  => 'ro',
    isa => ICB,
);

class_type Config, { class => __PACKAGE__ };
coerce Config, from HashRef,
    via { HTML::Detergent::Config->new(shift) };

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my %p = ref $_[0] ? %{$_[0]} : @_;
    $p{_match_sequence} = $p{match};

    $class->$orig(%p);
};

=head2 stylesheets

List all stylesheets associated with an XPath expression.

=head2 stylesheet

Retrieve a stylesheet for a given XPath expression.

=cut

__PACKAGE__->meta->make_immutable;
no Moose;

1;

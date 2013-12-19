package DummyIterable;

sub next {
    my $self = shift;
    shift @$self;
}

1;

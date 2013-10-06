package Car;

sub all_brands {
    return qw / Toyota Nissan /;
}

sub new {
    my $class = shift;
    return bless({}, $class);
}

sub set_brand {
    my $self = shift;
    $self->{brand} = shift;
}

sub brand {
    my $self = shift;
    return $self->{brand}
}

sub drive {
    my $self = shift;
    my $distance = shift;

    $self->{distance} ||= 0;
    $self->{distance} += $distance;
    return undef
}

sub distance {
    my $self = shift;
    return $self->{distance};
}

sub out_of_gas {
    my $self = shift;
    die "Out of gas!";
}

1; # satisfy require

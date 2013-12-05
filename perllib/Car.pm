#
# Car.pm
#
# Copyright (C) 2013, Timo Kluck <tkluck@infty.nl>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
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

# Copyright 2000-2001 ActiveState

package Python::Object;

use strict;
use vars qw(@ISA $VERSION $AUTOLOAD);

require Carp;

use overload '""'   => \&Python::PyObject_Str,
             'bool' => \&Python::PyObject_IsTrue,
             '@{}'  => sub { my @a; tie @a, "Python::Object", @_; \@a },
             '%{}'  => sub { my %h; tie %h, "Python::Object::Hash", @_; \%h },
             '&{}'  => sub { my $self = shift;
                             return sub {
				 Python::PyObject_CallObject($self, @_);
			     }
                           };

$VERSION = '1.00';

Python::Object->bootstrap($VERSION);

# We could have moved these methods to the Python::Object::Array
# namespace, but that would mean one more level of indirection and is
# probably not worth it.
sub TIEARRAY { $_[1] }

*FETCH = \&Python::PyObject_GetItem;
*STORE = \&Python::PyObject_SetItem;
*FETCHSIZE = \&Python::PyObject_Length;

sub PUSH {
    my $o = shift;
    while (@_) {
	$o->append(shift);
    }
}

sub UNSHIFT {
    my $o = shift;
    while (@_) {
	$o->insert(0, pop);
    }
}

sub POP {
    shift->pop();
}

sub SHIFT {
    shift->pop(0);
}


sub SPLICE {
    my $o = shift;
    my $olen = FETCHSIZE($o);
    my $offset = @_ ? shift : 0;
    if ($offset < 0) {
	$offset += $olen;
	die "offset outside" if $offset < 0;
    }
    elsif ($offset > $olen) {
	$offset = $olen;
    }
    my $len = @_ ? shift : $olen - $offset;
    if ($len < 0) {
	$len = $olen - $offset + $len;
	$len = 0 if $len < 0;
    }
    elsif ($offset + $len > $olen) {
	$len = $olen - $offset;
    }

    # take out
    my @old;
    push(@old, $o->pop($offset)) while $len--;

    # put back
    while (@_) {
	$o->insert($offset, pop);
    }

    return @old;
}

sub EXISTS {
    eval { &FETCH; };
    return !$@;
}

sub DELETE {
    my $old = &FETCH;
    &Python::PyObject_DelItem;
    $old;
}

sub DESTROY { }


# The following AUTOLOAD provide a more convenient way to access
# attributes that mimic the normal way to give attribute access in
# perl.
#
#   $obj->foo
#
# will return an attribute or call a method.  An exception will be
# raised if the object does not have such an attribute.
#
#   $obj->foo(42)
#
# will set an attribute or call a method
#
#  $obj->foo(3,4)
#
# will always be treated as a method call.

sub AUTOLOAD {
    my $self = shift;
    my $method = substr($AUTOLOAD, rindex($AUTOLOAD, '::')+2);
    Carp::croak("No static method $method for $self") unless ref($self);
    if (@_ == 1 && !Python::hasattr($self, $method)) {
	Python::setattr($self, $method, $_[0]);
	return;
    }
    my $attr = Python::getattr($self, $method);
    if (@_ > 1 || Python::PyCallable_Check($attr)) {
	my $kw;
	# I could not really decide on what way to support
	# keyword arguments to python methods, so I ended up
	# with two ways for now.
	if (@_ && UNIVERSAL::isa($_[-1], "Python::Keywords")) {
	    $kw = pop(@_);
	}
	else {
	    while (@_ >= 2 && ref(\$_[-2]) eq "GLOB") {
		my($key, $val) = splice(@_, -2);
		$kw->{substr($key, rindex($key, "::")+2)} = $val;
	    }
	}
	$attr = Python::apply($attr, \@_, $kw);
    }
    elsif (@_ == 1) {
	Python::setattr($self, $method, @_);
    }

    if (wantarray) {
	return @$attr if Python::PySequence_Check($attr);
	return %$attr if Python::PyMapping_Check($attr);
    }

    return $attr;
}

package Python;

# set up some aliases
*hasattr = \&PyObject_HasAttr;
*getattr = \&PyObject_GetAttr;
*setattr = \&PyObject_SetAttr;
*delattr = \&PyObject_DelAttr;

# should we??
*getitem = \&PyObject_GetItem;
*setitem = \&PyObject_SetItem;
*delitem = \&PyObject_DelItem;

*str   = \&PyObject_Str;
*repr  = \&PyObject_Repr;
*cmp   = \&PyObject_Compare;
*type  = \&PyObject_Type;
*hash  = \&PyObject_Hash;
*len   = \&PyObject_Length;

*funcall = \&PyObject_CallObject;  # a bit Lisp influence here :-)
*apply   = \&PyEval_CallObjectWithKeywords;
*Import  = \&PyImport_ImportModule;

sub KW {
    bless Python::dict(@_), "Python::Keywords";
}

require Exporter;
*import = \&Exporter::import;

our @EXPORT_OK = qw(hasattr getattr setattr delattr
                    getitem setitem delitem
                    str repr cmp type hash len
                    exec eval
                    funcall apply
                    Import
                    KW
                   );

package Python::Keywords;

use vars qw(@ISA);
@ISA=qw(Python::Object);

package Python::Object::Hash;

# Helper class because we need to keep keys during iteration

require Carp;

sub TIEHASH {
    my($class, $obj) = @_;
    Carp::croak("Can't treat non-mapping object as hash")
	  unless Python::PyMapping_Check($obj);

    # We use an array as our object representation. The first element is the
    # Python dictionary and the rest are the remaining keys in reverse order.
    bless [$obj], $class;
}

sub FETCH {
    $_[0] = $_[0][0];
    &Python::PyObject_GetItem;
}

sub EXISTS {
    $_[0][0]->has_key($_[1]);
}

sub STORE {
    $_[0] = $_[0][0];
    &Python::PyObject_SetItem;
}

sub DELETE {
    $_[0] = $_[0][0];
    my $old = &Python::PyObject_GetItem;
    &Python::PyObject_DelItem;
    $old;
}

sub CLEAR {
    my $self = shift;
    $self->[0]->clear;
    splice(@$self, 1);  # remove key state
}

sub FIRSTKEY {
    my $self = shift;
    my $dict = $self->[0];
    @$self = ($dict, reverse $dict->keys);
    NEXTKEY($self);
}

sub NEXTKEY {
    my $self = shift;
    return if @$self == 1;
    pop(@$self);
}


package Python::Err;

use overload '""'   => \&as_string,
             'bool' => \&as_bool;

1;

__END__

=head1 NAME

Python::Object - Encapuslate python objects

=head1 SYNOPSIS

    my $dict = Python::dict(foo => 42);

    # attribute access
    print $dict->foo, "\n";    # get
    $dict->bar(84);

    # boolean context
    if ($dict) {
	# ...
    }

    # automatic stringify
    print $dict

=head1 DESCRIPTION

Instances of the C<Python::Object> class encapulate objects within the
python interpreter.  All builtin python datatypes as well as user
defined classes, instances, extention types, and functions are python
objects.

Various functions in the C<Python::> namespace provide means for
creation and maniplation of C<Python::Object> instances.  See
L<Python> for details.

The C<Python::Object> class provide AUTOLOAD and overload features
that make it convenient to use python objects as if they where native
perl objects.  A python sequence object (like a list or a
tuple) can basically be treated as if it was a perl array.  A
python mapping object can be treaded as a hash, and callable objects
can be called directly as if they where perl code references.  Python
objects also turn into strings if used in string context or into a
reasonable test in boolean context.

=head2 Attribute access and method calls

Python object attributes can be manipulated with the getattr(),
setattr(), hasattr() and delattr() functions found in the C<Python>
package, but usually it is more convenient to rely on the automatic
mapping from method calls to attribute access operations:

=over

=item $o->foo

This will read the attribute called "foo", i.e. is a shorthand for
getattr($o, "foo") in most cases.  If the attribute is callable, then
it will be automatically called as well.

=item $o->foo(42)

This will try to set the value of attribute "foo" to be 42, i.e. it is
a shorthand for setattr($o, "foo" => 42), with the difference that it
will return the old value of the attribute as well.

If the "foo" attribute happen to be callable then this will be
resolved as a plain method call with a single argument instead.

=item $o->foo("bar", "baz")

If multiple arguments are passed to a method then it will always be
resolved as a method call, i.e. this is always just a short hand for:

  funcall(getattr($o, "foo"), "bar", "baz")

=back

As an additional convenience, if an attribute is accessed in list
context and the object to be returned is some python sequence, then
the sequence is unwrapped and the elements are returned as a perl
list.  That helps in making code like this work as expected:

   foreach ($o->method_returning_a_list) {
       # do something with each element
   }

In the same way, a mapping object in list context is unwrapped into
separate key/value pairs.  I.e. this should work as expected:

   %hash = $o->method_return_a_dictinary;

Keyword arguments are also supported for methods called this way.
There are currently two ways to set them up.  Either use globs to
indicate keys:

   $o->foo($pos1, $pos2, *key1 => $val1, *key2 => $val2);

or make a special hash object constructed with Python::KW() the last
argument:

  $o->foo($pos1, $pos2, Python::KW(key1 => $val1, key2 => $val2));

The KW() function can be imported to reduce clutter in the argument
list:

  use Python qw(KW);
  $o->foo($pos1, $pos2,
	  KW(key1 => $val1, key2 => $val2)
	 );

Note: One of these ways of specifying keyword arguments might be
dropped in the final version of this interface.

=head2 Overloading

The C<Python::Object> class use perl's overloading mechanism to make
instances behave like perl data.  Python sequence objects can be
treated like perl arrays and python mapping object can be treated like
hashes.  If $list is a reference to a C<Python::Object> wrapping a
list then statements like these are allowed:

   @array = @$list;     # copy list elements into a perl array
   $list->[0];          # same as getitem($list, 0)
   $list->[0] = 42;     # same as setitem($list, 0, 42)
   pop(@$list);         # same as $list->pop;

Correspondingly, a python dictionary $dict can be used like this:

   @array = %$dict;     # copy key/value pairs out of the dictionary
   $dict->{foo};        # same as getitem($dict, "foo")
   $dict->{foo} = 42;   # same as setitem($dict, "foo", 42)
   delete $dict->{foo}; # same as delitem($dict, "foo")
   exists $dict->{foo};

We also provide code dereferencing which make it possible to invoke
objects directly:

   $callable->("foo");  # same as funcall($callable, "foo")

For objects used in string context, the str() function will be
automatically invoked.

  "$obj";               # same as str($obj)

For objects used in boolean context, the PyObject_IsTrue() function
will be automatically invoked.

  if ($obj) { ...}     # same as if (PyObject_IsTrue($obj)) { ...}

=head1 BUGS

Some all upper case method names (see L<perltie>) are used by the
overload/tie interface and will hide the corresponding python
attribute in the object.  If you need to access an attribute with a
name clash, you need to use functions like getattr() and setattr().

=head1 COPYRIGHT

(C) 2000-2001 ActiveState

This code is distributed under the same terms as Perl; you can
redistribute it and/or modify it under the terms of either the GNU
General Public License or the Artistic License.

THIS SOFTWARE IS PROVIDED BY ACTIVESTATE `AS IS'' AND ANY EXPRESSED OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED.  IN NO EVENT SHALL ACTIVESTATE OR ITS CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=head1 SEE ALSO

L<Python>, L<Python::Err>, L<perlmodule>

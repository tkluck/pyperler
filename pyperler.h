#include <EXTERN.h> /* from the Perl distribution */
#include <perl.h> /* from the Perl distribution */
extern PerlInterpreter *my_perl;

extern void boot_DynaLoader (CV *cv);

#define stack (&ST(0))

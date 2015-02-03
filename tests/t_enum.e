include std/unittest.e
include std/get.e as g
include std/filesys.e

create_directory("tmp")
system("eui ../eudoc.ex res/s_enum.e -o tmp/s_enum.doc", 0)
system("grep -n TWO tmp/s_enum.doc  >  tmp/two.dat", 0)
system("grep -n PRIME tmp/s_enum.doc > tmp/prime.dat", 0)

integer two = open("tmp/two.dat", "r")
sequence buffer = get(two)
close(two)

integer two_line = buffer[2]

integer prime = open("tmp/prime.dat", "r")
buffer = get(prime)
close(prime)

integer prime_line = buffer[2]

test_true("The first prime appears after the prime title", prime_line < two_line )

test_report()

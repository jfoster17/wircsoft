"""
Make a list of files for use in WIRCSOFT

Options:
-n : Name   -- The name of the region
-l : Lower  -- Starting index
-u : Upper  -- Ending index
-h : Help   -- Display this help

"""

import os,sys
import getopt

def main():
    try:
        opts,args = getopt.getopt(sys.argv[1:],"n:l:u:h")
    except getopt.GetoptError,err:
        print(str(err))
        print(__doc__)
        sys.exit(2)
    for o,a in opts:
        if o == "-n":
            name = a
        elif o == "-l":
            lower = a
        elif o == "-u":
            upper = a
        elif o == "-h":
            print(__doc__)
            sys.exit(1)
        else:
            assert False, "unhandled option"
            print(__doc__)
            sys.exit(2)
    ff = open(name+".list",'w')

    for i in range(int(lower),int(upper)):
        ff.write("wirc"+str(i).zfill(4)+".fits\n")
    ff.close()

if __name__ == '__main__':
    main()

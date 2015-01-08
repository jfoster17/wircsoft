#!/scisoft/bin/python
"""
Make a list of files for use in WIRCSOFT

Options:
-s : Sky    -- Make lists for separate sky-object obs
-n : Name   -- The name of the region
-l : Lower  -- Starting index
-u : Upper  -- Ending index
-h : Help   -- Display this help

"""

import os,sys
import getopt

def main():
    do_sky = False
    try:
        opts,args = getopt.getopt(sys.argv[1:],"sn:l:u:h")
    except getopt.GetoptError,err:
        print(str(err))
        print(__doc__)
        sys.exit(2)
    for o,a in opts:
        if o == "-n":
            name = a
        elif o == "-s":
            do_sky = True
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
    if do_sky:
        pattern_length = 3 #Number of positions on
                           #sky/obj before switching
        ff = open(name+"_obj.list",'w')
        gg = open(name+"_sky.list",'w')
        hh = open(name+".list",'w')
        counter = 0
        now_on_obj = True #Start on object
        for i in range(int(lower),int(upper)+1):
            if now_on_obj:
                ff.write("wirc"+str(i).zfill(4)+".fits\n")
                counter += 1
            else:
                gg.write("wirc"+str(i).zfill(4)+".fits\n")
                counter += 1
            if counter == pattern_length:
                now_on_obj = not now_on_obj
                counter = 0
            hh.write("wirc"+str(i).zfill(4)+".fits\n")
        ff.close()
        gg.close()
        hh.close()
    else:
        ff = open(name+".list",'w')

        for i in range(int(lower),int(upper)+1):
            ff.write("wirc"+str(i).zfill(4)+".fits\n")
        ff.close()

if __name__ == '__main__':
    main()

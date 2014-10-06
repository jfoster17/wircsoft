"""
Clean up a directory

Put all the WIRCSOFT files in a subdirectory

"""

import os,sys,shutil,glob

def main():
    filelist = sys.argv[1]

    objname = filelist.rstrip(".list")

    print("Object name: "+objname)
    try:
        os.mkdir(objname)
    except OSError:
        pass

    ff = open(filelist,'r')
    for line in ff:
        base = line.strip()
        raw = base.strip(".fits")
        #try:
        #    shutil.move(base,objname)
        #except shutil.Error:
        #    pass
        try:
            shutil.move("ff_"+base,objname)
        except shutil.Error:
            pass
        try:
            shutil.move("wcs_ff_"+base,objname)
        except shutil.Error:
            pass
        try:
            shutil.move("prep_wcs_ff_"+base,objname)
        except shutil.Error:
            pass
        try:
            shutil.move("mask_"+base,objname)
        except shutil.Error:
            pass
    for file in glob.glob(objname+"*"):
        shutil.move(file,objname)

    ff.close()


if __name__ == '__main__':
    main()

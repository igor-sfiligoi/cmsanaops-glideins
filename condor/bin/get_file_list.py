#!/usr/bin/env python

#
# Tool:
#  get_file_list.py
# 
# Arguments:
#   get_file_list.py <fname>
#
# Description:
#   This script returns the list of files from an index file
#
# License:
#   MIT
#   Copyright (c) 2013 Igor Sfiligoi <isfiligoi@ucsd.edu>
#

import sys,os

def usage(fd):
    fd.write("Usage:\n")
    fd.write(" %s <fname> [<basedir>]\n"%sys.argv[0])


if len(sys.argv)<2 or len(sys.argv)>3:
    usage(sys.stderr)
    sys.exit(1)

if sys.argv[1]=="-h":
    usage(sys.stdout)
    sys.exit(0)

idx_fname=sys.argv[1]
if not os.path.isfile(idx_fname):
    usage(sys.stderr)
    sys.stderr.write("File not found: %s\n"%idx_fname)
    sys.exit(2)

def get_abs_info(relname,basepath):
    new_fname=os.path.abspath(os.path.join(basepath,relname))
    new_path=os.path.abspath(os.path.join(basepath,os.path.dirname(relname)))
    return (new_fname,new_path)    

abs_fname,abs_path=get_abs_info(idx_fname,'.')
if len(sys.argv)==3:
    if not os.path.isdir(sys.argv[2]):
        usage(sys.stderr)
        sys.stderr.write("Directory not found: %s\n"%sys.argv[2])
        sys.exit(2)
    abs_path=os.path.abspath(sys.argv[2])
    

# make it a list, so we preserve the order
files_read=[]

# returns a list of file names
def process_file(idx_fname,basepath):
    global files_read
    if idx_fname in files_read:
        # read already, do not read again
        # this allows for graceful handling of loops
        return []
    files_read.append(idx_fname)

    out=[]

    fd=open(idx_fname,"r")
    try:
        lines=fd.readlines()
    finally:
        fd.close()

    i=0
    for line in lines:
        i+=1
        line=line.strip()
        if len(line)==0:
            continue # skip empty lines
        if line[0]=="#":
            continue # skip comments
        larr=line.split()
        if len(larr)==1:
            # this should be a data file
            data_fname=os.path.join(basepath,line)
            if not os.path.isfile(data_fname):
                raise IOError (2,"File not found (referenced in %s:%i): %s"%(idx_fname,i,data_fname))
            out.append(data_fname)
            continue

        if larr[0]!='include':
            raise KeyError, "Invalid keyword found in %s:%i: %s"%(idx_fname,i,larr[0])
        next_idx_relname=larr[1]
        next_idx_fname,next_relpath=get_abs_info(next_idx_relname,basepath)
        if not os.path.isfile(next_idx_fname):
            raise IOError (2,"File not found (referenced in %s:%i): %s"%(idx_fname,i,next_idx_fname))
        out+=process_file(next_idx_fname,next_relpath)

        # end of for loop
        pass
    
    return out

try:
    gout=process_file(abs_fname,abs_path)
except IOError, e:
    sys.stderr.write("While reading %s\n"%str(files_read))
    sys.stderr.write("%s\n"%str(e))
    sys.exit(3)
except KeyError, e:
    sys.stderr.write("While reading %s\n"%str(files_read))
    sys.stderr.write("%s\n"%str(e))
    sys.exit(3)
    
for line in gout:
    print line

sys.exit(0)


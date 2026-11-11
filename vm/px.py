#!/usr/bin/env python3
"""Print RGB of screen pixels in the VM: px.py X,Y [X,Y ...]"""
import json, socket, sys, time, os, tempfile
d = os.path.dirname(os.path.abspath(__file__))
s = socket.socket(socket.AF_UNIX); s.connect(os.path.join(d, 'qmp.sock')); f = s.makefile('rw'); f.readline()
def cmd(n, **a):
    f.write(json.dumps({'execute': n, 'arguments': a}) + '\n'); f.flush()
    while True:
        r = json.loads(f.readline())
        if 'return' in r or 'error' in r: return r
cmd('qmp_capabilities'); p = os.path.join(tempfile.gettempdir(), 'm3-px.ppm'); cmd('screendump', filename=p); time.sleep(0.4)
raw = open(p, 'rb').read(); h = raw.split(b'\n', 3); w = int(h[1].split()[0]); px = h[3]
for a in sys.argv[1:]:
    x, y = map(int, a.split(',')); print(a, '#%02x%02x%02x' % tuple(px[(y*w+x)*3:(y*w+x)*3+3]))

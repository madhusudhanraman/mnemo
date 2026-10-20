# Summarise a `top -l` log from measure-energy.sh: a 10-second CPU timeline, then averages after --from seconds.
# Usage: python3 summarise-top.py <log> <pid>... [--from 90]
# top's IDLEW column is a running total, so wakeups/s is the difference over the window.
import collections,statistics,subprocess,sys
args=sys.argv[1:];start=30
if '--from' in args:i=args.index('--from');start=int(args[i+1]);del args[i:i+2]
log,*pids=args
names={}
for p in pids:
    c=subprocess.run(['ps','-o','comm=','-p',p],capture_output=True,text=True).stdout.strip()
    names[p]='Mnemo' if c.endswith('/Mnemo') else 'WebKit '+c.split('.')[-1] if c else 'pid '+p
rows=collections.defaultdict(list);timeline=collections.defaultdict(float);sample=-1
for line in open(log):
    if line.startswith('Processes:'):sample+=1
    f=line.split()
    if sample<1 or len(f)<6 or f[0] not in names:continue
    seconds=8+2*sample
    timeline[seconds//10*10]+=float(f[2])/5
    if seconds>=start:rows[f[0]].append((float(f[2]),f[3],float(f[4]),int(f[5].rstrip('+-'))))
print('CPU per 10 s:',' '.join(f"{k}s {v:.1f}%" for k,v in sorted(timeline.items())))
total=[0,0,0]
for p,v in sorted(rows.items(),key=lambda kv:names[kv[0]]):
    cpu=statistics.mean(x[0] for x in v);energy=statistics.mean(x[2] for x in v);wake=(v[-1][3]-v[0][3])/(2*max(1,len(v)-1))
    total=[total[0]+cpu,total[1]+energy,total[2]+wake]
    print(f"  {names[p]:18} cpu {cpu:4.1f}%  energy {energy:4.1f}  wakeups/s {wake:5.0f}  mem {v[-1][1]}")
print(f"  {'TOTAL':18} cpu {total[0]:4.1f}%  energy {total[1]:4.1f}  wakeups/s {total[2]:5.0f}  (from {start} s)")

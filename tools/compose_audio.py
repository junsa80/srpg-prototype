"""Original stereo-free scores. Reproducible, no external samples (CC0)."""
from pathlib import Path
import wave, numpy as np
RATE=22050
ROOT=Path(__file__).resolve().parents[1]/'assets/sfx'
def compose(filename,bpm,root,melody,pulse):
 beat=60/bpm;duration=beat*4*16;n=int(duration*RATE);mix=np.zeros(n)
 scale=[0,2,3,5,7,8,10];chords=[0,5,3,4]
 def midi(degree):return root+scale[degree%7]+12*(degree//7)
 def note(m,t,d,amp):
  count=int(d*RATE);x=np.arange(count)/RATE;f=440*2**((m-69)/12);env=np.minimum(1,x/.015)*np.maximum(0,1-x/d)**1.7
  signal=(np.sin(2*np.pi*f*x)+.2*np.sin(2*np.pi*f*2*x)+.07*np.sin(2*np.pi*f*3*x))*env*amp
  start=int(t*RATE)%n;first=min(count,n-start);mix[start:start+first]+=signal[:first]
  if count>first:mix[:count-first]+=signal[first:]
 for step in range(128):
  bar,pos=divmod(step,8);t=step*beat/2;d=chords[(bar//2)%4]
  if pos==0:
   for k in [0,2,4]:note(midi(d+k),t,beat*3.2,.032)
   note(midi(d)-12,t,beat*3.5,.09)
  if pulse and pos in [2,4,6]:note(midi(d)-12,t,beat*.3,.06)
  if pos%2:note(midi(d+[0,2,4][(pos//2)%3])+12,t,beat*.55,.027)
  v=melody[((bar//2)%4)*4+pos//2]
  if pos%2==0 and v is not None and bar%4!=3:note(midi(v)+12,t,beat*1.3,.085)
 mix=np.tanh(mix*1.4)*.65
 with wave.open(str(ROOT/filename),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes((mix*32767).astype('<i2').tobytes())
 print(filename,round(duration,2),'sec','peak',round(float(abs(mix).max()),3))
compose('bgm_home.wav',76,50,[0,None,4,3,2,None,0,1,5,4,None,6,3,2,1,None],False)
compose('bgm.wav',106,50,[0,0,4,None,3,2,1,None,5,4,6,None,3,4,1,None],True)

"""Offline bundled speech with the host libespeak-ng; no runtime dependency.
Run: python3 tools/generate_audio.py from the repository root.
"""
import ctypes as C
import hashlib, json, math, random, struct, wave
from pathlib import Path
OUT=Path(__file__).resolve().parents[1]/'vocab-box/audio'
lib=C.CDLL('libespeak-ng.so.1')
lib.espeak_Initialize.argtypes=[C.c_int,C.c_int,C.c_char_p,C.c_int]
rate=lib.espeak_Initialize(2,0,None,0) # synchronous retrieval
if rate <= 0: raise RuntimeError('Cannot initialize eSpeak NG')
lib.espeak_SetVoiceByName(b'en-gb')
lib.espeak_SetParameter(1,145,0)
chunks=[]
CALLBACK=C.CFUNCTYPE(C.c_int,C.POINTER(C.c_short),C.c_int,C.c_void_p)
@CALLBACK
def collect(samples,count,events):
    if samples and count: chunks.append(C.string_at(samples,count*2))
    return 0
lib.espeak_SetSynthCallback(collect)
lib.espeak_Synth.argtypes=[C.c_void_p,C.c_size_t,C.c_uint,C.c_int,C.c_uint,C.c_uint,C.c_void_p,C.c_void_p]
def wav(name,data,sample_rate):
    with wave.open(str(OUT/name),'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(sample_rate); f.writeframes(data)
for text in json.loads((OUT/'manifest.json').read_text()):
    chunks.clear(); encoded=text.encode()+b'\0'; buf=C.create_string_buffer(encoded)
    status=lib.espeak_Synth(buf,len(encoded),0,1,0,1,None,None)
    if status != 0: raise RuntimeError(status)
    lib.espeak_Synchronize()
    wav(hashlib.sha256(text.encode()).hexdigest()+'.wav',b''.join(chunks),rate)
lib.espeak_Terminate()
rng=random.Random(12)
def synth(name,seconds,fn):
    sr=22050
    data=b''.join(struct.pack('<h',int(max(-1,min(1,fn(i/sr)))*32767)) for i in range(int(sr*seconds)))
    wav(name+'.wav',data,sr)
synth('step',.12,lambda t:rng.uniform(-1,1)*.12*math.exp(-t*35))
synth('interact',.3,lambda t:.2*math.sin(2*math.pi*(660 if t<.12 else 880)*t)*math.exp(-t*10))
for name in ['city','supermarket']:
    def ambient(t):
        notes=[261.63,329.63,392,329.63,293.66,349.23,440,349.23]
        phase=t%1.5; note=notes[int(t/1.5)%8]
        melody=.045*math.sin(2*math.pi*note*t)*math.sin(math.pi*phase/1.5)**2
        air=.012*math.sin(2*math.pi*130.815*t)
        chirp=.025*math.sin(2*math.pi*(1800+300*math.sin(t*18))*t)*max(0,math.sin(t*1.3))**20 if name=='city' else .008*rng.uniform(-1,1)
        return melody+air+chirp
    synth(name,24,ambient)
print('Generated',len(list(OUT.glob('*.wav'))),'WAV files')

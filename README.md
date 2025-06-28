# FPGA电子琴课设

## 简介

SWJTU数电课设电子琴。引脚分配适用于SWJTU数电实验室MFB-5自主实验器(EP4CE6E22)

![structure](/readme/structure.png)

大部分代码是vibe coding的垃圾，给大家伙玩个乐(

### 功能介绍

**基本功能：**

A. 自动演奏功能

B. 用按键模拟琴键，36键弹奏，数码管显示弹奏的音符

C. 录音回放回放

D. 乐曲练习功能

**扩展功能：**

E. 练习模式与弹奏模式的数码管滚动与回滚

F. 输入固定音符进入练习模式的模式切换方式

G. Python脚本自动扒midi文件生成verilog谱

### 使用说明：

**1.**   **基本按键发声与八度切换测试:** Key1-Key7（对应C,D,E,F,G,A,B基本音阶）和Key8-Key12（对应C#,Eb,F#,G#,Bb半音）。SW15（八度增加键）和SW13（八度降低键）。按下一个音乐按键，蜂鸣器发出对应音高的声音。

**2.**   **录音与回放：** SW16掷1（录音键），开始录音，直到SW16掷0停止。

按下SW17开始播放。

**3.**   **预设歌曲播放功能测试：** SW14掷1时播放指定的音乐。

**4.**   **练习模式相关：** 快速输入2317616即可进入练习模式，可以练习指定的曲子。按复位键退出。


### Badapple示例谱子
```v
        song_rom[  0]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[  1]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[  2]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[  3]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[  4]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4329s
        song_rom[  5]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[  6]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[  7]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[  8]  = { OCTAVE_MID , NOTE_DS  , 4'd6 }; // MIDI 63 (D#4), Dur: 0.4330s
        song_rom[  9]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[ 10]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 11]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 12]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 13]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2155s
        song_rom[ 14]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 15]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 16]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 17]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[ 18]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 19]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 20]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 21]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[ 22]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2155s
        song_rom[ 23]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2155s
        song_rom[ 24]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 25]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[ 26]  = { OCTAVE_MID , NOTE_D   , 4'd3 }; // MIDI 62 (D4), Dur: 0.2156s
        song_rom[ 27]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 28]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[ 29]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 30]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 31]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 32]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4329s
        song_rom[ 33]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2155s
        song_rom[ 34]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[ 35]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[ 36]  = { OCTAVE_MID , NOTE_DS  , 4'd6 }; // MIDI 63 (D#4), Dur: 0.4330s
        song_rom[ 37]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[ 38]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 39]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 40]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 41]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2155s
        song_rom[ 42]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2155s
        song_rom[ 43]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 44]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 45]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[ 46]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 47]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 48]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 49]  = { OCTAVE_MID , REST     , 4'd3 }; // Rest dur: 0.2192s
        song_rom[ 50]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 51]  = { OCTAVE_MID , REST     , 4'd3 }; // Rest dur: 0.2192s
        song_rom[ 52]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[ 53]  = { OCTAVE_MID , REST     , 4'd3 }; // Rest dur: 0.2192s
        song_rom[ 54]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[ 55]  = { OCTAVE_MID , REST     , 4'd3 }; // Rest dur: 0.2192s
        song_rom[ 56]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[ 57]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 58]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 59]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 60]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[ 61]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2155s
        song_rom[ 62]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2155s
        song_rom[ 63]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4329s
        song_rom[ 64]  = { OCTAVE_MID , NOTE_DS  , 4'd6 }; // MIDI 63 (D#4), Dur: 0.4330s
        song_rom[ 65]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[ 66]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 67]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 68]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 69]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[ 70]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 71]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2155s
        song_rom[ 72]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[ 73]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[ 74]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 75]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 76]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 77]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[ 78]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 79]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 80]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 81]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2155s
        song_rom[ 82]  = { OCTAVE_MID , NOTE_D   , 4'd3 }; // MIDI 62 (D4), Dur: 0.2155s
        song_rom[ 83]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 84]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[ 85]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 86]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 87]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 88]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[ 89]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[ 90]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[ 91]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4329s
        song_rom[ 92]  = { OCTAVE_MID , NOTE_DS  , 4'd6 }; // MIDI 63 (D#4), Dur: 0.4330s
        song_rom[ 93]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[ 94]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 95]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 96]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 97]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[ 98]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 99]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[100]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[101]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4329s
        song_rom[102]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[103]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[104]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[105]  = { OCTAVE_MID , REST     , 4'd3 }; // Rest dur: 0.2192s
        song_rom[106]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[107]  = { OCTAVE_MID , REST     , 4'd3 }; // Rest dur: 0.2192s
        song_rom[108]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[109]  = { OCTAVE_MID , REST     , 4'd3 }; // Rest dur: 0.2192s
        song_rom[110]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[111]  = { OCTAVE_MID , REST     , 4'd3 }; // Rest dur: 0.2192s
        song_rom[112]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[113]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[114]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[115]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[116]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[117]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[118]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[119]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[120]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2155s
        song_rom[121]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[122]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[123]  = { OCTAVE_MID , NOTE_AS  , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3243s
        song_rom[124]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[125]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[126]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[127]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[128]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[129]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[130]  = { OCTAVE_LOW , NOTE_AS  , 4'd3 }; // MIDI 61 (A#3), Dur: 0.2156s
        song_rom[131]  = { OCTAVE_MID , NOTE_DS  , 4'd6 }; // MIDI 63 (D#4), Dur: 0.4329s
        song_rom[132]  = { OCTAVE_LOW , NOTE_AS  , 4'd3 }; // MIDI 61 (A#3), Dur: 0.2156s
        song_rom[133]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[134]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[135]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[136]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[137]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[138]  = { OCTAVE_MID , NOTE_DS  , 4'd5 }; // MIDI 63 (D#4), Dur: 0.3243s
        song_rom[139]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[140]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[141]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[142]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2155s
        song_rom[143]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2155s
        song_rom[144]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[145]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[146]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[147]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[148]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[149]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[150]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[151]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[152]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[153]  = { OCTAVE_MID , NOTE_AS  , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3242s
        song_rom[154]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[155]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[156]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[157]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[158]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[159]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[160]  = { OCTAVE_LOW , NOTE_AS  , 4'd3 }; // MIDI 61 (A#3), Dur: 0.2156s
        song_rom[161]  = { OCTAVE_MID , NOTE_DS  , 4'd6 }; // MIDI 63 (D#4), Dur: 0.4330s
        song_rom[162]  = { OCTAVE_LOW , NOTE_AS  , 4'd3 }; // MIDI 61 (A#3), Dur: 0.2155s
        song_rom[163]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2155s
        song_rom[164]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[165]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[166]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[167]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[168]  = { OCTAVE_MID , NOTE_DS  , 4'd5 }; // MIDI 63 (D#4), Dur: 0.3243s
        song_rom[169]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[170]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[171]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[172]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[173]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2155s
        song_rom[174]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[175]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[176]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[177]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[178]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[179]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[180]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[181]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[182]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[183]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[184]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[185]  = { OCTAVE_MID , NOTE_CS  , 4'd3 }; // MIDI 61 (C#4), Dur: 0.2156s
        song_rom[186]  = { OCTAVE_MID , NOTE_DS  , 4'd6 }; // MIDI 63 (D#4), Dur: 0.4330s
        song_rom[187]  = { OCTAVE_MID , NOTE_CS  , 4'd3 }; // MIDI 61 (C#4), Dur: 0.2156s
        song_rom[188]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2155s
        song_rom[189]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2155s
        song_rom[190]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[191]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[192]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[193]  = { OCTAVE_MID , NOTE_DS  , 4'd5 }; // MIDI 63 (D#4), Dur: 0.3243s
        song_rom[194]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[195]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[196]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[197]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[198]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[199]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[200]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[201]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[202]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[203]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[204]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[205]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[206]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[207]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[208]  = { OCTAVE_MID , NOTE_AS  , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3243s
        song_rom[209]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[210]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2155s
        song_rom[211]  = { OCTAVE_HIGH, NOTE_F   , 4'd3 }; // MIDI 77 (F5), Dur: 0.2156s
        song_rom[212]  = { OCTAVE_HIGH, NOTE_FS  , 4'd3 }; // MIDI 78 (F#5), Dur: 0.2156s
        song_rom[213]  = { OCTAVE_HIGH, NOTE_F   , 4'd3 }; // MIDI 77 (F5), Dur: 0.2156s
        song_rom[214]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[215]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[216]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[217]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[218]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[219]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[220]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2155s
        song_rom[221]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[222]  = { OCTAVE_MID , NOTE_CS  , 4'd3 }; // MIDI 61 (C#4), Dur: 0.2156s
        song_rom[223]  = { OCTAVE_MID , NOTE_DS  , 4'd5 }; // MIDI 63 (D#4), Dur: 0.3243s
        song_rom[224]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[225]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[226]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[227]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[228]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[229]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[230]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[231]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4329s
        song_rom[232]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[233]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[234]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[235]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[236]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[237]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[238]  = { OCTAVE_MID , NOTE_AS  , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3243s
        song_rom[239]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[240]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[241]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[242]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[243]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[244]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[245]  = { OCTAVE_MID , NOTE_CS  , 4'd3 }; // MIDI 61 (C#4), Dur: 0.2156s
        song_rom[246]  = { OCTAVE_MID , NOTE_DS  , 4'd6 }; // MIDI 63 (D#4), Dur: 0.4330s
        song_rom[247]  = { OCTAVE_MID , NOTE_CS  , 4'd3 }; // MIDI 61 (C#4), Dur: 0.2156s
        song_rom[248]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[249]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[250]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[251]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[252]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[253]  = { OCTAVE_MID , NOTE_DS  , 4'd5 }; // MIDI 63 (D#4), Dur: 0.3243s
        song_rom[254]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[255]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[256]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[257]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[258]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[259]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[260]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[261]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4329s
        song_rom[262]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[263]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[264]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2155s
        song_rom[265]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[266]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[267]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[268]  = { OCTAVE_MID , NOTE_AS  , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3243s
        song_rom[269]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[270]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[271]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[272]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[273]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2155s
        song_rom[274]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2155s
        song_rom[275]  = { OCTAVE_MID , NOTE_CS  , 4'd3 }; // MIDI 61 (C#4), Dur: 0.2156s
        song_rom[276]  = { OCTAVE_MID , NOTE_DS  , 4'd6 }; // MIDI 63 (D#4), Dur: 0.4330s
        song_rom[277]  = { OCTAVE_MID , NOTE_CS  , 4'd3 }; // MIDI 61 (C#4), Dur: 0.2156s
        song_rom[278]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[279]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[280]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[281]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[282]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[283]  = { OCTAVE_MID , NOTE_DS  , 4'd5 }; // MIDI 63 (D#4), Dur: 0.3242s
        song_rom[284]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[285]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[286]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[287]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[288]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[289]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[290]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[291]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[292]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[293]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[294]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2155s
        song_rom[295]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[296]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[297]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[298]  = { OCTAVE_MID , NOTE_AS  , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3243s
        song_rom[299]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[300]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[301]  = { OCTAVE_HIGH, NOTE_F   , 4'd3 }; // MIDI 77 (F5), Dur: 0.2156s
        song_rom[302]  = { OCTAVE_HIGH, NOTE_FS  , 4'd3 }; // MIDI 78 (F#5), Dur: 0.2156s
        song_rom[303]  = { OCTAVE_HIGH, NOTE_F   , 4'd3 }; // MIDI 77 (F5), Dur: 0.2156s
        song_rom[304]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2155s
        song_rom[305]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2155s
        song_rom[306]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4329s
        song_rom[307]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[308]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[309]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[310]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[311]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[312]  = { OCTAVE_MID , NOTE_CS  , 4'd3 }; // MIDI 61 (C#4), Dur: 0.2156s
        song_rom[313]  = { OCTAVE_MID , NOTE_DS  , 4'd5 }; // MIDI 63 (D#4), Dur: 0.3243s
```










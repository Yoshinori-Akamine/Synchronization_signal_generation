# Zero_Cross_detection_code
2次側スイッチングのタイミングを決めるために必要となるゼロクロス信号を複数の方法で取得できるようにしたfpgaモジュール。
モジュール名はsync_signal_generator_ifとした。
Pe-expert4のfpgaボードで実装することを想定している

<p align="center">  
<img src="sync_rect_module.svg">  
</p>  
<p align="center"><strong>このモジュールの構成　概念図</strong></p>

---
## 概要
入力で指定されたモード信号に応じて、出力するゼロクロス信号の生成アルゴリズムを変える。
- mode0：チャタリング防止機能付きのゼロクロス信号FB
- mode1：インバータのスイッチS1を基準に生成するゼロクロス信号FB
- mode2：インバータのスイッチS2を基準に生成するゼロクロス信号FB
- mode3：rect_nocontrol_flag = 1（出力信号）として、後段でこの出力を読むことでダイオード整流モードの利用を想定


---
## 入出力の説明
あとでかく
---
## 各モードの説明
あとでかく
---
## 内容の説明
あとでかく
---

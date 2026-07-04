# 数字调制识别 MATLAB 仿真工程

这是一个完整的 MATLAB 课程设计工程，用于完成“数字通信系统中的调制识别算法设计与仿真”。

工程已经包含：

- ASK、FSK、BPSK、QPSK、16QAM 五类信号生成
- AWGN 加噪
- 时域波形、频谱、星座图绘制
- 幅度、相位、频率、高阶累积量特征提取
- SVM 主分类器和 KNN 对照分类器
- 不同 SNR 下识别准确率统计
- 中文小论文 Word/PDF/Markdown 版本
- 已运行生成的结果文件

## 快速运行

打开 MATLAB，把当前目录切换到本工程根目录，然后运行：

```matlab
run_modulation_recognition
```

或者直接打开：

```text
src/run_modulation_recognition.m
```

运行后结果会保存到：

```text
results/
```

## 项目结构

```text
数字调制识别MATLAB仿真工程/
├─ README_先看我.md
├─ README.md
├─ run_modulation_recognition.m          # 根目录运行入口
├─ src/
│  └─ run_modulation_recognition.m       # 完整 MATLAB 源代码
├─ docs/
│  ├─ 项目说明.md
│  ├─ 运行说明.md
│  ├─ 参数选择说明.md
│  ├─ 调制识别仿真小论文.md
│  ├─ 调制识别仿真小论文.docx
│  └─ 调制识别仿真小论文.pdf
└─ results/
   ├─ accuracy_by_snr.csv
   ├─ features_dataset.csv
   ├─ accuracy_vs_snr.png
   ├─ time_waveforms.png
   ├─ spectra.png
   ├─ constellations.png
   ├─ confusion_svm_10dB.png
   ├─ confusion_knn_10dB.png
   └─ simulation_models_and_results.mat
```

## 核心结论

本工程采用 `SNR = -10:2:20 dB`，使用 RBF-SVM 作为主分类器，KNN 作为对照。仿真结果中，SVM 在 4 dB 后准确率接近 100%，在 6 dB 后达到 100%。




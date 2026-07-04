%% Digital modulation recognition simulation
% Modulation types: ASK, FSK, BPSK, QPSK, 16QAM
% Classifiers: SVM as the main classifier, KNN as a baseline.

clear; clc; close all;
rng(20260703);

scriptDir = fileparts(mfilename("fullpath"));
[~, scriptFolderName] = fileparts(scriptDir);
if strcmpi(string(scriptFolderName), "src")
    projectDir = fileparts(scriptDir);
else
    projectDir = scriptDir;
end
resultDir = fullfile(projectDir, "results");
if ~exist(resultDir, "dir")
    mkdir(resultDir);
end

params.modTypes = ["ASK", "FSK", "BPSK", "QPSK", "16QAM"];
params.snrList = -10:2:20;
params.samplesPerSymbol = 8;
params.symbolsPerFrame = 256;
params.trainFramesPerClassPerSNR = 60;
params.testFramesPerClassPerSNR = 30;
params.fskDeviation = 0.25 / params.samplesPerSymbol;

featureNames = ["realMean", "imagMean", "dcAbs", ...
    "ampMean", "ampVar", "ampSkew", "ampKurt", ...
    "phaseStepMeanAbs", "phaseStepVar", "phaseStepKurt", ...
    "freqChangeVar", "freqChangeMeanAbs", ...
    "c20Abs", "c40Abs", "c42Abs", "c40Real", "c40Imag"];

fprintf("Building training set...\n");
[XTrain, YTrain, trainSnr] = buildDataset(params, params.trainFramesPerClassPerSNR, featureNames);

fprintf("Building test set...\n");
[XTest, YTest, testSnr] = buildDataset(params, params.testFramesPerClassPerSNR, featureNames);

fprintf("Training SVM and KNN classifiers...\n");
svmTemplate = templateSVM( ...
    "KernelFunction", "rbf", ...
    "KernelScale", "auto", ...
    "BoxConstraint", 1, ...
    "Standardize", true);

svmModel = fitcecoc(XTrain, YTrain, ...
    "Learners", svmTemplate, ...
    "Coding", "onevsone", ...
    "ClassNames", categorical(params.modTypes));

knnModel = fitcknn(XTrain, YTrain, ...
    "NumNeighbors", 5, ...
    "Distance", "euclidean", ...
    "Standardize", true, ...
    "ClassNames", categorical(params.modTypes));

fprintf("Testing classifiers...\n");
svmPred = predict(svmModel, XTest);
knnPred = predict(knnModel, XTest);

accuracyTable = makeAccuracyTable(params.snrList, testSnr, YTest, svmPred, knnPred);
disp(accuracyTable);

writetable(accuracyTable, fullfile(resultDir, "accuracy_by_snr.csv"));

featureTable = array2table([XTrain; XTest], 'VariableNames', cellstr(featureNames));
featureTable.Modulation = [YTrain; YTest];
featureTable.SNR_dB = [trainSnr; testSnr];
featureTable.Split = [repmat("train", numel(YTrain), 1); repmat("test", numel(YTest), 1)];
writetable(featureTable, fullfile(resultDir, "features_dataset.csv"));

plotAccuracy(accuracyTable, resultDir);
plotExamples(params, resultDir);
plotConfusion(YTest(testSnr == 10), svmPred(testSnr == 10), params.modTypes, ...
    "SVM confusion matrix at 10 dB", fullfile(resultDir, "confusion_svm_10dB.png"));
plotConfusion(YTest(testSnr == 10), knnPred(testSnr == 10), params.modTypes, ...
    "KNN confusion matrix at 10 dB", fullfile(resultDir, "confusion_knn_10dB.png"));

save(fullfile(resultDir, "simulation_models_and_results.mat"), ...
    "params", "featureNames", "svmModel", "knnModel", ...
    "accuracyTable", "XTrain", "YTrain", "trainSnr", "XTest", "YTest", "testSnr");

writeSummary(params, featureNames, accuracyTable, resultDir);
fprintf("Done. Results saved to: %s\n", resultDir);

function [X, Y, snrColumn] = buildDataset(params, framesPerClassPerSNR, featureNames)
totalRows = numel(params.modTypes) * numel(params.snrList) * framesPerClassPerSNR;
X = zeros(totalRows, numel(featureNames));
Y = strings(totalRows, 1);
snrColumn = zeros(totalRows, 1);

row = 1;
for s = 1:numel(params.snrList)
    snrDb = params.snrList(s);
    for m = 1:numel(params.modTypes)
        modType = params.modTypes(m);
        for n = 1:framesPerClassPerSNR
            cleanSignal = generateSignal(modType, params);
            noisySignal = addAwgn(cleanSignal, snrDb);
            X(row, :) = extractFeatures(noisySignal);
            Y(row) = modType;
            snrColumn(row) = snrDb;
            row = row + 1;
        end
    end
end

Y = categorical(Y, params.modTypes);
end

function signal = generateSignal(modType, params)
numSymbols = params.symbolsPerFrame;
sps = params.samplesPerSymbol;

switch string(modType)
    case "ASK"
        bits = randi([0 1], numSymbols, 1);
        symbols = 0.3 + 0.7 * bits;
        signal = repelem(symbols, sps);

    case "FSK"
        bits = randi([0 1], numSymbols, 1);
        freq = (2 * bits - 1) * params.fskDeviation;
        freqSamples = repelem(freq, sps);
        phase = cumsum(2 * pi * freqSamples);
        signal = exp(1j * phase);

    case "BPSK"
        bits = randi([0 1], numSymbols, 1);
        symbols = 2 * bits - 1;
        signal = repelem(symbols, sps);

    case "QPSK"
        idx = randi([0 3], numSymbols, 1);
        phases = pi/4 + idx * pi/2;
        symbols = exp(1j * phases);
        signal = repelem(symbols, sps);

    case "16QAM"
        levels = [-3 -1 1 3];
        iPart = levels(randi([1 4], numSymbols, 1)).';
        qPart = levels(randi([1 4], numSymbols, 1)).';
        symbols = iPart + 1j * qPart;
        symbols = symbols / sqrt(mean(abs(symbols).^2));
        signal = repelem(symbols, sps);

    otherwise
        error("Unsupported modulation type: %s", modType);
end

signal = signal(:);
signal = signal / sqrt(mean(abs(signal).^2));
end

function noisy = addAwgn(signal, snrDb)
signalPower = mean(abs(signal).^2);
noisePower = signalPower / (10^(snrDb / 10));
noise = sqrt(noisePower / 2) * (randn(size(signal)) + 1j * randn(size(signal)));
noisy = signal + noise;
end

function features = extractFeatures(signal)
z = signal(:);
z = z / sqrt(mean(abs(z).^2) + eps);
zCentered = z - mean(z);
zCentered = zCentered / sqrt(mean(abs(zCentered).^2) + eps);

amp = abs(z);
phaseStep = diff(unwrap(angle(z)));
phaseStep = wrapToPiLocal(phaseStep);
freqChange = diff(phaseStep);

m20 = mean(zCentered.^2);
m40 = mean(zCentered.^4);
m21 = mean(abs(zCentered).^2);
m42 = mean(abs(zCentered).^4);
c40 = m40 - 3 * m20^2;
c42 = m42 - abs(m20)^2 - 2 * m21^2;

features = [ ...
    real(mean(z)), ...
    imag(mean(z)), ...
    abs(mean(z)), ...
    mean(amp), ...
    var(amp), ...
    skewness(amp), ...
    kurtosis(amp), ...
    mean(abs(phaseStep)), ...
    var(phaseStep), ...
    kurtosis(phaseStep), ...
    var(freqChange), ...
    mean(abs(freqChange)), ...
    abs(m20), ...
    abs(c40), ...
    abs(c42), ...
    real(c40), ...
    imag(c40)];
end

function wrapped = wrapToPiLocal(angleValue)
wrapped = mod(angleValue + pi, 2 * pi) - pi;
end

function accuracyTable = makeAccuracyTable(snrList, testSnr, yTrue, svmPred, knnPred)
svmAccuracy = zeros(numel(snrList), 1);
knnAccuracy = zeros(numel(snrList), 1);

for k = 1:numel(snrList)
    idx = testSnr == snrList(k);
    svmAccuracy(k) = mean(svmPred(idx) == yTrue(idx));
    knnAccuracy(k) = mean(knnPred(idx) == yTrue(idx));
end

accuracyTable = table(snrList(:), svmAccuracy, knnAccuracy, ...
    'VariableNames', {'SNR_dB', 'SVM_Accuracy', 'KNN_Accuracy'});
end

function plotAccuracy(accuracyTable, resultDir)
fig = figure("Visible", "off", "Color", "w", "Position", [100 100 860 520]);
plot(accuracyTable.SNR_dB, 100 * accuracyTable.SVM_Accuracy, "-o", ...
    "LineWidth", 2, "MarkerSize", 6);
hold on;
plot(accuracyTable.SNR_dB, 100 * accuracyTable.KNN_Accuracy, "-s", ...
    "LineWidth", 2, "MarkerSize", 6);
grid on;
xlabel("SNR (dB)");
ylabel("Recognition accuracy (%)");
title("Recognition accuracy under different SNR values");
legend("SVM", "KNN", "Location", "southeast");
ylim([0 105]);
exportgraphics(fig, fullfile(resultDir, "accuracy_vs_snr.png"), "Resolution", 180);
close(fig);
end

function plotExamples(params, resultDir)
snrDb = 20;
timeFig = figure("Visible", "off", "Color", "w", "Position", [100 100 900 720]);
specFig = figure("Visible", "off", "Color", "w", "Position", [100 100 900 720]);
constFig = figure("Visible", "off", "Color", "w", "Position", [100 100 900 720]);

for k = 1:numel(params.modTypes)
    modType = params.modTypes(k);
    signal = addAwgn(generateSignal(modType, params), snrDb);

    figure(timeFig);
    subplot(numel(params.modTypes), 1, k);
    n = min(320, numel(signal));
    plot(real(signal(1:n)), "LineWidth", 1);
    grid on;
    ylabel(modType);
    if k == 1
        title("Time-domain waveform examples at 20 dB");
    end
    if k == numel(params.modTypes)
        xlabel("Sample index");
    end

    figure(specFig);
    subplot(numel(params.modTypes), 1, k);
    spectrum = fftshift(abs(fft(signal, 4096)));
    spectrumDb = 20 * log10(spectrum / max(spectrum) + eps);
    freqAxis = linspace(-0.5, 0.5, numel(spectrumDb));
    plot(freqAxis, spectrumDb, "LineWidth", 1);
    grid on;
    ylim([-80 5]);
    ylabel(modType);
    if k == 1
        title("Normalized spectrum examples at 20 dB");
    end
    if k == numel(params.modTypes)
        xlabel("Normalized frequency");
    end

    figure(constFig);
    subplot(2, 3, k);
    symbolSamples = signal(1:params.samplesPerSymbol:end);
    scatter(real(symbolSamples), imag(symbolSamples), 10, "filled", ...
        "MarkerFaceAlpha", 0.45, "MarkerEdgeAlpha", 0.45);
    axis equal;
    grid on;
    xlabel("I");
    ylabel("Q");
    title(modType);
end

exportgraphics(timeFig, fullfile(resultDir, "time_waveforms.png"), "Resolution", 180);
exportgraphics(specFig, fullfile(resultDir, "spectra.png"), "Resolution", 180);
exportgraphics(constFig, fullfile(resultDir, "constellations.png"), "Resolution", 180);
close(timeFig);
close(specFig);
close(constFig);
end

function plotConfusion(yTrue, yPred, modTypes, chartTitle, filePath)
order = categorical(modTypes);
cm = confusionmat(yTrue, yPred, "Order", order);
rowSum = sum(cm, 2);
cmPercent = 100 * cm ./ max(rowSum, 1);

fig = figure("Visible", "off", "Color", "w", "Position", [100 100 720 620]);
imagesc(cmPercent);
axis equal tight;
colormap(parula);
colorbar;
title(chartTitle);
xlabel("Predicted class");
ylabel("True class");
xticks(1:numel(modTypes));
yticks(1:numel(modTypes));
xticklabels(modTypes);
yticklabels(modTypes);

for r = 1:size(cmPercent, 1)
    for c = 1:size(cmPercent, 2)
        text(c, r, sprintf("%.1f%%", cmPercent(r, c)), ...
            "HorizontalAlignment", "center", ...
            "Color", "w", ...
            "FontWeight", "bold");
    end
end

exportgraphics(fig, filePath, "Resolution", 180);
close(fig);
end

function writeSummary(params, featureNames, accuracyTable, resultDir)
summaryPath = fullfile(resultDir, "run_summary.txt");
fid = fopen(summaryPath, "w");
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, "Digital modulation recognition simulation summary\n");
fprintf(fid, "Generated at: %s\n\n", char(datetime("now")));
fprintf(fid, "Modulation types: %s\n", char(strjoin(params.modTypes, ", ")));
fprintf(fid, "SNR range: %s dB\n", mat2str(params.snrList));
fprintf(fid, "Samples per symbol: %d\n", params.samplesPerSymbol);
fprintf(fid, "Symbols per frame: %d\n", params.symbolsPerFrame);
fprintf(fid, "Training frames per class per SNR: %d\n", params.trainFramesPerClassPerSNR);
fprintf(fid, "Test frames per class per SNR: %d\n\n", params.testFramesPerClassPerSNR);
fprintf(fid, "Features:\n");
for k = 1:numel(featureNames)
    fprintf(fid, "  %02d. %s\n", k, char(featureNames(k)));
end

fprintf(fid, "\nAccuracy by SNR:\n");
for k = 1:height(accuracyTable)
    fprintf(fid, "  SNR=%4.0f dB, SVM=%6.2f%%, KNN=%6.2f%%\n", ...
        accuracyTable.SNR_dB(k), ...
        100 * accuracyTable.SVM_Accuracy(k), ...
        100 * accuracyTable.KNN_Accuracy(k));
end
end
